# Story Checkpoint: Store-Release Hygiene (Backlog #6)

## Story Goal
Backlog #6, picked up 2026-10-23 (Nigel: "do #6 and then carry on to others"), after the compliance work ([[story-checkpoint-compliance]]). Make the app fit for a public release:
- decide the leftover test screens;
- check the permission strings;
- deal with the **Live test recordings**: 87 MB of real footage, including people's faces and voices in the Quick draw clip, inside every build today.

## Status
IN PROGRESS 2026-10-23: Task 1 built. Task 2 needs Nigel's decision (below).

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

## Task 2: The recordings out of store builds (NEEDS NIGEL)

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

## Not in this story
- Line-touch rules (#3), axes (#7) and full-screen Play (#8) stay on the backlog.

---

## Plan Changes Log
- (none yet)
