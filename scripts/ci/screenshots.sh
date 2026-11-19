#!/bin/bash
set -euo pipefail
mkdir -p verify-m11d verify-m13
# Pick a real iPhone runtime available on this runner, never a generic destination.
device=$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(x["udid"] for group in d["devices"].values() for x in group if x["name"].startswith("iPhone")))')
xcrun simctl boot "$device"
xcrun simctl bootstatus "$device" -b
xcodebuild build -project FurnacePath.xcodeproj -scheme FurnacePath -configuration Debug -sdk iphonesimulator -destination "id=$device" -derivedDataPath "$RUNNER_TEMP/verify-build" CODE_SIGNING_ALLOWED=NO > "$RUNNER_TEMP/verify-build.log" 2>&1 || { tail -80 "$RUNNER_TEMP/verify-build.log"; exit 1; }
xcrun simctl install "$device" "$RUNNER_TEMP/verify-build/Build/Products/Debug-iphonesimulator/FurnacePath.app"
xcrun simctl status_bar "$device" override --time '9:41' --batteryState charged --batteryLevel 100
# Dark device appearance deliberately exercises the original failure.
xcrun simctl ui "$device" appearance dark
for screen in path lesson drills review mastery sim; do
  xcrun simctl terminate "$device" com.jackdewan.furnacepath 2>/dev/null || true
  xcrun simctl launch "$device" com.jackdewan.furnacepath --verify-screen "$screen"
  sleep 4
  xcrun simctl io "$device" screenshot "verify-m11d/$screen.png"
done

for screen in signin signin-error claim profile; do
  xcrun simctl terminate "$device" com.jackdewan.furnacepath 2>/dev/null || true
  xcrun simctl launch "$device" com.jackdewan.furnacepath --verify-screen "$screen"
  sleep 4
  xcrun simctl io "$device" screenshot "verify-m13/$screen.png"
done
