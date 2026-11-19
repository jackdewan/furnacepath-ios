# Overnight notes — 2026-11-18

## Demo flow diagnosis and fix

The live API base is `http://100.87.179.24:3011`. A normal demo entry POSTs `{}` to `api/auth/demo`; request, decoding, or session-storage failures propagate to `AuthView`, which displays “Couldn't start the demo. Check your connection and try again.”

The CI test does **not** use that live endpoint: `AuthFlowTests` launches with `--verify-screen auth-flow`; the Debug simulator build defines `DEBUG`, and `API.request` intercepts verification requests. The existing fixture supplies the demo POST response and all refresh data. The screenshot workflow likewise uses `--verify-screen` fixtures. The prior failure's UI error alone does not identify its underlying error; the prior logs did not record a keychain status. Given the fixture path, the unsigned simulator build (`CODE_SIGNING_ALLOWED=NO`), and the successful result after isolating session storage, the simulator keychain write is the supported cause, although its exact Security framework error was not captured.

Commit `6fd1a2e` makes session storage in-memory only for opt-in Debug simulator verification. The real app continues to use the keychain. The unchanged UI test enters demo through the fixture, opens profile, exits demo, and verifies sign-in.

- Fix build: [44446595533](https://github.com/jackdewan/furnacepath-ios/actions/runs/44446595533), green including demo sign-out.
- M13b merge: `17e10b8390c8fb343e4a6c1c692a7dd822dac142`.
- Combined main build: [44448946673](https://github.com/jackdewan/furnacepath-ios/actions/runs/44448946673), green including demo sign-out.
- Screenshots from the combined run: `verify-m13b/` on main, committed as `07798af`. `sim.png` shows all three generic plants.

## TestFlight blocker

The one authorized delivery dispatch, [44451434466](https://github.com/jackdewan/furnacepath-ios/actions/runs/44451434466), checked out main at `07798af` but **failed before archive and upload**. Xcode reported the Apple account has reached its certificate maximum and asked for a certificate to be revoked; it also reported no matching iOS App Development provisioning profile. No build was uploaded and there is no uploaded build version for this run. The workflow would have stamped marketing version `1.0`, build `2000.12`, had it reached the archive, but this is not an uploaded version.

Clearing the signing capacity and provisioning issue requires choosing how to handle the existing certificates; no certificate was revoked. The user explicitly limited this task to one TestFlight dispatch, so no second delivery was started.

Claim remains dry-run only. No backend or P51 data was modified.
