# Common Tasks

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
