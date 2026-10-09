# Common Tasks

## Ship a Build to TestFlight (Remote iPhone Testers)

On the Mac, with the repo pulled. The first time takes about an hour, later builds about 15 minutes.

**One-time setup**
1. **Signing:** open `ios/Runner.xcworkspace` in Xcode → Runner target → *Signing & Capabilities* → tick *Automatically manage signing* and pick your **Team**. Bundle ID `nz.nrbond.thrower`; Xcode registers it. Commit the resulting `project.pbxproj` change (the team ID isn't a secret).
2. **App record:** [App Store Connect](https://appstoreconnect.apple.com) → *Apps* → **+** → *New App*: iOS, a name (it must be unique on the App Store; "Thrower App" may be taken, and it can be changed later), language, bundle ID `nz.nrbond.thrower`, any SKU (e.g. `thrower-app`).
3. **Testers.** **Decided (Nigel, 2026-10-08): internal testers**, for immediate access without Beta App Review.
   1. *Users and Access* → **+** → the tester's name and email → the most limited role (e.g. **Customer Support**) → under *Apps*, give access to **this app only** (not "all apps") → *Invite*.
   2. The tester accepts the App Store Connect invitation email (with an Apple ID on that address, or one created then).
   3. *TestFlight* → *Internal Testing* → **+** → a group (e.g. "Field testers"), with *automatic distribution* on → add the tester.
   4. Each processed build then reaches them straight away; they get a TestFlight email and install it in Apple's TestFlight app.
   - The alternative, **external** testers, needs no account access but a Beta App Review of each version's first build (usually within a day).

**Each build**
1. Bump the build number in `pubspec.yaml` (`version: 1.0.0+N`, N one higher than the last upload).
2. `flutter build ipa --release` → `build/ios/ipa/*.ipa`.
3. Upload with Apple's **Transporter** app (drag the `.ipa` in) or Xcode → *Window → Organizer → Distribute App*.
4. Wait for *Processing* in App Store Connect (10–30 min). Export compliance is pre-answered (`ITSAppUsesNonExemptEncryption = NO`).
5. With automatic distribution on, the internal group gets the build as soon as it's processed; otherwise *TestFlight* → the build → add it to the group. Testers get an email and a TestFlight notification.

**Feedback** arrives in App Store Connect → *TestFlight* → *Feedback* (screenshots with comments, crash reports).

**Gotchas**
- A TestFlight build is a **release** build: no frames/s label, no error detail, no calibration frame dump (all `kDebugMode`). Diagnose from screenshots, or reproduce on a debug build at the Mac.
- `NSMicrophoneUsageDescription` is present only because the camera plugin links audio APIs, which App Store Connect flags; the app never asks for the microphone (`enableAudio: false`).
- TestFlight builds expire after 90 days.

## Update the In-App Instructions

The *Instructions* screen (Home → Instructions) is what players and testers read. Its text is in **`lib/ui/instructions.dart`** → `instructionSections`, with two versions picked by `InstructionTarget`: **Real board** (default) and **Paper target** (A4 printout, pens in Blu Tack). Shared points are written once; version-specific ones sit under `if (paper)`. Keep both versions in mind when editing.
- **When:** any change to setup advice, button names, how rounds work, scoring or safety wording. The Docs Agent checks this on every change to `lib/ui/`, `lib/scoring/` or `lib/game/`.
- **Numbers aren't typed in:** rounds, throws per round, ring scores and the line-touch rule come from `GameSession` and `TargetModel`, so they follow rule changes automatically.
- **Button names are typed in** (*Find target*, *Lock target*, *Re-calibrate*, *Reset game*, *New game*): if a label changes, update the text.
- **Safety wording:** never imply the app knows the lane is clear (Review Agent checklist §7).
- Run `flutter test test/ui/instructions_test.dart` and update its expected phrases if the wording changed on purpose.

## Run the App on a Phone

- Use the JetBrains `main.dart` run configuration (see `working-with-nigel.md` → IDE).
- **After adding or upgrading a plugin with native code** (e.g. `camera`), fully **stop and re-run**. A hot reload or hot restart doesn't add the native side, and the plugin fails at runtime. See [[Known Issues]].

## Run Tests and Analysis

```bash
flutter analyze
flutter test
```

Both must be clean before any commit (Test Agent rule).

## Regenerate the Printable Test Targets

```bash
dart run tool/printable_target.dart
```

Writes `docs/thrower/reference/printable/target-A4.pdf`, `target-A3.pdf`, `target-A1-full-size.pdf` and `target-A4.jpg` (300 dpi, 2480 × 3508; JPEGs carry no physical size, so print it "fit to page"). Files already up to date are skipped, so a PDF left open in a viewer doesn't block a run. Ring sizes come from `TargetModel.ikthof()`, so rerun this after changing the rings. Print at **100% / actual size** and measure the 100 mm bar to confirm the scale.

## Check the Ring Finder on a Photo

```bash
dart run tool/locate_target.dart path/to/photo.jpg [out.png]
```

Prints each fitted ring edge and the confidence, and writes the photo with the edge points (yellow) and ellipses drawn on it (blue if found, magenta for a rejected attempt). For a new real-board photo that matters, also copy it into `test/fixtures/targets/` and add a test case.

## Render Camera Views (Test Pictures with Known Answers)

```bash
dart run tool/render_camera_views.dart [--texture-only]
```

Renders the reference board (`target-example.png`) as the phone sees it from 2 m to the side and 2 m out, at 1× and 2× zoom, with 0/1/2 knives, into `docs/thrower/reference/camera-views/` with `truth.json` (entry points, scores, ring edges). About 70 s per image. `--texture-only` writes just the cleaned board face. Camera position, knives and zooms are constants at the top of the tool. To use new renders in tests, copy them into `test/fixtures/camera-views/` and regenerate its `truth.json`.

## See What the Ring Finder Was Given (Android, Debug)

In debug builds, every "Find target" logs the frame's layout and result, and saves the exact image the ring finder received:

```bash
ADB="$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"
"$ADB" logcat -d | grep "Calibration frame"
MSYS_NO_PATHCONV=1 "$ADB" exec-out run-as nz.nrbond.thrower cat code_cache/calibration-frame.png > frame.png
```

(`Directory.systemTemp` is `code_cache` on Android, not `cache`.) Run the ring finder on it with `dart run tool/locate_target.dart frame.png`.

## Render Throw Sequences (Test Data for Throw Detection)

```bash
dart run tool/render_throw_sequences.dart [throw-stick-ring4 throw-stick-ring3 throw-bounce-out retrieve-knives]
```

15 fps, 640 × 360 frames with motion blur and noise, plus full-resolution `before.jpg` / `after.jpg`, `preview.gif` and `truth.json`, in `docs/thrower/reference/sequences/<name>/`. About 3.5 min per throw sequence and 13 min for the retrieval. Knife positions, timings and the release point are constants at the top of the tool.

## Read Logs from the Android Phone (Wireless Debugging)

`adb` isn't on `PATH`; use the SDK copy:

```bash
"$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe" devices
"$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe" -s "<device id>" logcat -d | grep -E "I/flutter|E/flutter"
```

In Git Bash, prefix `adb shell` commands that take device paths with `MSYS_NO_PATHCONV=1`, or `/sdcard/...` gets rewritten to a Windows path.

The wireless device ID can change after the phone locks (e.g. `adb-…._adb-tls-connect._tcp` becomes `adb-… (2)._adb-tls-connect._tcp`). Check `flutter devices` before `flutter run -d`. See [[Known Issues]].

## Reset the Camera Permission (to Test the First-Run Prompt)

```bash
adb -s "<device id>" shell pm revoke nz.nrbond.thrower android.permission.CAMERA
adb -s "<device id>" shell pm clear-permission-flags nz.nrbond.thrower android.permission.CAMERA user-set user-fixed
```

Revoking kills the running app, so relaunch it afterwards.
