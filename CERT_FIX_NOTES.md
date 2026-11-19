# Certificate and TestFlight signing repair — 2026-11-19

## Revoked certificates

The approved DEVELOPMENT certificates named “Created via API” were checked and revoked in run 44505395737:

- 2YTS834V8T
- 3XY2646WS3
- 5448NSSF4G
- 88DS2K4AFD
- 92JTZ9SYV8
- DTQADKL3Q7
- J27F5YQ6CG
- R27XQQXBKX
- RDBAK99L6Q
- WN748B3X58

The workflow verified that only Jack's personal certificate remained after revocation.

## Signing setup

A single Apple Distribution certificate, `766A7QKUPN`, was created in setup run 44505658565. Its private key and certificate are kept together as a password-protected PKCS#12 identity in GitHub repository secrets. The delivery workflow imports that identity into a temporary keychain, fetches or creates an active App Store provisioning profile for `com.jackdewan.furnacepath` tied to this certificate, and signs the archive and export manually. It does not request automatic provisioning. Simulator build and test commands explicitly disable signing; the screenshot helper also disables signing.

Persistent secret names created: `BUILD_CERTIFICATE_BASE64`, `P12_PASSWORD`, `DISTRIBUTION_CERTIFICATE_ID`. A temporary `CI_SECRETS_ADMIN_TOKEN` was used to write secrets and removed; the temporary `CI_SIGNING_RECOVERY_KEY` was removed after the identity was stored. The original ASC API secrets remain in place.

The initial TestFlight attempt failed when macOS rejected the original PKCS#12 encryption format. Conversion run 44505940011 rewrote the same stored identity in a compatible format, and the failed job was retried on the same run; no additional certificate was created. The setup script now creates the compatible format directly.

## Delivery and verification

- TestFlight workflow run: 44505752970, attempt 2 — manual archive and export succeeded; upload succeeded.
- Uploaded version: **1.0**, build **2000.13**.
- Apple reported one upload warning: beginning April 2027, uploads require the iOS 27 SDK or later; this build used the iOS 26.5 SDK.
- Certificate list workflow run 44506453921 returned exactly **two** certificates:
  - `8536CS4W6C` — DEVELOPMENT, Apple Development: Jack Dewan (personal certificate).
  - `766A7QKUPN` — DISTRIBUTION, Apple Distribution: Jack Dewan.

The claim remains dry-run only; app source, backend, and user data were not changed.
