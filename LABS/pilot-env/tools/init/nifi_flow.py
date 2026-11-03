"""Creates (idempotently) the NiFi ETL flow that unifies MySQL/PostgreSQL orders into Ordini.ordini.

Per source:
 GetMongo (only docs without etl_status) -> EvaluateJsonPath (src_pk) -> UpdateAttribute (etl_ts)
 -> JoltTransformJSON (unify schema) -> PutMongo upsert in 'ordini'
 -> ReplaceText ($set etl_status=DONE) -> PutMongo update on the source doc (marks it as processed)
Failures are auto-terminated: the source doc stays unmarked and is retried at the next poll.
"""
import json
import os
import sys
import time

import requests

NIFI = os.environ.get("NIFI_URL", "http://nifi:8080") + "/nifi-api"
MONGO_URI = f"mongodb://{os.environ['MONGO_USER']}:{os.environ['MONGO_PASSWORD']}@mongodb:27017/?authSource=admin"
MONGO_DB = os.environ.get("MONGO_DATABASE", "Ordini")
GROUP_NAME = "orders-etl"
POLL = "5 sec"

STATUS_MAP_PG = {
    "created": {"#NEW": "status"}, "paid": {"#PAID": "status"},
    "shipped": {"#SHIPPED": "status"}, "cancelled": {"#CANCELLED": "status"},
}

JOLT = {
    "mysql": [
        {"operation": "shift", "spec": {"0": {"*": "&"}}},  # GetMongo emits a one-element array
        {"operation": "shift", "spec": {
            "order_id": "source_order_id",
            "customer_code": "customer.code",
            "customer_name": "customer.name",
            "order_datetime": "order_date",
            "order_status": "status",
            "net_amount": "total_net",
            "tax_amount": "total_vat",
            "total_amount": "total_gross",
            "currency": "currency",
            "ship_country": "country",
            "items": {"*": {
                "line_no": "items[&1].line_number",
                "product_sku": "items[&1].sku",
                "product_name": "items[&1].description",
                "quantity": "items[&1].quantity",
                "unit_price": "items[&1].unit_price",
                "line_total": "items[&1].line_total"}},
        }},
        {"operation": "default", "spec": {
            "_id": "MYSQL-${src_pk}", "source_system": "MYSQL", "etl_processed_at": "${etl_ts}"}},
    ],
    "postgres": [
        {"operation": "shift", "spec": {"0": {"*": "&"}}},
        {"operation": "shift", "spec": {
            "id": "source_order_id",
            "customer": {"id": "customer.code", "full_name": "customer.name"},
            "created_at": "order_date",
            "state": STATUS_MAP_PG,
            "amount_net": "total_net",
            "amount_vat": "total_vat",
            "amount_gross": "total_gross",
            "currency_code": "currency",
            "country_code": "country",
            "lines": {"*": {
                "line_number": "items[&1].line_number",
                "item_code": "items[&1].sku",
                "item_description": "items[&1].description",
                "qty": "items[&1].quantity",
                "price_net": "items[&1].unit_price",
                "line_net": "items[&1].line_total"}},
        }},
        {"operation": "default", "spec": {
            "_id": "POSTGRES-${src_pk}", "source_system": "POSTGRES", "etl_processed_at": "${etl_ts}"}},
    ],
}


def api(method, path, **kw):
    r = requests.request(method, NIFI + path, timeout=60, **kw)
    if not r.ok:
        sys.exit(f"NiFi API {method} {path} -> {r.status_code}: {r.text[:1500]}")
    return r.json() if r.text else {}


def wait_nifi():
    for _ in range(60):
        try:
            if requests.get(NIFI + "/flow/about", timeout=10).ok:
                return
        except requests.RequestException:
            pass
        time.sleep(5)
    sys.exit("NiFi not reachable")


class Builder:
    def __init__(self, group_id):
        self.group_id = group_id
        self.types = {}
        for t in api("GET", "/flow/processor-types")["processorTypes"]:
            self.types[t["type"]] = t["bundle"]
        self.x = 0

    def proc(self, short, name, props, y, terminate=(), period=None):
        full = next(t for t in self.types if t.endswith("." + short))
        self.x += 1
        config = {"properties": props, "autoTerminatedRelationships": list(terminate)}
        if period:
            config.update({"schedulingPeriod": period, "schedulingStrategy": "TIMER_DRIVEN"})
        body = {"revision": {"version": 0}, "component": {
            "type": full, "bundle": self.types[full], "name": name,
            "position": {"x": self.x * 330.0, "y": y}, "config": config}}
        res = api("POST", f"/process-groups/{self.group_id}/processors", json=body)
        return res["id"]

    def connect(self, src, dst, rels):
        body = {"revision": {"version": 0}, "component": {
            "source": {"id": src, "groupId": self.group_id, "type": "PROCESSOR"},
            "destination": {"id": dst, "groupId": self.group_id, "type": "PROCESSOR"},
            "selectedRelationships": rels}}
        api("POST", f"/process-groups/{self.group_id}/connections", json=body)


def build_source(b, source, y):
    mongo = {"Mongo URI": MONGO_URI, "Mongo Database Name": MONGO_DB}
    get = b.proc("GetMongo", f"read-{source}-ingest", {
        **mongo, "Mongo Collection Name": f"data-ingest-ordini-{source}",
        "Query": '{"etl_status": {"$exists": false}}', "Limit": "200", "Batch Size": "100",
        "results-per-flowfile": "1", "json-type": "Standard"}, y, period=POLL,
        terminate=["failure", "original"])
    key = b.proc("EvaluateJsonPath", f"extract-{source}-key", {
        "Destination": "flowfile-attribute", "src_pk": "$[0]._id"}, y, terminate=["failure", "unmatched"])
    ts = b.proc("UpdateAttribute", f"set-{source}-etl-timestamp", {
        "etl_ts": "${now():format(\"yyyy-MM-dd'T'HH:mm:ss'Z'\", 'UTC')}"}, y)
    jolt = b.proc("JoltTransformJSON", f"unify-{source}-json", {
        "jolt-transform": "jolt-transform-chain", "jolt-spec": json.dumps(JOLT[source])},
        y, terminate=["failure"])
    put = b.proc("PutMongo", f"upsert-{source}-in-ordini", {
        **mongo, "Mongo Collection Name": "ordini", "Mode": "update", "Upsert": "true",
        "Update Query Key": "_id", "put-mongo-update-mode": "doc"}, y, terminate=["failure"])
    mark_body = b.proc("ReplaceText", f"build-{source}-done-marker", {
        "Replacement Strategy": "Always Replace", "Evaluation Mode": "Entire text",
        "Replacement Value": '{"$set": {"etl_status": "DONE", "etl_processed_at": "${etl_ts}"}}'},
        y, terminate=["failure"])
    mark = b.proc("PutMongo", f"mark-{source}-ingest-done", {
        **mongo, "Mongo Collection Name": f"data-ingest-ordini-{source}", "Mode": "update",
        "putmongo-update-query": '{"_id": "${src_pk}"}', "put-mongo-update-mode": "operators"},
        y, terminate=["success", "failure"])
    b.connect(get, key, ["success"])
    b.connect(key, ts, ["matched"])
    b.connect(ts, jolt, ["success"])
    b.connect(jolt, put, ["success"])
    b.connect(put, mark_body, ["success"])
    b.connect(mark_body, mark, ["success"])


def main():
    wait_nifi()
    root = api("GET", "/flow/process-groups/root")["processGroupFlow"]
    root_id = root["id"]
    existing = [g for g in root["flow"]["processGroups"] if g["component"]["name"] == GROUP_NAME]
    if existing:
        group_id = existing[0]["id"]
        print("flow already present, ensuring it is running")
    else:
        group = api("POST", f"/process-groups/{root_id}/process-groups", json={
            "revision": {"version": 0},
            "component": {"name": GROUP_NAME, "position": {"x": 100.0, "y": 100.0}}})
        group_id = group["id"]
        b = Builder(group_id)
        for i, source in enumerate(["mysql", "postgres"]):
            b.x = 0
            build_source(b, source, 100.0 + i * 250.0)
        print("flow created")

    api("PUT", f"/flow/process-groups/{group_id}", json={"id": group_id, "state": "RUNNING"})
    time.sleep(5)
    flow = api("GET", f"/flow/process-groups/{group_id}")["processGroupFlow"]["flow"]
    bad = [p["component"]["name"] for p in flow["processors"]
           if p["component"]["state"] != "RUNNING" or p["component"].get("validationErrors")]
    if bad:
        for p in flow["processors"]:
            if p["component"].get("validationErrors"):
                print(p["component"]["name"], p["component"]["validationErrors"])
        sys.exit(f"processors not running/valid: {bad}")
    print(f"{len(flow['processors'])} processors RUNNING")


if __name__ == "__main__":
    main()
