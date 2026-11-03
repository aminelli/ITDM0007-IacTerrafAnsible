"""Configures Metabase (idempotently): admin user, MongoDB data source, BI and real-time dashboards."""
import os
import sys
import time

import requests

MB = os.environ.get("METABASE_URL", "http://metabase:3000") + "/api"
EMAIL = os.environ["METABASE_ADMIN_EMAIL"]
PASSWORD = os.environ["METABASE_ADMIN_PASSWORD"]
DB_NAME = "Ordini (MongoDB)"
COLLECTION = "ordini"

PARSE_DATE = {"$dateFromString": {"dateString": "$order_date"}}
LAST_N_MIN = lambda n: {"$match": {"$expr": {"$gte": [PARSE_DATE, {"$dateSubtract": {
    "startDate": "$$NOW", "unit": "minute", "amount": n}}]}}}

# (name, display, pipeline, viz settings)
BI_CARDS = [
    ("Total orders", "scalar", [{"$count": "total_orders"}], {}),
    ("Total revenue (gross)", "scalar", [{"$group": {"_id": None, "total_revenue": {"$sum": "$total_gross"}}},
                                          {"$project": {"_id": 0, "total_revenue": {"$round": ["$total_revenue", 2]}}}], {}),
    ("Average order value", "scalar", [{"$group": {"_id": None, "avg_order_value": {"$avg": "$total_gross"}}},
                                        {"$project": {"_id": 0, "avg_order_value": {"$round": ["$avg_order_value", 2]}}}], {}),
    ("Revenue by source system", "pie", [
        {"$group": {"_id": "$source_system", "revenue": {"$sum": "$total_gross"}}},
        {"$project": {"_id": 0, "source_system": "$_id", "revenue": {"$round": ["$revenue", 2]}}}],
     {"pie.dimension": "source_system", "pie.metric": "revenue"}),
    ("Orders by status", "bar", [
        {"$group": {"_id": "$status", "orders": {"$sum": 1}}},
        {"$project": {"_id": 0, "status": "$_id", "orders": 1}}, {"$sort": {"status": 1}}],
     {"graph.dimensions": ["status"], "graph.metrics": ["orders"]}),
    ("Revenue by day", "line", [
        {"$group": {"_id": {"$dateToString": {"format": "%Y-%m-%d", "date": PARSE_DATE}}, "revenue": {"$sum": "$total_gross"}}},
        {"$project": {"_id": 0, "day": "$_id", "revenue": {"$round": ["$revenue", 2]}}}, {"$sort": {"day": 1}}],
     {"graph.dimensions": ["day"], "graph.metrics": ["revenue"]}),
    ("Top 10 products by revenue", "bar", [
        {"$unwind": "$items"},
        {"$group": {"_id": "$items.description", "revenue": {"$sum": "$items.line_total"}}},
        {"$sort": {"revenue": -1}}, {"$limit": 10},
        {"$project": {"_id": 0, "product": "$_id", "revenue": {"$round": ["$revenue", 2]}}}],
     {"graph.dimensions": ["product"], "graph.metrics": ["revenue"]}),
    ("Top customers by revenue", "bar", [
        {"$group": {"_id": "$customer.name", "revenue": {"$sum": "$total_gross"}, "orders": {"$sum": 1}}},
        {"$sort": {"revenue": -1}}, {"$limit": 10},
        {"$project": {"_id": 0, "customer": "$_id", "revenue": {"$round": ["$revenue", 2]}}}],
     {"graph.dimensions": ["customer"], "graph.metrics": ["revenue"]}),
    ("Revenue by country", "bar", [
        {"$group": {"_id": "$country", "revenue": {"$sum": "$total_gross"}}},
        {"$sort": {"revenue": -1}},
        {"$project": {"_id": 0, "country": "$_id", "revenue": {"$round": ["$revenue", 2]}}}],
     {"graph.dimensions": ["country"], "graph.metrics": ["revenue"]}),
]

RT_CARDS = [
    ("Orders last 5 minutes", "scalar", [LAST_N_MIN(5), {"$count": "orders_last_5_min"}], {}),
    ("Revenue last 5 minutes", "scalar", [LAST_N_MIN(5), {"$group": {"_id": None, "revenue_last_5_min": {"$sum": "$total_gross"}}},
                                           {"$project": {"_id": 0, "revenue_last_5_min": {"$round": ["$revenue_last_5_min", 2]}}}], {}),
    ("Avg ingestion latency (s, last 5 min)", "scalar", [LAST_N_MIN(5), {"$group": {"_id": None, "avg_latency_s": {"$avg": {
        "$dateDiff": {"startDate": PARSE_DATE, "endDate": {"$dateFromString": {"dateString": "$etl_processed_at"}}, "unit": "second"}}}}},
        {"$project": {"_id": 0, "avg_latency_s": {"$round": ["$avg_latency_s", 1]}}}], {}),
    ("Orders per minute (last 30 min)", "line", [LAST_N_MIN(30), {"$group": {"_id": {"$dateToString": {
        "format": "%H:%M", "date": PARSE_DATE, "timezone": "Europe/Rome"}}, "orders": {"$sum": 1}}},
        {"$project": {"_id": 0, "minute": "$_id", "orders": 1}}, {"$sort": {"minute": 1}}],
     {"graph.dimensions": ["minute"], "graph.metrics": ["orders"]}),
    ("Orders last 5 min by source", "bar", [LAST_N_MIN(5), {"$group": {"_id": "$source_system", "orders": {"$sum": 1}}},
        {"$project": {"_id": 0, "source_system": "$_id", "orders": 1}}],
     {"graph.dimensions": ["source_system"], "graph.metrics": ["orders"]}),
    ("Latest 20 orders", "table", [
        {"$sort": {"order_date": -1}}, {"$limit": 20},
        {"$project": {"_id": 1, "source_system": 1, "order_date": 1, "customer": "$customer.name",
                      "status": 1, "total_gross": 1, "items_count": {"$size": "$items"}}}], {}),
]


def req(method, path, token=None, **kw):
    headers = {"X-Metabase-Session": token} if token else {}
    r = requests.request(method, MB + path, headers=headers, timeout=120, **kw)
    if not r.ok:
        sys.exit(f"Metabase {method} {path} -> {r.status_code}: {r.text[:1500]}")
    return r.json() if r.text else {}


def get_session():
    login = requests.post(MB + "/session", json={"username": EMAIL, "password": PASSWORD}, timeout=30)
    if login.ok:
        return login.json()["id"]
    props = requests.get(MB + "/session/properties", timeout=30).json()
    req("POST", "/setup", json={
        "token": props["setup-token"],
        "user": {"first_name": "Pilot", "last_name": "Admin", "email": EMAIL, "password": PASSWORD,
                 "site_name": "Orders Pilot"},
        "prefs": {"site_name": "Orders Pilot", "allow_tracking": False, "site_locale": "en"}})
    print("Metabase initial setup done")
    return req("POST", "/session", json={"username": EMAIL, "password": PASSWORD})["id"]


def ensure_collection(token):
    for c in req("GET", "/collection", token):
        if c.get("name") == "Orders Pilot":
            return c["id"]
    return req("POST", "/collection", token, json={"name": "Orders Pilot", "color": "#509EE3"})["id"]


def make_dashboard(token, db_id, coll_id, name, description, cards):
    for d in req("GET", "/dashboard", token):
        if d["name"] == name and not d.get("archived"):
            print(f"dashboard '{name}' already present (id {d['id']})")
            return d["id"]
    dash = req("POST", "/dashboard", token, json={"name": name, "description": description, "collection_id": coll_id})
    dashcards, row, col = [], 0, 0
    for i, (cname, display, pipeline, viz) in enumerate(cards):
        import json as _json
        card = req("POST", "/card", token, json={
            "name": f"{name} - {cname}", "display": display, "collection_id": coll_id,
            "visualization_settings": viz,
            "dataset_query": {"type": "native", "database": db_id,
                              "native": {"collection": COLLECTION, "query": _json.dumps(pipeline)}}})
        scalar = display == "scalar"
        w, h = (6, 3) if scalar else (12, 6)
        if col + w > 24:
            row, col = row + (3 if prev_scalar else 6), 0
        dashcards.append({"id": -(i + 1), "card_id": card["id"], "row": row, "col": col, "size_x": w, "size_y": h,
                          "parameter_mappings": [], "visualization_settings": {}})
        col += w
        prev_scalar = scalar
    req("PUT", f"/dashboard/{dash['id']}", token, json={"dashcards": dashcards})
    print(f"dashboard '{name}' created (id {dash['id']}) with {len(dashcards)} cards")
    return dash["id"]


def main():
    for _ in range(60):
        try:
            if requests.get(MB + "/health", timeout=10).ok:
                break
        except requests.RequestException:
            pass
        time.sleep(5)
    token = get_session()
    dbs = req("GET", "/database", token)
    dbs = dbs["data"] if isinstance(dbs, dict) else dbs
    db = next((d for d in dbs if d["name"] == DB_NAME), None)
    if db is None:
        db = req("POST", "/database", token, json={"engine": "mongo", "name": DB_NAME, "details": {
            "host": "mongodb", "port": 27017, "dbname": os.environ.get("MONGO_DATABASE", "Ordini"),
            "user": os.environ["MONGO_USER"], "pass": os.environ["MONGO_PASSWORD"],
            "authdb": "admin", "use-conn-uri": False, "ssl": False}, "is_full_sync": True})
        print(f"MongoDB data source added (id {db['id']})")
    db_id = db["id"]
    coll_id = ensure_collection(token)
    bi = make_dashboard(token, db_id, coll_id, "Orders BI Analysis", "Business analysis of unified orders", BI_CARDS)
    rt = make_dashboard(token, db_id, coll_id, "Orders Real-Time Monitor",
                        "Incoming orders monitoring (open with #refresh=5)", RT_CARDS)
    print(f"BI dashboard:        http://localhost:{os.environ.get('PORT_METABASE', '3000')}/dashboard/{bi}")
    print(f"Real-time dashboard: http://localhost:{os.environ.get('PORT_METABASE', '3000')}/dashboard/{rt}#refresh=5")


if __name__ == "__main__":
    main()
