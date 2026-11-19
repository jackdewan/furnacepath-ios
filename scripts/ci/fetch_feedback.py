import json, os, sys, time
import urllib.request, urllib.error

import jwt  # PyJWT

KEY_ID = os.environ["ASC_KEY_ID"]
ISSUER = os.environ["ASC_ISSUER_ID"]
KEY_PATH = os.environ["ASC_KEY_PATH"]
BUNDLE_ID = "com.jackdewan.furnacepath"
BASE = "https://api.appstoreconnect.apple.com"

with open(KEY_PATH) as f:
    key_pem = f.read()

now = int(time.time())
token = jwt.encode(
    {"iss": ISSUER, "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"},
    key_pem,
    algorithm="ES256",
    headers={"kid": KEY_ID, "typ": "JWT"},
)

def get(path):
    req = urllib.request.Request(BASE + path, headers={"Authorization": f"Bearer {token}"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace")[:500]
        return e.code, {"error": body}
    except Exception as e:
        return None, {"error": str(e)}

status, apps = get(f"/v1/apps?filter[bundleId]={BUNDLE_ID}&limit=5")
print("apps lookup status:", status)
if status != 200 or not apps.get("data"):
    print(json.dumps(apps)[:800])
    sys.exit(1)
app_id = apps["data"][0]["id"]
print("app id:", app_id)

candidates = [
    f"/v1/apps/{app_id}/betaFeedback?limit=50",
    f"/v1/apps/{app_id}/betaFeedbacks?limit=50",
]
found = None
for path in candidates:
    status, data = get(path)
    print("tried", path, "->", status)
    if status == 200:
        found = data
        with open("feedback_raw.json", "w") as f:
            json.dump(data, f, indent=2)
        break
    else:
        print(json.dumps(data)[:300])

lines = []
if found is None:
    lines.append("NO_FEEDBACK_ENDPOINT_WORKED")
else:
    items = found.get("data", [])
    lines.append(f"FEEDBACK_COUNT: {len(items)}")
    included = { (i.get("type"), i.get("id")): i for i in found.get("included", []) }
    for it in items:
        a = it.get("attributes", {})
        lines.append("---")
        for k in ("createdDate", "comment", "email", "deviceModel", "deviceFamily", "osVersion", "appVersion", "bundleVersion", "submissionType", "architecture", "batteryPercentage", "diskTotal", "diskFree", "locale", "timeZone"):
            if a.get(k) is not None:
                lines.append(f"{k}: {a[k]}")
        rels = it.get("relationships", {})
        lines.append(f"relationships: {list(rels.keys())}")
        for rname, rval in rels.items():
            rdata = rval.get("data")
            if isinstance(rdata, dict) and (rdata.get("type"), rdata.get("id")) in included:
                inc = included[(rdata.get("type"), rdata.get("id"))]
                lines.append(f"{rname}: {json.dumps(inc.get('attributes', {}))[:400]}")
        # screenshot / attachment urls if present anywhere in attributes
        for k, v in a.items():
            if isinstance(v, str) and v.startswith("http"):
                lines.append(f"{k} URL: {v}")

with open("feedback.txt", "w") as f:
    f.write("\n".join(lines))
print("\n".join(lines)[:3000])
