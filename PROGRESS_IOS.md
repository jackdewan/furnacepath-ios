# M11 — FurnacePath iOS

## Phase A
- Implemented native SwiftUI iOS 17 thin client: Path with all server units/lessons available, Sprint, CEO Rep, numeric/MC lesson player, explanations, tutor reasoning/confidence, saved results, Drills, spaced Review, tutor feedback, Mastery/Coach/Owner Track.
- Fetches content and progress dynamically from P51; loading, Tailscale failure banner/Retry, foreground and pull refresh preserve open lesson inputs.
- XcodeGen configuration, simulator build workflow, manual TestFlight TODO stub and networking documentation added. No question data, databases, credentials or signing assets committed.
- Validation: backend/web contract inspected; initial simulator CI **GREEN** (no correction iterations): https://github.com/jackdewan/furnacepath-ios/actions/runs/43949233972 (commit 8464aad). Live learning writes intentionally not used for validation against Jack's production progress.

## Phase B
- Implemented after Phase A green: dynamic plant/furnace setup, starting position, active-run resume, capacity-aware jobs and player pricing, standing decisions, Woodworth overflow, event cards, P&L, final scoring/weak spots, tutor debriefs, completed-run history and confirmed abandon. All simulation state/processing stays on P51.
- Simulator CI pending; no production sim writes performed.
