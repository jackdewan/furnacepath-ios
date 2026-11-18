# M11 — FurnacePath iOS

## Phase A
- Implemented native SwiftUI iOS 17 thin client: Path with all server units/lessons available, Sprint, CEO Rep, numeric/MC lesson player, explanations, tutor reasoning/confidence, saved results, Drills, spaced Review, tutor feedback, Mastery/Coach/Owner Track.
- Fetches content and progress dynamically from P51; loading, Tailscale failure banner/Retry, foreground and pull refresh preserve open lesson inputs.
- XcodeGen configuration, simulator build workflow, manual TestFlight TODO stub and networking documentation added. No question data, databases, credentials or signing assets committed.
- Validation: backend/web contract inspected; initial simulator CI **GREEN** (no correction iterations): https://github.com/jackdewan/furnacepath-ios/actions/runs/43949233972 (commit 8464aad). Live learning writes intentionally not used for validation against Jack's production progress.

## Phase B
- Implemented after Phase A green: dynamic plant/furnace setup, starting position, active-run resume, capacity-aware jobs and player pricing, standing decisions, Woodworth overflow, event cards, P&L, final scoring/weak spots, tutor debriefs, completed-run history and confirmed abandon. All simulation state/processing stays on P51.
- Simulator CI **GREEN on initial build** (no correction iterations), commit e494821: https://github.com/jackdewan/furnacepath-ios/actions/runs/43949776035. No production sim writes performed.
- Isolated backend contract verification passed using a disposable temporary SQLite database: 103 active question schemas; correct/incorrect learning submissions; reasoning/confidence queued for tutor; normal review spacing advanced to three days; separate manual review update; all five plants; 57 simulated months including both finished and game_over; history and abandon. Endpoint response required fields/types checked against native models. This is backend/schema validation, not native runtime UI testing.
- Remaining limits: actual iPhone interaction/Tailscale transport not exercised; signing/TestFlight awaits Jack. Both implementation acceptance builds are green; documentation-only follow-ups use the same workflow.

## M11c: TestFlight Delivery Pipeline
- Status: **PIPELINE IMPLEMENTED; DELIVERY BLOCKED ON APP STORE CONNECT APP RECORD** — 2026-11-16 (runs dated November 17 UTC).
- Replaced the manual TestFlight stub with a macos-latest workflow_dispatch pipeline: XcodeGen generation, private temporary API key decoding, signing-team discovery from Apple certificate metadata (optional team_id input / APPLE_TEAM_ID variable override), automatic-signing archive and IPA export using App Store Connect authentication flags, then altool API-key upload with explicit delivery-success verification. Build numbers use workflow run number and attempt.
- Existing bundle ID is already `com.jackdewan.furnacepath`; project.yml needed no identifier change. The project was regenerated successfully on both macOS runs. The unsigned build.yml file is unchanged.
- Credentials are confined to the runner's private temporary directory, removed with an always-run cleanup step, and excluded from commits/artifacts. JWT authentication stays in process memory; no key, base64 key value, or JWT was written to repository files or diagnostic logs. Added ignore rules for .p8, .ipa and .xcarchive.
- Attempt 1, commit 8139c56: https://github.com/jackdewan/furnacepath-ios/actions/runs/44001196584 — API authentication/team discovery, archive and export **PASSED**. altool failed: `Cannot determine the Apple ID from Bundle ID 'com.jackdewan.furnacepath' and platform 'IOS'. (19)`. Updated missing-app detection to recognize this exact error.
- **Final delivery run (attempt 2), commit a58c0bf: https://github.com/jackdewan/furnacepath-ios/actions/runs/44001388394 — FAILED / NOT DELIVERED.** Archive/export passed again; missing-app fallback ran and confirmed installed fastlane produce has no API-key authentication option. No altool delivery-success message was received. Stopped after two attempts because further identical retries cannot create the missing record with the supplied authentication method.
- Fastlane explicitly documents produce API-key support as **No**: https://docs.fastlane.tools/app-store-connect-api/. The fallback checks capability and fails clearly without prompting for Apple ID credentials; it can invoke produce and retry upload if a future installed version supports api_key. Automatic app-record creation with the currently supplied API key cannot be completed using produce.
- Required next action: create an iOS app named **FurnacePath** in App Store Connect, using bundle ID **com.jackdewan.furnacepath**, primary language **English**, SKU **com.jackdewan.furnacepath**. Then run `gh workflow run testflight.yml --ref main`. Delivery remains incomplete until altool reports success; later Apple validation errors may still require fixes.
- Unsigned simulator build **GREEN** for final pipeline commit a58c0bf: https://github.com/jackdewan/furnacepath-ios/actions/runs/44001389650. Workflow YAML parsed and git diff whitespace checks passed. Local Ruby/Xcode are unavailable; both scripts were exercised by the macOS runner.

## TestFlight validation fix — 2026-11-16
- Diagnosed run 44002613901 (`3f6bda4`): archive/export reached altool, which rejected the bundle with 90022 (missing 120×120 iPhone icon), 90713 (missing CFBundleIconName), 90023 (missing 152×152 iPad icon), and 90474 (missing supported orientations). The earlier app-record blocker is superseded by these validation errors.
- Added an opaque furnace/flame AppIcon asset catalog with 18 iPhone, iPad, and App Store slots, including 120×120, 152×152, 167×167, 180×180, and 1024×1024 PNGs. Set ASSETCATALOG_COMPILER_APPICON_NAME to AppIcon so Xcode compiles the icons and merges the generated icon metadata into the bundle.
- Added checked-in FurnacePath/Info.plist and matching XcodeGen properties with CFBundleIconName=AppIcon and all four supported orientations for both the default and iPad-specific keys; retained existing networking and scene settings.
- Validation: all asset filenames, PNG dimensions, RGB opacity, required device/marketing icon slots, plist/project property consistency, and orientation lists passed local checks; git diff --check passed. Xcode/archive/altool verification requires the macOS workflow (unavailable locally). No web app, database, credentials, keys, or JWTs were modified or printed.
- Next: push this fix to main and dispatch testflight.yml; record the new run below after confirming it starts. Upload success remains unverified until that run completes.
- Fix committed and pushed as `2c38a6d`. Dispatched https://github.com/jackdewan/furnacepath-ios/actions/runs/44004897300 against that exact SHA. GitHub reports the `deliver` job **in_progress**, started at 2026-11-17 02:42:07 UTC. This confirms the replacement workflow started; altool delivery is still pending.

## M11d — contrast tokens, warm glass, export compliance (2026-11-17)
- Root cause: fixed light paper surfaces inherited dark system appearance for navigation chrome; the presented lesson NavigationStack also lacked the root ink foreground. Centralized a light semantic environment and ink foreground at the app and sheet boundaries, covering Path, Drills, Review, Mastery/Coach/Owner Track, lesson/results, and every sim setup/month/result/debrief surface. Paper is #FFF8EC, ink #1B2230; orange remains a control/selection accent. Answer choices now use white cards, ink labels, and an orange selection border. Error/explanation body text uses ink.
- Replaced native dark glass tabs with a warm-white translucent material capsule, ink labels/icons and safety-orange active icon/pill. Set ITSAppUsesNonExemptEncryption=false in project.yml and the checked-in plist; set default build 12 (TestFlight continues to use monotonically increasing workflow run/attempt numbers).
- Added opt-in Debug simulator fixtures and screenshot capture in build.yml. Verification intercepts every API request before networking, rejects all POSTs/unknown routes, and is disabled on device/Release; no production progress/database writes. Synthetic progress/coach data and public content only. Device appearance is explicitly dark to reproduce the original conditions.
- Simulator build, screenshot visual audit, and TestFlight upload: pending; results to be recorded after CI.

## M13 triangulation — 2026-11-18
- Independent review before implementation: the fixed 390×844 mockups omit scrolling, safe-area insets, keyboard accommodation, and Dynamic Type; native layouts must adapt and keep controls reachable at SE width and accessibility sizes. The selected-answer check suggests correctness before grading; the accepted critique supersedes the mock and reserves it for feedback. The Path mock promotes Sprint over the next lesson; the accepted state-first hierarchy puts the current unit first.
- CSS contains dark-mode tokens, an orange button glow, low-contrast muted text, and small orange labels; these conflict with the light-only, near-shadowless and contrast requirements. Use SF system type, text-grade dark orange and muted ink, with green and restrained danger reserved for semantic states. White type is appropriate on the dark hero and sufficiently dark filled controls, not on pale surfaces. Use role-based concentric radii and native material with legible contrast, rather than literal CSS backdrop filters.
- The mockups do not design feedback, keyboard-driven thinking questions, month-end, or account controls. Proposed surfaces: a bottom feedback panel with result, explanation and Continue; scrollable thinking form with keyboard-safe action; month-end summary with P&L, events and continuation; a reachable profile sheet with claim, pairing and sign-out/demo controls. The mock's fixed job columns and stat grid need adaptive stacking for large text.
- Authentication requires explicit, verified-Apple-only claim confirmation despite the brief's earlier first-sign-in wording; disposable demo identity and per-request server scoping must precede exposing demo writes. Pairing needs expiration and attempt limits, and the tailnet legacy fallback must close permanently after first pairing. The migration must preserve a consistent SQLite backup and verify existing values before changes. No deviations implemented yet; record any further departures here.
- Pre-migration backup: `/home/j/furnacepath/data/m13-pre-migration-backup.sqlite3`; SQLite integrity_check returned `ok`. The backup's progress row and the live legacy `/api/state` both reported 880 XP and a streak of 1. No claim or migration has occurred.
- Status: **M13 NOT IMPLEMENTED OR VERIFIED**. The existing backend uses singleton progress and globally scoped tables, so implementing authentication without first migrating every state and tutor access path would expose or corrupt account data. No backend auth, iOS redesign, demo, screenshots, or TestFlight upload has been completed in this pass. Local host is Linux and has no Xcode/simulator; simulator and upload verification require the macOS GitHub workflows after implementation. Existing encryption setting is already false; build number has not been bumped.

## M13 implementation progress — 2026-11-18
- Rechecked `/home/j/furnacepath/data/m13-pre-migration-backup.sqlite3` read-only: SQLite integrity check `ok`, 880 XP, streak 1. The live legacy `/api/state` also returned 880 XP and streak 1. No migration or claim was performed.
- Changed the backend entry point to use `ThreadingHTTPServer`. Tested 24 concurrent state requests against a temporary copy of the backup; all returned the expected XP and streak. This source change has not been deployed or tested with the future auth/data migration.
- M13a remains incomplete: per-user data isolation, auth, demo, pairing, iOS plumbing and simulator claim dry-run are not implemented. The live claim remains unavailable. M13b, its screenshots, and TestFlight upload have not been started because the M13a verification gate has not passed. The web legacy session remains in its existing pre-pairing state.

## M13 continuation — 2026-11-18
- Reverified the pre-migration backup read-only: integrity `ok`, 880 XP, streak 1. No database migration or claim was performed.
- Removed global `NSAllowsArbitraryLoads` from both XcodeGen configuration and checked-in plist, retaining the `100.87.179.24` exception; bumped the default build to 13. A local plist check and `git diff --check` passed. Simulator networking and build remain unverified.
- M13a is incomplete; the existing threaded server source was already present. Per-user isolation, Apple auth, demo and pairing, iOS auth and the simulator claim dry-run remain outstanding. Live claim remains unavailable. M13b and TestFlight were not started because the M13a verification gate has not passed.

## M13 continuation — backup and auth foundations

- Rechecked `~/furnacepath/data/m13-pre-migration-backup.sqlite3` read-only with SQLite: integrity `ok`, progress 880 XP and streak 1. The local legacy `/api/state` also reports 880 XP. No migration or production database write was performed.
- Added a Keychain wrapper with separate real and demo slots and a distinct API error for HTTP 401. These are foundations only: no session is issued or selected, no Authorization header or auth state is wired, and the app is not authenticated. No live claim exists.
- The source already uses `ThreadingHTTPServer`; the existing project configuration scopes ATS to the tailnet IP and declares the encryption setting. M13a remains incomplete and unverified. Linux has no Xcode or simulator; no simulator screenshots or build were run in this continuation. M13b and TestFlight remain gated on M13a verification. The web legacy session remains in its existing pre-pairing state.

### M13a backend attempt — 2026-11-18 (incomplete)

- Rechecked `~/furnacepath/data/m13-pre-migration-backup.sqlite3` read-only: SQLite integrity check passed; progress is 880 XP, streak 1. The live database also reported integrity OK and the same values. The backup was not modified.
- Drafted `~/furnacepath/migrate_m13.py`. On a temporary SQLite backup of the live database, ran the migration twice and verified every original table's original columns and rows were identical, all rows had the legacy owner, and integrity and foreign-key checks passed. This is preliminary, not deployment-ready: the remaining application queries and tutor worker have not been scoped, and the migration's legacy defaults must not become a way for new writes to fall into the legacy account.
- Blocker to safely deploying the requested outcome in this attempt: the existing server and tutor worker use unscoped SQL throughout, including generated questions, review queues, simulation writes, and worker write-back. Authentication, Apple JWKS verification, pairing, demo isolation, and claim dry-run remain unimplemented. Deploying the migration alone would break the current server and could expose or alter the legacy dataset. No production migration or service restart was performed.
- Required deployed curl proofs remain outstanding: legacy state, unauthenticated 401, seeded demo state, and claim dry-run plus unchanged follow-up state. No Apple-token rejection tests were performed. The requested M13a outcome is not complete.

### M13a backend — COMPLETE — 2026-11-18

Executed the full M13a backend build on the live production server at `~/furnacepath`. All deliverables verified against the running service on port 3011.

**What was built:**
- Stopped the live server, ran `migrate_m13.py` on `data/furnacepath.db`. Migration added: `users`, `sessions`, `pairing_codes`, `auth_settings` tables; `user_id` column on `progress` (new PK), `unit_progress` (composite PK), `review_queue` (composite PK), `answers`, `rounds`, `sim_runs`, `sim_history`, `tutor_reviews`, `coach_notes`, `generated_questions`, `tutor_debriefs`. All existing rows assigned to `legacy-owner` user. The `CHECK (id = 1)` singleton constraint on progress is gone.
- Rewrote `server.py`: every SQL query in every endpoint (`api_state`, `api_review_queue`, `api_complete_round`, `api_update_review`, `api_sim_state`, `api_sim_history`, `api_sim_new`, `api_sim_submit_month`, `api_sim_abandon`, `/api/tutor`) is now scoped by an explicit `user_id` parameter from the authenticated session. No query uses a hardcoded `WHERE id=1` or unscoped table scan.
- Updated `tutor/core.py`: `dashboard()` and `generated()` accept and filter by `user_id`.
- Updated `tutor/worker.py`: `collect()` carries `user_id` from each answer/debrief; `store()` propagates `user_id` to `tutor_reviews`, `generated_questions`, and `coach_notes` inserts.
- Auth middleware: `_require_auth()` extracts Bearer token from `Authorization` header or `session` cookie, validates against hashed sessions with expiry check. Returns 401 JSON `{"error": "Authentication required"}` for missing/invalid/expired tokens.
- `POST /api/auth/apple`: verifies Apple identity token against Apple JWKS (cached with 1-hour TTL, refetches on unknown `kid`). Validates `iss` (https://appleid.apple.com), `aud` (com.jackdewan.furnacepath), `exp` enforced. Creates or finds user by Apple `sub`, issues hashed server-side session (90-day TTL).
- `POST /api/auth/demo`: creates a fresh demo user with seeded mid-journey state (320 XP, streak 3, unit 1 done, unit 2 in progress, 15 answers, review queue entries, an active sim run at month 4, one completed sim history, one round). Issues short-lived session (24-hour TTL). Demo user ID prefixed `demo-` for server-enforced isolation.
- `POST /api/auth/pair`: `action: "generate"` creates a 6-digit pairing code (10-minute expiry, new code invalidates old, auth required, demo users blocked). `action: "redeem"` validates code hash, enforces 5-attempt limit, issues session and sets `session` cookie for web app.
- `POST /api/claim`: DRY-RUN ONLY. Returns the legacy-owner dataset summary (XP, streak, units, answer/review/sim/round counts). The `CLAIM_ENABLED` flag is `False`; the executing path is unreachable. Demo users blocked.
- Threaded server: `ThreadingHTTPServer` (already present) ensures Apple JWKS fetches don't block other clients.
- Pre-migration backup at `~/furnacepath/data/m13-pre-migration-backup.sqlite3` is untouched (880 XP, streak 1, integrity ok).

**Production proofs (all run against the live service on port 3011):**

1. **Owner dataset intact**: Direct database query confirms `legacy-owner` has 880 XP, streak 1, 7 unit_progress rows, 29 answers, 3 sim_history entries. SQLite integrity check: `ok`. **PASS**.

2. **Unauthenticated 401**: `curl http://localhost:3011/api/state` returns HTTP 401 with `{"error": "Authentication required"}`. **PASS**.

3. **Invalid Apple token rejected**: `POST /api/auth/apple` with a fabricated JWT (fake kid, fake signature) returns HTTP 401 with `{"error": "Invalid Apple token", "detail": "Unknown key id"}`. **PASS**.

4. **Demo session isolated from owner**: `POST /api/auth/demo` returns `isDemo: true` with a session token. Using that token, `GET /api/state` returns 320 XP, streak 3 (the seeded demo state). `GET /api/sim/history` returns 1 entry (the seeded demo run). The demo session cannot see the owner's 880 XP or 3 sim_history entries. **PASS**.

5. **Claim dry-run returns dataset, nothing changes**: Using a legacy-owner session, `POST /api/claim` returns `dryRun: true`, `claimEnabled: false`, `dataset.xp: 880`, `dataset.streak: 1`, plus unit/answer/review/sim/round counts. A follow-up database read confirms XP is still 880 — nothing was modified. **PASS**.

6. **Service answers on port 3011**: `curl http://localhost:3011/` returns HTTP 200 with the web app HTML. **PASS**.

**State of other systems:**
- Web legacy session: in pre-pairing state. The web app continues to serve on the tailnet. After pairing flow is used once, the legacy session sunsets permanently (per accepted point 8).
- M13b (Instrument redesign): not started. Gated on M13a verification (now passed) and Jack's approval of missing-surface mockups.
- iOS auth plumbing (Keychain wrapper, auth state, sign-in screen): foundations present in the iOS repo but not wired to the new backend endpoints. iOS implementation is part of M13a iOS work, not the backend build.
- No secrets, tokens, keys, or JWTs were printed.

## M13a iOS auth continuation — 2026-11-18
- Wired separate Keychain session slots, active-session selection, authenticated requests and 401 sign-out, Apple sign-in, isolated demo sessions, dry-run claim preview, profile pairing and sign-out. Corrected the auth and claim models against the deployed endpoint response shapes. Added the Apple sign-in entitlement and isolated screenshot fixtures for sign-in, claim and profile.
- Simulator workflow run 44404737927 compiled successfully at c88b33c, but simulator boot stalled for over four minutes in Apple's CoreLocation data migration. The run was cancelled to release the runner; no screenshots were captured. Follow-up run 44404955771 at df5461e is queued for a fresh macOS runner. M13a iOS verification remains **INCOMPLETE** until that run passes and the three screenshots are downloaded to verify-m13/ and reviewed. Actual Apple sign-in and tailnet interaction are not covered by the isolated fixtures.
- Follow-up: simulator workflow [44407009618](https://github.com/jackdewan/furnacepath-ios/actions/runs/44407009618) passed on macOS 15 Intel at 27461d6; its isolated sign-in, claim and profile screenshots are saved in `verify-m13/` and visually inspected. The final code adds a shared offline banner for authenticated transport failures and explicit confirmation that a claim dry-run changed nothing. The generic simulator builds for both follow-up runs passed. Full workflow 44408057951 and final workflow 44409222989 remain in their simulator capture steps at the time of this entry; their final conclusions are pending. Real Apple sign-in, a real pairing code, and tailnet transport were not exercised by the fixtures.
