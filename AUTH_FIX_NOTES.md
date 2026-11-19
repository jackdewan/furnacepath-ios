# Auth state fix — 2026-11-18

Jack confirmed that demo entry worked, Exit demo left a Profile claiming Apple sign-in, and Sign out appeared to do nothing. He did not attempt Apple sign-in. The server had no Apple user. The legacy dataset remains untouched; claiming remains dry-run only.

## Root cause and changes

Profile was a sheet attached to RootView. Changing authState to signedOut did not dismiss that sheet, and Profile treated every non-demo state as Apple signed in. Thus the signed-out sheet displayed an Apple identity, zeroed stats and a Sign out button even though signOut had already cleared the session. Simulator fixtures are compiled only for DEBUG simulator and did not cause the TestFlight symptom. An earlier bootstrap also treated a stored credential as signed in after an unsuccessful refresh; restore now requires a successful authenticated state response.

Both profile actions dismiss the sheet and the root closes presented content when signed out. Profile's Apple identity and account controls require signedIn and a session token. Sign-out clears both Keychain slots, local user info and state, and requests server revocation; revocation is best effort when offline. Refresh responses are checked against the current token to prevent an old request repopulating state after sign-out. Demo failures return to sign-in.

Apple completion posts its identity token to /api/auth/apple; the backend verifies the RS256 signature using Apple's JWKS, issuer, expiration, issued-at, subject and native audience com.jackdewan.furnacepath, then creates/finds the Apple user and issues a session. iOS validates the issued session with /api/state before entering and shows a plain error if exchange or claim preview fails. Claim remains dry-run, including confirmation. Auth request logs record method, path, status and sanitized reason, without token or subject values. The backend is maintained outside git at ~/furnacepath/server.py and its service was restarted.

## Verification

The simulator workflow runs a UI regression with isolated fixtures: fresh sign-in, tap demo, open demo profile, tap Exit demo, assert sign-in returns and Apple label is absent; screenshots are attached to the auth-flow-result xcresult artifact. Backend invalid Apple input returned HTTP 401 and the service journal recorded auth_request method=POST path=/api/auth/apple outcome=401 reason=DecodeError. A real Apple authorization has not occurred: final proof of the end-to-end handshake requires Jack to retest on the new TestFlight build.

Simulator run 44432111432 compiled the app but stalled in its screenshot step; it was cancelled and its UI test did not run. TestFlight was dispatched exactly once as run 44433425874, for commit 670c8e5. Verification of the simulator screenshots and UI flow remains pending until a successful run produces its artifact. An isolated temporary database test confirmed demo logout revokes its session; a locally signed JWT test confirmed rejection of wrong signature, issuer, audience and expiry.
