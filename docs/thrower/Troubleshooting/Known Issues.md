# Known Issues

## "The camera couldn't start" After Adding the Camera Plugin

- **Symptom:** the Camera screen shows the generic "The camera couldn't start" message, there are no CameraX lines in logcat, and no permission prompt appears.
- **Seen:** 2026-10-05, Samsung SM A065F (Android 16), the first run after `camera` was added.
- **Likely cause:** the app was still running from a session started before the native plugin was built in (a hot reload/restart doesn't add native code). Not confirmed: a fresh `flutter run` worked, including the first-time permission prompt.
- **Fix:** stop the app fully and re-run it. In debug builds the error view now shows the underlying exception, so if this recurs the cause is on screen. See [[Common Tasks#Run the App on a Phone]].

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
- **Fix:** use `compute(topLevelFunction, data)` (or `Isolate.run` with a closure built in a top-level function) and pass plain data only. See `lib/ui/debug_locator_screen.dart`.

## Wireless `adb` Device ID Changes

- **Symptom:** `flutter run -d <id>` says "No supported devices found" although the phone is connected.
- **Cause:** after the phone locks, wireless debugging can come back under a new mDNS name (`… (2)._adb-tls-connect._tcp`).
- **Fix:** run `flutter devices` and use the ID it lists.
- **Related:** if the phone is **locked**, `flutter run` installs and starts the app but never attaches (no "Flutter run key commands"). Unlock it and run again.

## Camera Plugin Declares Unused Android Permissions

- `camera_android_camerax` declares `RECORD_AUDIO` and `WRITE_EXTERNAL_STORAGE` (which implies `READ_EXTERNAL_STORAGE`). Our `AndroidManifest.xml` removes all three with `tools:node="remove"`. **Re-check the merged manifest after upgrading the plugin** (`build/app/intermediates/merged_manifest/debug/.../AndroidManifest.xml`), in case it adds new permissions.

## "Someone at the Board" / "The View Changed" With Nobody There

- **Symptom (2026-10-09, Samsung A06, A4 printout):** while nothing moves, Play keeps saying someone is at the board or the lighting changed. The debug log also shows many tiny episodes ending as bounce-outs.
- **Cause:** the camera moves by about 1 pixel (a phone propped on a sofa arm, image stabilisation, refocusing). Every sharp ring edge then "differs": 9% of the watch region on Nigel's frames, with brightness unchanged (169 vs 169), so it was not the lighting.
- **Fix:** `lib/vision/image_difference.dart`. Before comparing two frames, find the shift (±3 px; ±8 px at full resolution) that best lines them up. Count a pixel as changed only if it is also unlike all its neighbours. A knife is new content, so it still counts. On the real frames: 9.1% → 2.6% changed, no longer "blocked". The classifier also ignores new shapes only 1 px thick (slivers along ring edges). The regression fixtures are `test/fixtures/real/nudge-*.pgm` and the test is `test/vision/camera_nudge_test.dart`.
- **Still:** prop the phone on something rigid (a tripod or a shelf), not a sofa arm. A big knock (more than a few pixels) still needs recalibrating.
