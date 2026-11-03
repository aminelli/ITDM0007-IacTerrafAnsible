"""Registers (idempotently) all Kafka Connect connectors found in /app/connectors."""
import glob
import json
import os
import string
import sys
import time

import requests

CONNECT_URL = os.environ.get("CONNECT_URL", "http://connect:8083")
TIMEOUT = 180


def main():
    names = []
    for path in sorted(glob.glob("/app/connectors/*.json")):
        with open(path, encoding="utf-8") as fh:
            definition = json.loads(string.Template(fh.read()).safe_substitute(os.environ))
        name = definition["name"]
        r = requests.put(f"{CONNECT_URL}/connectors/{name}/config", json=definition["config"], timeout=30)
        r.raise_for_status()
        print(f"registered {name}", flush=True)
        names.append(name)

    deadline = time.time() + TIMEOUT
    pending = set(names)
    while pending and time.time() < deadline:
        for name in list(pending):
            resp = requests.get(f"{CONNECT_URL}/connectors/{name}/status", timeout=30)
            if resp.status_code != 200:
                continue
            st = resp.json()
            states = [st["connector"]["state"]] + [t["state"] for t in st.get("tasks", [])]
            if "FAILED" in states:
                print(json.dumps(st, indent=2))
                sys.exit(f"connector {name} FAILED")
            if st.get("tasks") and all(s == "RUNNING" for s in states):
                print(f"{name}: RUNNING", flush=True)
                pending.discard(name)
        time.sleep(3)
    if pending:
        sys.exit(f"timeout waiting for: {pending}")


if __name__ == "__main__":
    main()
