"""Order generator: creates one order (with items) every N seconds on MySQL or PostgreSQL.

Each order is written in a single transaction together with an outbox row whose payload
contains the whole aggregate (order + items). Debezium captures the outbox table.
"""
import json
import os
import random
import sys
import time
import uuid
from datetime import datetime, timezone
from decimal import Decimal

TARGET = os.environ["TARGET_DB"]  # mysql | postgres
INTERVAL = float(os.environ.get("INTERVAL_SECONDS", "5"))

CUSTOMERS = [
    ("C001", "Acme Corp"), ("C002", "Globex Srl"), ("C003", "Initech SpA"),
    ("C004", "Umbrella Italia"), ("C005", "Stark Industries"), ("C006", "Wayne Logistics"),
    ("C007", "Wonka Foods"), ("C008", "Hooli Europe"), ("C009", "Soylent Group"),
    ("C010", "Cyberdyne Systems"),
]
PRODUCTS = [
    ("SKU-1001", "Laptop 14 inch", Decimal("899.00")), ("SKU-1002", "Wireless Mouse", Decimal("19.90")),
    ("SKU-1003", "Mechanical Keyboard", Decimal("79.50")), ("SKU-1004", "USB-C Dock", Decimal("129.00")),
    ("SKU-1005", "27 inch Monitor", Decimal("249.00")), ("SKU-1006", "Webcam HD", Decimal("49.90")),
    ("SKU-1007", "Headset", Decimal("59.00")), ("SKU-1008", "External SSD 1TB", Decimal("99.00")),
]
COUNTRIES = ["IT", "DE", "FR", "ES", "NL"]
VAT = Decimal("0.22")


def money(value):
    return value.quantize(Decimal("0.01"))


def build_order():
    code, name = random.choice(CUSTOMERS)
    lines = []
    for n, (sku, desc, price) in enumerate(random.sample(PRODUCTS, random.randint(1, 4)), start=1):
        qty = random.randint(1, 5)
        lines.append({"n": n, "sku": sku, "desc": desc, "qty": qty, "price": price, "total": money(price * qty)})
    net = sum(l["total"] for l in lines)
    vat = money(net * VAT)
    return {
        "code": code, "name": name, "lines": lines, "net": net, "vat": vat, "gross": net + vat,
        "country": random.choice(COUNTRIES), "ts": datetime.now(timezone.utc),
    }


def iso(ts):
    return ts.strftime("%Y-%m-%dT%H:%M:%S.") + f"{ts.microsecond // 1000:03d}Z"


def connect_mysql():
    import pymysql
    return pymysql.connect(
        host="mysql", user="root", password=os.environ["MYSQL_ROOT_PASSWORD"],
        database=os.environ["MYSQL_DATABASE"], autocommit=False,
    )


def connect_postgres():
    import psycopg2
    return psycopg2.connect(
        host="postgres", user=os.environ["POSTGRES_USER"],
        password=os.environ["POSTGRES_PASSWORD"], dbname=os.environ["POSTGRES_DB"],
    )


def insert_mysql(conn, o):
    status = "NEW"
    with conn.cursor() as cur:
        cur.execute(
            "INSERT INTO orders (customer_code, customer_name, order_datetime, order_status, net_amount,"
            " tax_amount, total_amount, currency, ship_country) VALUES (%s,%s,%s,%s,%s,%s,%s,'EUR',%s)",
            (o["code"], o["name"], o["ts"].replace(tzinfo=None), status, o["net"], o["vat"], o["gross"], o["country"]),
        )
        order_id = cur.lastrowid
        for l in o["lines"]:
            cur.execute(
                "INSERT INTO order_items (order_id, line_no, product_sku, product_name, quantity, unit_price,"
                " line_total) VALUES (%s,%s,%s,%s,%s,%s,%s)",
                (order_id, l["n"], l["sku"], l["desc"], l["qty"], l["price"], l["total"]),
            )
        payload = {
            "order_id": order_id, "customer_code": o["code"], "customer_name": o["name"],
            "order_datetime": iso(o["ts"]), "order_status": status, "net_amount": o["net"],
            "tax_amount": o["vat"], "total_amount": o["gross"], "currency": "EUR", "ship_country": o["country"],
            "items": [
                {"line_no": l["n"], "product_sku": l["sku"], "product_name": l["desc"], "quantity": l["qty"],
                 "unit_price": l["price"], "line_total": l["total"]} for l in o["lines"]
            ],
        }
        cur.execute(
            "INSERT INTO order_outbox (aggregate_type, aggregate_id, event_type, payload) VALUES (%s,%s,%s,%s)",
            ("order", str(order_id), "OrderCreated", json.dumps(payload, default=float)),
        )
    conn.commit()
    return order_id


def insert_postgres(conn, o):
    state = "created"
    customer_id = str(uuid.uuid5(uuid.NAMESPACE_DNS, o["code"]))
    with conn.cursor() as cur:
        cur.execute(
            "INSERT INTO sales_orders (customer_id, customer_full_name, created_at, state, amount_net, amount_vat,"
            " amount_gross, currency_code, country_code) VALUES (%s,%s,%s,%s,%s,%s,%s,'EUR',%s) RETURNING id",
            (customer_id, o["name"], o["ts"], state, o["net"], o["vat"], o["gross"], o["country"]),
        )
        order_id = cur.fetchone()[0]
        for l in o["lines"]:
            cur.execute(
                "INSERT INTO sales_order_lines (order_id, line_number, item_code, item_description, qty, price_net,"
                " line_net) VALUES (%s,%s,%s,%s,%s,%s,%s)",
                (order_id, l["n"], l["sku"], l["desc"], l["qty"], l["price"], l["total"]),
            )
        payload = {
            "id": order_id, "customer": {"id": customer_id, "full_name": o["name"]},
            "created_at": iso(o["ts"]), "state": state, "amount_net": o["net"], "amount_vat": o["vat"],
            "amount_gross": o["gross"], "currency_code": "EUR", "country_code": o["country"],
            "lines": [
                {"line_number": l["n"], "item_code": l["sku"], "item_description": l["desc"], "qty": l["qty"],
                 "price_net": l["price"], "line_net": l["total"]} for l in o["lines"]
            ],
        }
        cur.execute(
            "INSERT INTO order_outbox (aggregate_type, aggregate_id, event_type, payload) VALUES (%s,%s,%s,%s)",
            ("order", str(order_id), "OrderCreated", json.dumps(payload, default=float)),
        )
    conn.commit()
    return order_id


def main():
    connect, insert = (connect_mysql, insert_mysql) if TARGET == "mysql" else (connect_postgres, insert_postgres)
    conn = None
    while True:
        started = time.monotonic()
        try:
            if conn is None:
                conn = connect()
            order_id = insert(conn, build_order())
            print(f"[{TARGET}] created order {order_id}", flush=True)
        except Exception as exc:  # reconnect on next cycle
            print(f"[{TARGET}] error: {exc}", file=sys.stderr, flush=True)
            try:
                conn and conn.close()
            except Exception:
                pass
            conn = None
        time.sleep(max(0.0, INTERVAL - (time.monotonic() - started)))


if __name__ == "__main__":
    main()
