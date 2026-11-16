# FurnacePath iOS

Native SwiftUI thin client, iOS 17+, no third-party dependencies. Content, grading, progress, review scheduling and tutor work remain on the P51. Nothing is bundled from the question bank, and no production writes are performed by build checks.

Connect the iPhone to Jack's Tailscale network. Backend: `http://100.87.179.24:3011`. The Info.plist includes the requested IP ATS exception plus `NSAllowsArbitraryLoads`: Apple does not reliably apply domain exceptions to IP literals. A Tailscale Serve HTTPS name is the future cleanup, allowing removal of the broad HTTP allowance. Do not expose the backend publicly.

On a Mac or the GitHub Actions macOS runner:

```sh
brew install xcodegen
xcodegen generate
xcodebuild build -project FurnacePath.xcodeproj -scheme FurnacePath -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```

Generated Xcode projects are ignored; `project.yml` is the source of truth. `build.yml` is the simulator acceptance gate. `testflight.yml` is a manual TODO stub; signing awaits Jack's App Store Connect key and configuration.

The four tabs mirror Path, Drills, Review and Mastery. Foreground and pull refresh fetch progress with an eight-second timeout. All lessons are available immediately. Numeric and multiple-choice answers include raw `givenAnswer`, optional reasoning and confidence in `/api/complete-round`. Server grading is authoritative. Review rounds use this same endpoint, which already advances spaced repetition. The API also exposes the manual `/api/update-review` operation; it must not be applied a second time to round answers.

Run the Shop is accessible from Path and Mastery. Its five plants, furnaces, standing decisions, jobs, events, P&L, grades, history and tutor debriefs load from the backend. Closing the screen preserves the server run; resume fetches the active state. Only Quit abandons it.

Failed saves retain answers. The backend has no idempotency key: after an ambiguous network failure, inspect progress before retrying. Simulator compilation does not verify live Tailscale access or device interaction. No credentials or data files belong in this repository.
