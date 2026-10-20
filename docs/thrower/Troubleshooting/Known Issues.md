# Known Issues

## "The camera couldn't start" After Adding the Camera Plugin

- **Symptom:** the Camera screen shows the generic "The camera couldn't start" message, there are no Camera\cache\artifacts lines in logcat, and no permission prompt appears.
- **Seen:** 2026-10-05, Samsung SM A065F (Android 16), the first run after `camera` was added.
- **Likely cause:** the app was still running from a session started before the native plugin was built in (a hot reload/restart doesn't add native code). Not confirmed: a fresh `flutter run` worked, including the first-time permission prompt.
- **Fix:** stop the app fully and re-run it. In debug builds the error view now shows the underlying exception, so if this recurs the cause is on screen. See [[Common Tasks#Run the App on a Phone]].

## Tester Told to "Renew Your Membership" in App Store Connect

- **Symptom (2026-10-14, Joanna):** after signing in to App Store Connect, a tester sees a message that the membership must be renewed, naming Nigel's **old** developer account (nigel.bond@orcon.net.nz).
- **Cause:** Nigel has two developer teams, both probably named "Nigel Bond". The **old** one (account holder nigel.bond@orcon.net.nz) has a lapsed membership. The **new** one (account holder bondsfamily0007@gmail.com, team `QCQ64RLD77`) holds Knife and Axe Thrower, its builds and the Field testers group. A tester who belongs to both teams can be signed into the old one, where everyone sees the renewal notice. **Don't renew the old team**: nothing for this app is there.
- **Fix:** check in the **new** team's Users and Access that the tester has accepted (no *Resend Invitation*), then add them to **TestFlight → Field testers**. Accepting alone doesn't make someone a tester; Joanna had accepted but wasn't in the group. Testers then use only Apple's TestFlight app, so the website message doesn't matter. On the website they can switch team from their name (top right). Optionally, remove them from the old team (sign in as nigel.bond@orcon.net.nz → Users and Access) if Apple still allows it with the membership lapsed.

## iPhone: Target Outline in the Wrong Place (Frames Rotated Twice)

- **Symptom (Nigel, 2026-10-09, first iPhone test):** *Find target* finds the rings (95%+), but the outline lands on the wrong side of the preview, or higher and smaller than the target.
- **Cause:** `camera_avfoundation` sets the image stream's `videoOrientation` to match the device, so **iOS frames arrive already upright** (720×1280 in portrait). Android frames arrive in sensor orientation (landscape). `LiveCamera.uprightRotation` applied `sensorOrientation` (90°) on both platforms, so the iPhone frame was analysed sideways (1280×720) and the result was drawn in the wrong coordinates.
- **How it was found:** the debug log line `Calibration frame: 720×1280 bgra8888 …; rotation 90°; analysed 1280×720` and the dumped frame (poster lettering sideways). On iOS, pull the frame with `xcrun devicectl device copy from --device <id> --domain-type appDataContainer --domain-identifier nz.nrbond.thrower --source tmp/calibration-frame.png --destination calibration-frame.png`.
- **Fix in place (2026-10-09):** `frameRotation(alreadyUpright: Platform.isIOS, …)` returns 0 on iOS. It's covered by the `frameRotation` cases in `test/vision/frame_to_rgb_test.dart`. Calibration and throw watching both use `uprightRotation`, so the one change covers both.

## Calibration Can't Find the Target Indoors (Dim, Washed-Out Stream)

- **Symptom:** "Target not found" on the A4 printout indoors, although a photo of the same scene works.
- **Cause:** the camera's live stream is more washed out than the camera app's photos (maroon → brown, yellow → peach). In dim or flat light the two ring colours differ by less than the ring finder's fixed `edgeContrast`.
- **Fix in place:** the contrast-stretch fallback (`ContrastNormalisingLocator`; see Design Decisions → Coarse-to-Fine). If it still fails, pull the analysed frame (see [[Common Tasks#See What the Ring Finder Was Given (Android, Debug)]]) and add it as a fixture.

## Buttons Hidden Under the Navigation Bar (Android 15, iPhone)

- **Symptom (Nigel, 2026-10-09):** on Android the semi-transparent navigation bar sits over the Find target button (and other bottom content); iPhones have the same with the home indicator strip.
- **Cause:** Android 15 draws apps **edge to edge** (content runs under the system bars); iOS always has. A screen body that ends at the bottom of the screen ends under the bar.
- **Fix in place (2026-10-09):** every screen with content at the bottom wraps its body in `SafeArea(top: false, …)` (the AppBar already handles the top): Calibrate, Play, Camera and the two test screens. Centred screens (Home, Play's "calibrate first") don't need it. `test/ui/system_bars_test.dart` gives the screen a 48 px bar and checks Find target and Play's scores sit above it (it fails on the old layout: the button ended 32 px into the bar).
- **For new screens:** wrap a body that reaches the bottom in `SafeArea(top: false, …)`.
- **Hiding the bar instead** (immersive mode) was considered: Android brings it back on a swipe from the edge, and iPhones can't hide the home indicator, so content must stay clear of it anyway. Full-screen Play is an optional extra (backlog).

## Riverpod 3 Retries Failed Providers Automatically

- **Symptom (found in tests):** a camera start that failed stayed in loading, because Riverpod 3 retries failing providers with backoff by default.
- **Why it matters:** on Android, each retry after "Don't allow" would show the permission prompt again.
- **Fix in place:** `liveCameraProvider` has `retry: (retryCount, error) => null`. **Apply the same to any future provider whose failure needs a user decision** (permissions, sign-in).

## Isolate Fails: "object is unsendable" (Closure over Widget State)

- **Symptom:** `Isolate.run(() => ...)` called from a `State` method throws `Illegal argument in isolate message: object is unsendable`.
- **Cause:** the closure's context includes the widget state, which can't be sent to another isolate.
- **Fix:** use `compute(topLevelFunction, data)` (or `Isolate.run` with a closure built in a top-level function) and pass plain data only. See `_find` in `lib/ui/calibration_screen.dart` (`compute(locateInFrame, …)`).

## Wireless `adb` Device ID Changes

- **Symptom:** `flutter run -d <id>` says "No supported devices found" although the phone is connected.
- **Cause:** after the phone locks, wireless debugging can come back under a new mDNS name (`… (2)._adb-tls-connect._tcp`).
- **Fix:** run `flutter devices` and use the ID it lists.
- **Related:** if the phone is **locked**, `flutter run` installs and starts the app but never attaches (no "Flutter run key commands"). Unlock it and run again.

## Camera Plugin Declares Unused Android Permissions

- `camera_android_camerax` declares `RECORD_AUDIO` and `WRITE_E\cache\artifactsTERNAL_STORAGE` (which implies `READ_E\cache\artifactsTERNAL_STORAGE`). Our `AndroidManifest.xml` removes all three with `tools:node="remove"`. **Re-check the merged manifest after upgrading the plugin** (`build/app/intermediates/merged_manifest/debug/.../AndroidManifest.xml`), in case it adds new permissions.

## "Someone at the Board" / "The View Changed" With Nobody There

- **Symptom (2026-10-09, Samsung A06, A4 printout):** while nothing moves, Play keeps saying someone is at the board or the lighting changed. The debug log also shows many tiny episodes ending as bounce-outs.
- **Cause:** the camera moves by about 1 pixel (a phone propped on a sofa arm, image stabilisation, refocusing). Every sharp ring edge then "differs": 9% of the watch region on Nigel's frames, with brightness unchanged (169 vs 169), so it was not the lighting.
- **Fix:** `lib/vision/image_difference.dart`. Before comparing two frames, find the shift (±3 px; ±8 px at full resolution) that best lines them up. Count a pixel as changed only if it is also unlike all its neighbours. A knife is new content, so it still counts. On the real frames: 9.1% → 2.6% changed, no longer "blocked". The classifier also ignores new shapes only 1 px thick (slivers along ring edges). The regression fixtures are `test/fixtures/real/nudge-*.pgm` and the test is `test/vision/camera_nudge_test.dart`.
- **Still:** prop the phone on something rigid (a tripod or a shelf), not a sofa arm. A big knock (more than a few pixels) still needs recalibrating.
- **Zoom makes it bigger (2026-10-11):** since Find target zooms the camera in on the board, a nudge moves the picture by the zoom factor more pixels (a 1 px shake at 1× is about 3 px at 3×). The shift search covers ±8 px at full resolution; if zoomed play starts reporting "someone at the board" again, this is the first suspect.

## TestFlight Tester Invitation Loops Back to "Sign in with Apple Account"

- **Symptom (2026-10-10):** the internal tester opens the App Store Connect invitation, signs in, and lands back on the sign-in page, over and over.
- **Likely causes, most likely first (not yet confirmed which):**
  1. **Signed in with a different Apple ID** from the invited email address. The invitation only works for an Apple ID **on that exact address**. Fix: re-invite using his existing Apple ID's email, or create an Apple ID on the invited address.
  2. **The browser blocks the sign-in cookies.** This happens with iPhone Safari, private browsing, or "Prevent cross-site tracking" turned on. Fix: open the link on a computer, in a normal (not private) Chrome or Safari window.
  3. **The account isn't set up for App Store Connect:** no two-factor authentication, or a child/managed Apple ID. Fix: turn on two-factor authentication at account.apple.com.
  4. **The invitation is stale.** Fix: Nigel resends it from *Users and Access*.
- **Way round it:** use an **external** tester with a **public TestFlight link**. He needs no App Store Connect sign-in, only Apple's TestFlight app. The catch is that each version's first build needs Beta App Review, usually under a day. See [[Common Tasks]] → Ship a Build to TestFlight.
- **2026-10-19: still failing, so switched to external.** The invitation had **expired** (about 5 days after it was sent) and was resent. Then, in a private window, the link took him to Apple's **Data & Privacy** account page, not the invitation. Done instead: TestFlight → External Testing → group **External testers**, with him added by **email** (not a public link). Build 8 was **submitted to Beta App Review** with the Test Information (description, contact, sign-in not required) and a What to Test note. Once Apple approves, he gets a TestFlight email; he only needs the TestFlight app. **For each later build:** add it to External testers too. Builds of the same version often skip review, but a new version number needs review again.

## Compressed Video: Whole-Picture "Pulses"

- **Seen in:** the first Live test recordings (2026-10-11), cut from a copy of the video that a messaging app had compressed to 834 kb/s. Since 2026-10-12 the recordings come from the original (24 Mb/s), which has no pulses. The handling below stays, for any compressed source.
- **Sending videos for testing:** use AirDrop, an iCloud/Google Photos link, or a cable, not a messaging app. The messaging copy was 4× smaller, compressed, and hid board 1's last bounce-out completely.
- **Symptom:** about once a second, and strongly at 4, 10, 33, 40, 112, 144, 165 and 179 s, the **whole picture** changes slightly at once (sharpness, colour), with nothing moving. Frame differencing reads that as motion on the board.
- **Why:** the video's compression refreshing the picture (keyframes, and quality switches).
- **Handled (Task 5 of [[story-checkpoint-live-test]], 2026-10-11):** each pair of frames sets its own change threshold from its robust noise, motion is judged on the largest connected changed shape, and recordings use a minimum change of 20 (`RecordedCamera.minChange`). See [[Design Decisions]] → Throw Detection on Real Footage.
- **Also from the same compression:** when something moves elsewhere in the video, the board's picture gets re-encoded in blocks. On board 1 this happened every time board 2 was hit (the throwers throw together).
- **Also:** the recording's first 4 s repeat one frame, a still at the start of the video.

## Live Test Playback Jumps and Freezes on a Slower Android

- **Symptom (Nigel, 2026-10-13, Samsung SM A065F):** in the Live test, the recording jumps seconds at a time, then freezes, then jumps again.
- **Likely cause (measured on the PC, not yet on the phone):** `RecordedCamera._show` decodes every frame's JPEG with the pure-Dart `image` package **on the UI thread**, then copies it out twice (BGRA for the watcher, RGBA for the preview). The recordings moved from 140 px to 322 px crops on 2026-10-12 (5.3× the pixels). A 322 × 322 frame takes **14.5 ms** on the PC under JIT and **27 ms** AOT-compiled, so a release build doesn't help. A budget phone is several times slower than a desktop core, so 15 frames a second needs more than a second of UI-thread time per second. Throw watching runs on the same thread. Playback position comes from the clock, so when the thread catches up it **jumps** to the current frame.
- **Not the cause:** the live camera's own frames aren't JPEG-decoded. Whether the live camera on Play also stutters on this phone hasn't been checked.
- **Fix in place (2026-10-13; Nigel chose option a):** `RecordedCamera` decodes with Flutter's native image codec (`decodeFrameNatively`), asynchronously and one frame at a time, skipping to the newest frame if it falls behind. The preview draws the decoded image directly, so there's no extra RGBA copy. **Not yet checked on the Samsung.** If it still stutters, the next suspects are throw watching on the UI thread and the `compute` isolate started about once a second (see [[backlog]] → Speed on the phone).
- **Result (Nigel, 2026-10-13):** no stutter. But at the end of Target 1's recording the screen stopped responding (no button, no way back).
- **Found while looking (fixed 2026-10-13):** with asynchronous decoding, the recording re-sent its last decoded frame on every tick, and rounded the frame number down. Throw detection got repeats and skips (0, 0, 1, 3, 3, 4, …), which look like the board standing still mid-throw. Through the Play screen, Target 1's last round scored a stuck 3 instead of a bounce-out. Now each frame is delivered once, when decoded, at the nearest frame number; a still frame is repeated only while paused or after the end. `live_replay_test.dart` now replays through `RecordedCamera` → `ThrowWatcher` (the app's own path), so this can't drift again.
- **The freeze itself: not reproduced on the PC.** Checked:
  - a widget test plays Target 1 to the end through the real Play screen, and back works
  - only one decoded image is open at any time over 600 frames (no image leak)
  - the detector takes a steady ~9–10 ms a frame on the PC, with no rise at the end
  - every frame in both packs decodes
  
  Next: the phone's console output (or DevTools' memory and CPU views) at the moment it freezes.

## Re-calibrating After Play in the Live Test Didn't Always Work

- **Symptom (Nigel, 2026-10-13):** in the Live test, going back from Play and tapping Find again sometimes failed to find the rings, or found them wrongly.
- **Cause:** leaving Play left the recording running (or stopped on its last frame). Find again then ran the ring finder on whatever frame was showing: knives in the board, people collecting, the end of the recording. The locked calibrate screen's throw watcher also reacted to the footage.
- **Fix in place (2026-10-13):** `PlayScreen.dispose` calls `RecordedCamera.rewind()`, which stops playback and waits on the first frame again. A recording now plays only while Play is open. Covered by `recorded_camera_test.dart` ('rewind mid-play stops on the first frame and keeps delivering it') and `live_test_screen_test.dart` ('leaving Play rewinds the recording to its first frame, for re-calibrating').
- **Live camera:** not affected; it has no first frame to go back to. Re-calibrate with the board clear.

## Quick Draw: a Board Isn't Found, or the Wrong Outline

- **Symptom:** on Quick draw, a tap says "No board found there.", or the outline drawn doesn't match the board (a ring too small or too big, or off centre).
- **Cause:** the ring finder starts from the tap, and fits only start well from near the board's centre. Measured on the Quick draw clip's 16 still frames (2026-10-14): a tap on the centre finds the left (red on wood) board on 16 and the right (green and red) board on 15–16; a tap **15–30 px off centre** finds the green and red board on only **10–12** (the left still 15–16). It isn't resolution or compression: the right board fails as often on the uncompressed original at full size. See [[Design Decisions]] → Quick Draw: Choosing the Boards by Tapping.
- **What to do:** tap the **bull** (the middle of the board), not a ring. If the outline is wrong, press **Choose boards again** (it also rewinds the clip to its still first frame) and tap again. There's no drag-to-adjust per board yet ([[story-checkpoint-quick-draw]] Task 2).

## Quick Draw: Dropped Frames Make Times Coarser

- **Status: resolved 2026-10-15 by the analysis feed** ([[story-checkpoint-quick-draw]] Task 4; Nigel's device check pending). The watchers now get **every** frame of the clip, in order, from `RecordingAnalysisFeed`, each timed by its place in the clip, so the times no longer depend on which frames the screen showed. The cost: the result can **lag the picture**. While it does, the line at the bottom says **"Analysing… x s behind the picture."**, then the verdict. On a slow phone that can be a second or more at the throws; that's expected, not a hang. Why and how: [[Design Decisions]] → Quick Draw: Analysing Every Frame, Reporting Late. The history below is from before the fix.
- **Seen 2026-10-15 on Nigel's Samsung SM-A065F:** Quick draw played at **11–12 frames a second**, and a couple of runs gave both players the same time. **2026-10-15 on Nigel's iPhone** (debug build from \cache\artifactscode): about **42 frames a second**, and still "quite often" the same time for both.
- **Symptom:** on a slow phone, Quick draw's times under the boards jump in steps bigger than a frame (17 ms), or both boards show the **same** time.
- **Cause:** the clip is 720 × 1280 at **60 fps**, and `RecordedCamera` skips to the newest frame when decoding can't keep up (see Live Test Playback Jumps and Freezes on a Slower Android above). Each board's `ThrowWatcher` looks at every frame it's given (Quick draw sets `interval` to zero), so frames the camera skipped are never seen, and an impact is timed to the next frame that was delivered. The two knives on the clip land **2 frames (about 33 ms) apart**, so they can land in one delivered frame.
- **Still fair:** both boards are crops of the **same** frames (`CroppedCamera`), so a dropped frame delays both alike and the order can't be swapped; at worst it becomes a tie.
- **What to do:** watch the frame-rate label (debug builds) on the Samsung while Quick draw plays ([[story-checkpoint-quick-draw]] Task 3). If it drops well below 60, the options are decoding off the UI thread or a smaller clip (see [[backlog]] → Speed on the phone). **Chosen fix (Nigel, 2026-10-15): leave playback as it is, and let the analysis report late** (every frame analysed, timed by its place in the clip): see [[story-checkpoint-quick-draw]] Task 4. A live camera has no decoding to do, so this is mainly a test cost; the live-game timing questions are in [[backlog]] #9. The replay test (`quick_draw_replay_test.dart`) delivered every frame, so it didn't catch this; since Task 4 it also plays the clip skipping 2 of every 3 frames and checks the impacts land on the same frames.

## Live Quick Draw: 60 fps Is Asked For, Not Guaranteed

- **What:** the live Quick draw asks the camera for 60 frames a second (`LiveCamera.open(fps: 60)`). iOS picks the nearest rate its 720p formats offer; Android's Camera\cache\artifacts does its best and may stay at 30, or change the stream size. Neither throws, so the "open again at the default rate" fallback only covers real errors. (Review Agent, 2026-10-15; [[story-checkpoint-live-quick-draw]] Task 2.)
- **Check:** the debug frames/s label (top left of the live Quick draw) shows what the phone delivers. At 30, two knives 33 ms apart can land in one frame: a draw.
- **Dim light:** a fixed 60 fps caps exposure at 1/60 s, so frames get darker and noisier indoors; the motion detector learns the noise, but test in the dimmest lighting you expect.
- **Heat:** while the boards are locked, both boards' crops are analysed on every frame on the UI thread. On a slow phone, watch "s behind" in the debug line over 10+ minutes; if it climbs or the phone gets hot, the fix is a long-lived worker isolate. The queue is capped at 75 MB a board (frames dropped past it are counted in the debug line).

## Live Quick Draw: Sound Notes

From the Review Agent's Safety Report on the start signal ([[story-checkpoint-live-quick-draw]], 2026-10-15):
- **The go beep sounds a little after "go" is timed.** `goAt` is taken as the go beep is asked to play; the phone's sound start delay (tens of ms, more for the very first sound on iOS, where the low-latency mode does nothing) comes after it. It's the same for both throwers, so the winner is fair, but the times shown include it, and a throw that anticipates the beep by less than that delay still counts. Device Test Plan Q3 asks whether the lights going out and the beep line up.
- **Android: other apps' music stays turned down** from the first Start until Quick draw closes. Android's low-latency player gives no "finished" signal, so each sound keeps its duck-others audio focus until it's next stopped. Harmless; leaving Quick draw restores the music.
- **Fixed before the first device test:** the sounds were released as soon as they were read (an auto-disposed provider nothing watched), so a real phone would have played no beeps; the screen now keeps them loaded while it's open (`live_quick_draw_screen_test` checks it).

## Two Targets: One Thrower Collecting Early Ends Only Their Round

**Symptom:** on Play with 2 players on 2 targets, one thrower walks up to collect while the other is still throwing; the app shows the first thrower's next round and keeps scoring the other.
**Cause:** by design, each board is watched on its own ([[story-checkpoint-players-and-targets]], Task 3): a board visit closes only that board's round. The app sees the boards, not the lanes, so it can't stop someone walking up next to a live lane.
**What to do:** the Instructions say to collect together, when both have finished; the screen says "Wait for Player 2" until both rounds are complete. Nothing to fix in the app; it's a safety rule for the throwers (Review Agent, Task 3).

## Amplify's Android Plugins Apply the Kotlin Gradle Plugin (2026-10-19)

**Symptom:** `flutter build apk` warns: "Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP): amplify_analytics_pinpoint, amplify_auth_cognito, amplify_db_common, amplify_secure_storage. Future versions of Flutter will fail to build…".
**Cause:** Amplify Flutter 2.16 (the newest at the time) still applies KGP. Flutter 3.47 only warns about it.
**Fix:** none needed yet. Before upgrading Flutter, check the Amplify Flutter changelog for "Built-in Kotlin" support and upgrade it first. `amplify_analytics_pinpoint` comes in with `amplify_auth_cognito` (a transitive dependency in `pubspec.lock`), but the app never adds the analytics plugin and its Amplify settings have no analytics section, so nothing is collected (checked 2026-10-21: the privacy policy's "no analytics" holds).

## Flutter Upgrade Fails: "being used by another process" (2026-10-21)

- **Symptom:** after a Flutter upgrade, every `flutter` command tries to re-download part of the SDK and fails. Either the Dart SDK ("Unable to update Dart SDK … being used by another process") or the engine artifacts ("Flutter failed to write to a file at `…\bin\cache\artifacts\engine\windows-x64\icudtl.dat`", OS error 1224, "a user-mapped section open"). The IDE then can't build or run the app.
- **Cause:** Windows won't replace a file another process has open. Two holders were found:
  - the IDEs' Dart analysis servers (`dart.exe` under `bin\cache\dart-sdk`), holding the Dart SDK;
  - leftover `flutter_tester.exe` processes from old `flutter test` runs that never exited (ten, from 15–16 October), holding the engine's `icudtl.dat`.
- **Fix:**
  1. List the holders: `Get-Process dart, flutter_tester | Select Id, Path, StartTime` (PowerShell).
  2. Stale `flutter_tester` processes can simply be stopped: `Get-Process flutter_tester | Stop-Process -Force`.
  3. For the Dart SDK, close Android Studio and IntelliJ (their analysis servers restart with them).
  4. Run `flutter --version` (and `flutter precache` if the engine was the one that failed), then `flutter pub get` and `flutter analyze`.

## Build Warning: "A restricted method in java.lang.System has been called" (2026-10-21)

**Symptom:** at the start of `flutter build apk` / `flutter run`: "WARNING: java.lang.System::load has been called by net.rubygrapefruit.platform.internal.NativeLibraryLoader … Use --enable-native-access=ALL-UNNAMED … Restricted methods will be blocked in a future release".
**Cause:** Gradle 9.3.1's own native library loader on a newer Java (22+ warns about native access). Nothing to do with the app's code.
**Fix:** none needed; it goes when Flutter / Android Studio move to a Gradle that enables native access. The build and the app are unaffected.

## Build Warning: "SDK \cache\artifactsML versions up to 3 but … version 4" (2026-10-21)

**Symptom:** "Warning: SDK processing. This version only understands SDK \cache\artifactsML versions up to 3 but an SDK \cache\artifactsML file of version 4 was encountered."
**Cause:** Android Studio's SDK Manager wrote newer SDK metadata than the older Android SDK command-line tools the build reads it with.
**Fix (optional, harmless either way):** Android Studio → Settings → Languages & Frameworks → Android SDK → **SDK Tools** → tick **Android SDK Command-line Tools (latest)** → Apply.

## Release Builds Need INTERNET in the App's Manifest (2026-10-19)

**Symptom (avoided):** sign-in would work in debug builds and fail in release ones.
**Cause:** Flutter adds `android.permission.INTERNET` to the debug and profile manifests only, and the Amplify plugins don't declare it.
**Fix:** `android/app/src/main/AndroidManifest.xml` declares it (accounts story, Task 1).

## Cognito's Own Email Limits Sign-Up Codes (London) (2026-10-19)

**Situation:** the auth uses Cognito's built-in email for confirmation codes (about 50 a day), not SES. WhereWillWeVisit's SES is out of the sandbox only in `ap-southeast-2`; Thrower is in **London**.
**Before launch:** set up SES in `eu-west-2` and request production access (WhereWillWeVisit's Known Issues: "SES Account in Sandbox Blocks Real Users From Confirming Sign-Up"), then point Cognito at it.


## Amplify Build: `npm ci` Says the Lock File Is Out of Sync (2026-10-19)

**Symptom:** the first Amplify Hosting build (job 2, commit `21813f1`) failed in the backend phase: "`npm ci` can only install packages when your package.json and package-lock.json … are in sync … Missing: @aws-cdk/toolkit-lib@1.19.0 from lock file" (and about 40 more).
**Cause:** `package-lock.json` was made on the PC with **Node 24 / npm 11**; Amplify's build image runs **Node 22 / npm 10**, which resolves the Amplify backend's dependency tree differently and rejects the npm 11 lock file.
**Fix:** make the lock file with npm 10: `npx -y npm@10 install --package-lock-only`, check with `npx -y npm@10 ci --dry-run`, and commit it. Do the same whenever `package.json` changes. (WhereWillWeVisit avoids it by running `npm install` in its build, at the cost of reproducible installs.)

## Amplify Build: "not authorized to perform ssm:GetParameter … /cdk-bootstrap/hnb659fds/version" (2026-10-19)

**Symptom:** the next build (job 3, commit `8953499`) got past `npm ci`, then `ampx pipeline-deploy` failed: "[BootstrapDetectionError] Unable to detect CDK bootstrap stack due to permission issues … User: arn:aws:sts::499901155257:assumed-role/AemiliaControlPlaneLambda-CodeBuildRole-… is not authorized to perform: ssm:GetParameter".
**Cause:** two missing one-off setups.
1. The Amplify app had **no service role**, so the build ran as Amplify's own role (in AWS's account 499901155257, not ours).
2. **London (`eu-west-2`) wasn't CDK-bootstrapped** in account 445567075330: there was no `CDKToolkit` stack. WhereWillWeVisit's Sydney region was bootstrapped long ago.

**Fix (done 2026-10-19, with Nigel's OK):**
- created the role **`amplify-thrower-app-backend-role`**: trusted by `amplify.amazonaws.com`, with the AWS-managed policy `AmplifyBackendDeployFullAccess`;
- attached it to app `d1yhmpx84pdvnh` (`aws amplify update-app --iam-service-role-arn …`);
- ran `npx cdk bootstrap aws://445567075330/eu-west-2`;
- retried the build (job 4).

## Amplify Build: "Failed to retrieve backend secret" (2026-10-20)

**Symptom:** job 6 (commit `5b52497`, accounts Tasks 3–5) failed in the auth stack: `Custom::AmplifySecretFetcherResource … Received response status [FAILED] … Failed to retrieve backend secret`. CloudFormation rolled back (`UPDATE_ROLLBACK_COMPLETE`), so the deployed backend (email sign-in, Task 1–2) was untouched.
**Cause:** `amplify/auth/resource.ts` reads six secrets (`secret('GOOGLE_CLIENT_ID')` …) that don't exist yet for app `d1yhmpx84pdvnh` (none under `/amplify/shared/d1yhmpx84pdvnh/`).
**Fix:** set the six secrets ([[Cloud Config Setup]] → The Six Sign-In Secrets), then **Redeploy** the latest build in the Amplify console (or push again). Until then every build of `main` fails the same way; docs-only commits can carry `[skip-cd]` in the message so Amplify doesn't build them.

## Older App Versions Read Precision and Three Targets Games as Scoring (2026-10-20)
- **What:** History records are version 3 since the more-game-types story; a Precision or Three targets game has a `type`. A build from before that ignores `type`, so it shows such a game as a Scoring game (no distances), and a sign-in sync on that build copies it into its phone's History that way.
- **Not affected:** the backup's own copy keeps its type, and the History file stays version 2 (readable by older builds) until a Precision or Three targets game is kept on that phone (`FileGameHistory._versionFor`). A file of version 3 is set aside whole by an older build (renamed `.damaged-…`, not deleted), as any newer file is.
- **When it matters:** only if a tester goes back to an older build. Install the latest build instead.
- Found by the Traceability review: [[story-checkpoint-more-game-types]].

## Stencilled Boards: Find Target Can't Find Rings Painted With Gaps (2026-10-21)
- **Symptom (Mark, 2026-10-20):** on Play's Calibrate, **Find target** says "Target not found" or "Not sure about the target", or outlines the wrong thing (a net above the boards, a neighbouring board), on boards whose rings are sprayed through a stencil: each ring is a few arcs with gaps of bare wood, on speckled wood.
- **Cause:** the automatic search starts from single-colour regions, and none sits on the centre of a board whose rings are arcs on speckled wood; from a start a few px off, the board's size comes from a speck. See [[Design Decisions]] → Boards With Broken Rings: Tap the Board.
- **What to do:** tap **Tap the board**, then tap the **middle (the bull)** of the board being thrown at, only when no one is throwing. The rings are found round the tap by how they line up. Drag the outline if it's a little off, then Lock target. The same tap picks the right board when several are in the picture.
- **A dark board is sensitive to where it's tapped:** Mark's right board (in shade, against the sky) is found when tapped on its bull or just above it, but a tap about 10 px to the right (on the working picture) gives a wrong outline. Tap again on the bull, or drag the outline into place.
- **The whole board must be in view:** a board cut off by the picture's edge (Mark's left board) isn't found. Move or turn the phone so the whole board shows, keeping it out of the line of throw.
- **Not fixed:** Find target on its own still doesn't find these boards (widening it broke boards that work). Requirement and open questions: [[Board Finding]].

