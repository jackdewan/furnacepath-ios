#!/usr/bin/env python3
"""Create one distribution certificate and save its identity as repository secrets."""
import base64
import datetime
import os
import secrets
import subprocess

import requests
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives.serialization import pkcs12
from cryptography.x509.oid import NameOID
from list_certs import BASE, token

session = requests.Session()
session.headers['Authorization'] = 'Bearer ' + token()

def secret(name, value):
    subprocess.run(['gh', 'secret', 'set', name, '--repo', os.environ['GITHUB_REPOSITORY']], input=value, check=True, stdout=subprocess.DEVNULL)

response = session.get(BASE + '/v1/certificates?limit=100', timeout=30)
response.raise_for_status()
page = response.json()
if page.get('links', {}).get('next') or len(page['data']) != 1 or page['data'][0]['id'] != '8536CS4W6C':
    raise SystemExit('Expected exactly the personal certificate before creating a distribution certificate.')
existing = subprocess.run(['gh', 'secret', 'list', '--repo', os.environ['GITHUB_REPOSITORY']], check=True, capture_output=True, text=True).stdout
if any(line.split()[0] in {'BUILD_CERTIFICATE_BASE64', 'P12_PASSWORD', 'CI_SIGNING_RECOVERY_KEY'} for line in existing.splitlines() if line.split()):
    raise SystemExit('Signing or recovery secrets already exist; refusing to create another certificate.')
key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
private = key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption())
# Preserve the key before the irreversible API call, in case a later step fails.
secret('CI_SIGNING_RECOVERY_KEY', base64.b64encode(private))
csr = (x509.CertificateSigningRequestBuilder().subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, 'FurnacePath CI')])).sign(key, hashes.SHA256()))
response = session.post(BASE + '/v1/certificates', json={'data': {'type': 'certificates', 'attributes': {'certificateType': 'DISTRIBUTION', 'csrContent': csr.public_bytes(serialization.Encoding.PEM).decode()}}}, timeout=30)
if not response.ok:
    print(f'Certificate creation failed: HTTP {response.status_code} {response.text[:1000]}')
    response.raise_for_status()
data = response.json()['data']
print('Created distribution certificate ' + data['id'], flush=True)
cert = x509.load_der_x509_certificate(base64.b64decode(data['attributes']['certificateContent']))
password = secrets.token_urlsafe(32).encode()
encryption = (serialization.PrivateFormat.PKCS12.encryption_builder()
              .kdf_rounds(50000)
              .key_cert_algorithm(pkcs12.PBES.PBESv1SHA1And3KeyTripleDESCBC)
              .hmac_hash(hashes.SHA1()).build(password))
p12 = pkcs12.serialize_key_and_certificates(b'FurnacePath CI', key, cert, None, encryption)
secret('P12_PASSWORD', password)
secret('BUILD_CERTIFICATE_BASE64', base64.b64encode(p12))
secret('DISTRIBUTION_CERTIFICATE_ID', data['id'].encode())
subprocess.run(['gh', 'secret', 'delete', 'CI_SIGNING_RECOVERY_KEY', '--repo', os.environ['GITHUB_REPOSITORY']], check=True, stdout=subprocess.DEVNULL)
print('Distribution identity stored as repository secrets.')
