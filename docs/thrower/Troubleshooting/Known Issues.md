# Known Issues

## "The camera couldn't start" After Adding the Camera Plugin

- **Symptom:** the Camera screen shows the generic "The camera couldn't start" message, there are no CameraX lines in logcat, and no permission prompt appears.
- **Seen:** 2026-10-05, Samsung SM A065F (Android 16), the first run after `camera` was added.
- **Likely cause:** the app was still running from a session started before the native plugin was built in (a hot reload/restart doesn't add native code). Not confirmed: a fresh `flutter run` worked, including the first-time permission prompt.
- **Fix:** stop the app fully and re-run it. In debug builds the error view now shows the underlying exception, so if this recurs the cause is on screen. See [[Common Tasks#Run the App on a Phone]].

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
