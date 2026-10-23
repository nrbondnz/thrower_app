# Story Checkpoint: Store-Release Hygiene (Backlog #6)

## Story Goal
Backlog #6, picked up 2026-10-23 (Nigel: "do #6 and then carry on to others"), after the compliance work ([[story-checkpoint-compliance]]). Make the app fit for a public release:
- decide the leftover test screens;
- check the permission strings;
- deal with the **Live test recordings**: 87 MB of real footage, including people's faces and voices in the Quick draw clip, inside every build today.

## Status
IN PROGRESS 2026-10-23: Tasks 1 and 2 built on the PC. Task 2's Mac step (the Xcode configurations and schemes) waits for the Mac: [[Mac Handoff]] → Build 15 → Flavors: beta and store schemes.

## Task 1: Test tools hidden from store builds (built 2026-10-23)
- **Setup → Tools:**
  - **Live test** (the recordings) and the **Scoring test target** now show only in test builds. A test build is a debug build, or a TestFlight build made with `THROWER_TEST_TOOLS` ([[story-checkpoint-posting-from-history]]).
  - **Calibrate target** stays for everyone.
- **Instructions:** the Quick draw section mentions the Live test recording only in a test build (`instructionSections(..., testTools:)`). Its stale "(or under Throw)" is gone too.
- **Effect:** someone with an App Store or Play build can't reach the footage. **But it's still inside the app file** (87 MB, extractable), so Task 2 is still needed.

## Checked, no change needed
- **Microphone:** `NSMicrophoneUsageDescription` is in `Info.plist` although the app never records sound (`enableAudio: false`). Keep it.
  - Apple rejects an upload whose binary links microphone APIs without a description (the camera plugin links them).
  - The text already says the app doesn't record sound.
  - Android has no `RECORD_AUDIO` (removed on purpose).
- **Debug-only code:** the frame dumps, the frame-rate label and the watch debug line are all behind `kDebugMode`, so they're out of release builds.
- **App name:** the phone shows **"Thrower App"** (`CFBundleDisplayName`, Android `android:label`), while the app's hero says THROWER. Renaming the store name is Nigel's choice; it's not changed here.

## Task 2: The recordings out of store builds

### Decision
Nigel chose **A, flavors** (2026-10-23). The flavor is named **beta**, not "test": Android forbids flavor names starting with "test".

The footage is real people (Mark, the Captain, others at the venue), with voices in the Quick draw clip. For a public app, either they agree to it, or it isn't in the app.

### Options

**A. Flavors: a "test" build and a "store" build (architectural purity, recommended).**
- Flutter can put an asset in only some flavors (`assets: - path: assets/live/ flavors: [test]` in `pubspec.yaml`).
- TestFlight and Play testing would build `--flavor test`, with the recordings and the test tools. Store builds use `--flavor store`: no recordings, 87 MB smaller.
- The `THROWER_TEST_TOOLS` define could then come from the flavor (`appFlavor`), so a store build can't carry test tools by mistake. That would close the [[Known Issues]] `DART_DEFINES` carry-over risk for good.
- **Cost:**
  - Android: two `productFlavors` in `build.gradle.kts` (PC).
  - iOS: Xcode schemes and build configurations per flavor (`Debug-test`, `Release-store`, …), on the Mac with Nigel clicking.
  - Run configurations in JetBrains.
  - The Review Agent (signing and bundle IDs stay the same).

**B. Remove the recordings from the app; keep them for tests only (easy).**
- The PC tests already read the recordings from files. Move `assets/live/` out of `pubspec.yaml` assets, and drop Live test from the app.
- Testers lose Live test on their phones. Nigel chose to keep it in TestFlight builds (2026-10-11).

**C. Keep them in, with consent.**
- Ask everyone filmed for written permission to be in a public app.
- The app stays 87 MB bigger.

### Recommendation
**A.** It keeps Live test for testers, takes the footage and 87 MB out of store builds, and makes test tools follow the build flavor rather than a define that can be forgotten. Not needed before the first store submission; it is needed before one.

### Task 2 record
- **Status:** COMPLETE on the PC (2026-10-23), commit `8ed8624`. The Mac step is pending.
- **What changed:**
  - `pubspec.yaml`: `assets/live/` only in the **beta** flavor (`flavors: [beta]`).
  - Android: `productFlavors { beta, store }`, the same app ID. APKs `app-beta-release.apk` (164 MB) and `app-store-release.apk` (76 MB).
  - `testToolsEnabled = appFlavor != 'store' && (kDebugMode || appFlavor == 'beta' || THROWER_TEST_TOOLS)`. A store build never has test tools.
  - `liveRecordingsProvider` checks the asset manifest. Live test, and the Instructions' line about its recording, show only when the recordings are in the build.
  - `ios/Podfile` maps `Debug/Profile/Release-beta` and `-store`.
  - The JetBrains run config (gitignored) has Build flavor `beta` on this PC.
  - The stale `app-debug.apk` and `app-release.apk` were deleted ([[Known Issues]] → A Build With No Flavor Reports an Old APK).
- **Review Agent:** OK with conditions (stale APKs deleted; the store guard on `testToolsEnabled`).
- **Mac step (pending):** add the six Xcode configurations and the shared `beta` and `store` schemes ([[Mac Handoff]] → Flavors: beta and store schemes). Until then, an iPhone build has no flavor: no recordings, and test tools only with the `THROWER_TEST_TOOLS` define.
- **After the schemes:** delete the Runner scheme; remove the `THROWER_TEST_TOOLS` define; retire the Known Issues `grep VEhST1dF…` check and the Mac Handoff define steps; maybe add `default-flavor: store` to `pubspec.yaml` (never `beta`).
- **Verify:** device checks FL0–FL3 ([[Device Test Plan]] → Flavor Checks).

## Not in this story
- Line-touch rules (#3), axes (#7) and full-screen Play (#8) stay on the backlog.

---

## Plan Changes Log
- **2026-10-23:** Nigel chose option A (flavors). The tester flavor is named `beta`, since Android forbids flavor names starting with "test".

---

## Doc Update — 2026-10-23

### Files Updated
- `Architecture/Design Decisions.md`: new section **Store-Release Hygiene: Test Tools Only in Test Builds** (Live test and the Scoring test target behind `testToolsProvider`; the recordings decision pending, flavors recommended). Links [[Instructions and Safety]], [[Look and Feel]].
- `requirements/Instructions and Safety.md`: What Exists Today: test tools hidden from store builds. Also fixed a drift item: the Ranked games summary said the leaderboard starts again "each month"; now "each week".
- `requirements/Look and Feel.md`: Setup's tools, Live test and Scoring test target in test builds only.
- `Architecture/Glossary.md`: `SetupScreen` tools; new concept **Test build**.
- `tool/web_docs/content.py` (Screens: SetupScreen's tools) and `docs/web/` rebuilt.
- `Operations/Device Test Plan.md`: **Store Hygiene Checks** SH0–SH1.
- `Operations/Mac Handoff.md`: Build 15 → Also in it: store-release hygiene; SH checks under Checks to send.
- `stories/backlog.md`: #6 already links this story (no change).

### Notes
- Task 2 (the recordings out of store builds) still needs Nigel's decision.

## Doc Update — 2026-10-23 (Task 2: flavors)

### Files Updated
- `Architecture/Design Decisions.md`: new section **Build Flavors: Beta and Store (2026-10-23)**; the test-tools and Live test decisions now name the flavor.
- `Architecture/Glossary.md`: **Test build** (now the beta flavor); new concepts **Flavor**, **`appFlavor`**; `liveRecordingsProvider` under the providers.
- `AppDesign/Navigation and Structure.md`, `requirements/Game Centre/Rankings.md`: the test-build wording.
- `Operations/Common Tasks.md`: iOS archive commands with `--flavor`; `flutter run --flavor beta`; the beta APK path for `adb install -r`; new section **Build and Install on Android (Flavors)**.
- `Operations/Cloud Config Setup.md`: the adb install path.
- `Operations/Mac Handoff.md`: Build 15 gets the section **Flavors: beta and store schemes (Nigel in Xcode)**; the build commands name a flavor, or note why not.
- `Operations/Device Test Plan.md`: SH0 now a store-flavor build; new **Flavor Checks** FL0–FL3.
- `Operations/Store Compliance.md`: the release checklist: built from the store flavor and scheme, never a promoted beta or TestFlight build.
- `Troubleshooting/Known Issues.md`: `flutter run --flavor beta`; `Generated.xcconfig` keeps `FLAVOR` too; new entry **A Build With No Flavor Reports an Old APK**.
- `docs/dont-ask-again.md`: the Xcode entry's commands with `--flavor`.
- `docs/working-with-nigel.md`: one line on the flavors.
- `tool/web_docs/content.py`: `testToolsProvider` text; new `liveRecordingsProvider`; `docs/web/` rebuilt.
- `stories/story-checkpoint-compliance.md`, `website/Website Index.md`: Task 2 (publishing) done; the 5 pages live, dated 23 October 2026.

### Notes
- Archived and older story checkpoints keep `THROWER_TEST_TOOLS` as history.
