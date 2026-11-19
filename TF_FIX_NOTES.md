# TestFlight upload investigation

Two workflow runs were dispatched during this investigation.

| Run | Change | Archive CFBundleVersion / CFBundleShortVersionString | Exported IPA CFBundleVersion / CFBundleShortVersionString | Result |
| --- | --- | --- | --- | --- |
| [44428719164](https://github.com/jackdewan/furnacepath-ios/actions/runs/44428719164) | Added version diagnostics; archive override requested `2000.9` / `1.0` | `1` / `1.0` | `1` / `1.0` | Apple rejected the duplicate build: `ENTITY_ERROR.ATTRIBUTE.INVALID.DUPLICATE`, “The bundle version must be higher than the previously uploaded version: ‘1’”, `previousBundleVersion: 1`. |
| [44429019001](https://github.com/jackdewan/furnacepath-ios/actions/runs/44429019001) | Explicit version substitutions in XcodeGen plist properties | `2000.10` / `1.0` | `2000.10` / `1.0` | `UPLOAD SUCCEEDED with no errors, 1 warning`. |

The archive build setting alone did not control the generated app plist: XcodeGen's `info` section generated a plist with a default `CFBundleVersion` of `1`, replacing the variable in the checked-in plist. The archive and exported IPA matched, locating the problem before export. The fix adds `CFBundleVersion: $(CURRENT_PROJECT_VERSION)` and `CFBundleShortVersionString: $(MARKETING_VERSION)` explicitly to `project.yml`'s generated plist properties. The existing archive overrides and export settings remain in place, and no marketing version bump was needed.

The diagnostic step remains in the workflow so future deliveries print both version fields from the archive and exported IPA. Upload success confirms delivery to Apple; subsequent App Store Connect processing is separate.
