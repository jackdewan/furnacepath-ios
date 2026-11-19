#!/usr/bin/env python3
"""Revoke only the ten explicitly approved development certificates."""
import requests
from list_certs import BASE, token

IDS = ('2YTS834V8T', '3XY2646WS3', '5448NSSF4G', '88DS2K4AFD', '92JTZ9SYV8', 'DTQADKL3Q7', 'J27F5YQ6CG', 'R27XQQXBKX', 'RDBAK99L6Q', 'WN748B3X58')
PERSONAL = '8536CS4W6C'
session = requests.Session()
session.headers['Authorization'] = 'Bearer ' + token()

def check(cert_id):
    response = session.get(f'{BASE}/v1/certificates/{cert_id}', timeout=30)
    response.raise_for_status()
    data = response.json()['data']
    a = data['attributes']
    if data['id'] != cert_id or a.get('displayName') != 'Created via API' or a.get('certificateType') != 'DEVELOPMENT':
        raise SystemExit(f'Certificate {cert_id} does not match the approved criteria; aborting.')

# Check every target before any destructive operation, then recheck immediately before each deletion.
for cert_id in IDS:
    check(cert_id)
for cert_id in IDS:
    check(cert_id)
    response = session.delete(f'{BASE}/v1/certificates/{cert_id}', timeout=30)
    response.raise_for_status()
    print(f'Revoked {cert_id}', flush=True)
url = BASE + '/v1/certificates?limit=100'
remaining = []
while url:
    response = session.get(url, timeout=30)
    response.raise_for_status()
    page = response.json()
    remaining.extend(page['data'])
    url = page.get('links', {}).get('next')
if len(remaining) != 1 or remaining[0]['id'] != PERSONAL:
    raise SystemExit('Verification failed: expected only personal certificate 8536CS4W6C.')
print('Verified one certificate remains: 8536CS4W6C')
