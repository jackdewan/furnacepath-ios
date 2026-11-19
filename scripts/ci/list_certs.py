#!/usr/bin/env python3
"""List App Store Connect certificates (read-only) via the ASC API.
Reads ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_PATH from the environment.
Writes certs.txt + certs_raw.json. Never prints the token."""
import json
import os
import time

import jwt
import requests

KEY_ID = os.environ["ASC_KEY_ID"]
ISSUER_ID = os.environ["ASC_ISSUER_ID"]
KEY_PATH = os.environ["ASC_KEY_PATH"]
BASE = "https://api.appstoreconnect.apple.com"


def token():
    with open(KEY_PATH, "r", encoding="utf-8") as fh:
        private_key = fh.read()
    now = int(time.time())
    payload = {"iss": ISSUER_ID, "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"}
    return jwt.encode(payload, private_key, algorithm="ES256", headers={"kid": KEY_ID, "typ": "JWT"})


def main():
    headers = {"Authorization": "Bearer " + token()}
    out = []
    raw = {}
    url = BASE + "/v1/certificates?limit=100"
    resp = requests.get(url, headers=headers, timeout=30)
    raw["status"] = resp.status_code
    try:
        raw["body"] = resp.json()
    except Exception:
        raw["body"] = resp.text[:2000]
    if resp.status_code == 200:
        for item in resp.json().get("data", []):
            a = item.get("attributes", {})
            out.append({
                "id": item.get("id"),
                "name": a.get("name"),
                "displayName": a.get("displayName"),
                "certificateType": a.get("certificateType"),
                "serialNumber": a.get("serialNumber"),
                "expirationDate": a.get("expirationDate"),
                "platform": a.get("platform"),
            })
    with open("certs_raw.json", "w", encoding="utf-8") as fh:
        json.dump(raw, fh, indent=2)
    with open("certs.txt", "w", encoding="utf-8") as fh:
        fh.write(f"CERT_COUNT {len(out)} STATUS {raw['status']}\n")
        for c in out:
            fh.write(json.dumps(c) + "\n")
    print(f"certificates: {len(out)} (http {raw['status']})")


if __name__ == "__main__":
    main()
