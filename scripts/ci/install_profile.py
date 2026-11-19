#!/usr/bin/env python3
"""Fetch or create the App Store profile for the stored distribution certificate."""
import base64
import os
from pathlib import Path
import requests
from list_certs import BASE, token

s = requests.Session()
s.headers['Authorization'] = 'Bearer ' + token()

def get_all(path, params=None):
    url = BASE + path
    items = []
    while url:
        r = s.get(url, params=params, timeout=30)
        r.raise_for_status()
        page = r.json()
        items.extend(page['data'] if isinstance(page['data'], list) else [page['data']])
        url = page.get('links', {}).get('next')
        params = None
    return items

bundle = get_all('/v1/bundleIds', {'filter[identifier]': 'com.jackdewan.furnacepath', 'limit': 100})
if len(bundle) != 1:
    raise SystemExit('Expected exactly one FurnacePath bundle ID.')
bundle_id = bundle[0]['id']
cert_id = os.environ['DISTRIBUTION_CERTIFICATE_ID']
profiles = get_all('/v1/profiles', {'filter[profileType]': 'IOS_APP_STORE', 'limit': 100})
matches = []
for profile in profiles:
    if profile['attributes'].get('profileState') != 'ACTIVE':
        continue
    pid = profile['id']
    ids = get_all(f'/v1/profiles/{pid}/bundleId')
    certs = get_all(f'/v1/profiles/{pid}/certificates')
    if any(x['id'] == bundle_id for x in ids) and {x['id'] for x in certs} == {cert_id}:
        matches.append(profile)
if len(matches) > 1:
    raise SystemExit('Multiple active matching App Store profiles found; refusing to choose.')
if not matches:
    payload = {'data': {'type': 'profiles', 'attributes': {'name': 'FurnacePath CI App Store', 'profileType': 'IOS_APP_STORE'}, 'relationships': {'bundleId': {'data': {'type': 'bundleIds', 'id': bundle_id}}, 'certificates': {'data': [{'type': 'certificates', 'id': cert_id}]}}}}
    r = s.post(BASE + '/v1/profiles', json=payload, timeout=30)
    if not r.ok:
        print(f'Profile creation failed: HTTP {r.status_code} {r.text[:1000]}')
        r.raise_for_status()
    matches = [r.json()['data']]
profile = matches[0]
a = profile['attributes']
path = Path.home() / 'Library/MobileDevice/Provisioning Profiles' / (a['uuid'] + '.mobileprovision')
path.parent.mkdir(parents=True, exist_ok=True)
path.write_bytes(base64.b64decode(a['profileContent']))
with open(os.environ['GITHUB_ENV'], 'a') as f:
    f.write('PROFILE_UUID=' + a['uuid'] + '\n')
print('Installed App Store profile ' + profile['id'])
