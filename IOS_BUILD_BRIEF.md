# FurnacePath iOS: native SwiftUI client (M11)

Approved by Jack 2026-11-16. Jack has an Apple Developer account. Builds run
on GitHub Actions macOS runners; Jack's Mac is never used. Log as **M11**
in ~/furnacepath/PROGRESS.md and keep a running PROGRESS_IOS.md in this repo.

## Architecture rule (the whole point)

The iOS app is a THIN CLIENT over the existing P51 backend. All content and
data stay server-side: question bank, progress, tutor, sim. Updating data
(new questions, new units, tutor content, sim tuning) must NEVER require an
app build. An app build is needed only for app behavior or UI changes.

## Reference implementation

The web app in ~/furnacepath (server.py + static/) is the contract. Read
server.py and the web client to learn exactly how questions are fetched and
how each endpoint is called, then mirror those calls precisely.
Known routes:
- GET /api/state, GET /api/tutor, GET /api/review-queue
- GET /api/sim/state, GET /api/sim/history
- POST /api/complete-round, POST /api/update-review
- POST /api/sim/new, POST /api/sim/submit-month, POST /api/sim/abandon

## Networking

- Base URL: http://100.87.179.24:3011 (Jack's P51 over Tailscale).
- Info.plist ATS exception for that IP literal
  (NSExceptionAllowsInsecureHTTPLoads) so URLSession can reach it. Note in
  README.md that a Tailscale Serve https name is the future cleanup.
- State handling per the web app's M8 lessons: never render fake zeros;
  show a loading state until /api/state returns; on failure show a banner
  "Can't reach your progress on the P51. Check that Tailscale is connected,
  then retry." with a working Retry. Refetch state on foregrounding.

## Phase A (this milestone): the learning loop

Native SwiftUI, iOS 17 deployment target, SwiftUI TabView with 4 tabs:
- **Path**: XP/streak header, resume card, Units 1-7 with lessons, Sprint
  and CEO Rep entry points. NOTHING is locked anywhere (M10 parity).
- **Lesson player**: multiple choice with explanations and feedback,
  thinking questions with a reasoning text field and confidence picker
  (Sure / Unsure / Guessing) submitted for the tutor, results screen with
  accuracy, XP earned, weak spots.
- **Drills** and **Review** tabs mirroring the web app (spaced repetition
  queue via /api/review-queue and /api/update-review).
- **Mastery**: weak spots, review queue summary, Coach card (latest tutor
  note, top misconception, Drill it), Owner Track as progress milestones
  with NO padlocks.
Design tokens from the web app: ink navy #1B2230, warm paper, safety orange
#E85D1F, steel teal, amber. System tab bar, no custom glass recreation.

## Phase B (after Phase A CI is green): Run the Shop sim

Setup (5 plants including Otterson Court and Woodworth Flint, furnace
choice), monthly dashboard (cash, billed, utilization, reputation,
backlog), job accept/reject, standing decisions, event cards, month-end
P&L, game over with debrief, 12-month grading, history. All state via the
/api/sim endpoints.

## Project and CI mechanics

- No third-party dependencies. Generate the Xcode project with XcodeGen
  from a committed project.yml (do not hand-author project.pbxproj).
- Repo: private GitHub repo `furnacepath-ios` under jackdewan, created with
  the gh CLI already authed on this machine. Code only: no databases, no
  question data files, no credentials, ever.
- GitHub Actions workflow `build.yml` on push: macos-latest runner,
  install XcodeGen, generate, `xcodebuild build` for iOS Simulator with
  CODE_SIGNING_ALLOWED=NO. This unsigned simulator build is the Phase A/B
  acceptance gate.
- Add a second workflow file `testflight.yml` as workflow_dispatch only,
  stubbed with clear TODO markers for the App Store Connect API key and
  signing (Jack supplies the API key later; do not attempt signing now).
- Builder loop: write code, commit, push, watch CI with `gh run list` /
  `gh run view --log-failed`; fix compile errors and re-push, up to 5
  iterations; then record the final CI result in PROGRESS_IOS.md.
