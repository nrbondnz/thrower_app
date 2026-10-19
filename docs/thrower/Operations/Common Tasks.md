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

**Each build** (done in the foreground in Xcode: see [[dont-ask-again]] → Xcode work)
1. Bump the build number in `pubspec.yaml` (`version: 1.0.0+N`, N one higher than the last upload), then `flutter build ios --config-only --release` so Xcode picks up the new number.
2. `open ios/Runner.xcworkspace` → destination **Any iOS Device (arm64)** → **Product → Archive**. Organizer opens with the new archive when it's done.
3. Organizer → **Distribute App → App Store Connect → Upload**. (CLI alternative, not the default: `flutter build ipa --release`, then upload the `.ipa` with Transporter.)
   - "Redundant Binary Upload" means that build number was already uploaded: bump N and archive again.
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
- **Button names are typed in** (*Find target*, *Lock target*, *Re-calibrate*, *Reset game*, *New game*; Quick draw: *Quick draw*, *Lock boards*, *Choose boards again*, *Start*, *Next round* / *Extra round*, *Finish match*, *New match*): if a label changes, update the text.
- **Safety wording:** never imply the app knows the lane is clear (Review Agent checklist §7).
- Run `flutter test test/ui/instructions_test.dart` and update its expected phrases if the wording changed on purpose.

## Update the Architecture Web Pages

`docs/web/` is a static site, modelled on WhereWillWeVisit's `docs/web/`:
- `index.html`: a layer diagram where every solid box opens its component's page, plus a card for each flow;
- `flows/*.html`: one page per flow, as a step diagram;
- `components/*.html`: one page per component.

The pages are **generated**: edit `tool/web_docs/content.py` (the components, flows, wording and the files each one cites), then run:

```
python tool/web_docs/build.py
```

The build stops if a cited source file or a link target doesn't exist. `docs/web/assets/styles.css` is edited by hand. Keep the names the same as in the code and in [[Glossary]]. When a component or flow changes, update `content.py` along with the vault's [[System Diagram]] and [[Data Flow]]. To look at the site, open `docs/web/index.html` in a browser, or serve it with `python -m http.server` from `docs/web`.

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

Writes `docs/thrower/reference/printable/target-A4.pdf`, `target-A3.pdf`, `target-A1-full-size.pdf` and `target-A4.jpg` (300 dpi, 2480 × 3508; JPEGs carry no physical size, so print it "fit to page"). Files already up to date are skipped, so a PDF left open in a viewer doesn't block a run. Ring sizes come from `TargetModel.katta()`, so rerun this after changing the rings. Print at **100% / actual size** and measure the 100 mm bar to confirm the scale.

## Remake the Quick Draw Sounds

The live Quick draw's start signal and result chime are small WAVs made by a tool, not recorded:

```
dart run tool/make_signal_sounds.dart
```

Writes `assets/sounds/beep.wav` (each countdown beep, 1 kHz, 0.2 s), `go.wav` (1.5 kHz, 0.8 s) and `result.wav` (660 then 990 Hz) as mono 16-bit 22.05 kHz, with 5 ms fades so they don't click (~61 KB together). To change a pitch, length or volume, edit the `sounds` map (or `tone`) in the tool and rerun it; `pubspec.yaml` already lists `assets/sounds/`, so a full restart (not a hot reload) picks up the new files. Which sound plays when, and why: [[Design Decisions]] → Quick Draw: the Start Signal.

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

## Make a Live Test Recording

The app's **Live test** plays packed recordings (`assets/live/*.tfrm`) in place of the camera. See [[Design Decisions]] → Live Test.

1. Start from the **original** phone file (AirDrop, iCloud link, or a cable), not one sent through a messaging app: that copy was 4× smaller and compressed. Crop it to one board, e.g. `ffmpeg -i IMG_1628.mov -vf crop=322:322:118:535 -c:v libx264 -crf 12 -an 1.mp4`. Keep the original pixels: don't upscale. The crops so far are listed in `docs/thrower/reference/live-camera/README.md`.
2. Pack it: `dart run tool/pack_recording.dart 1.mp4 assets/live/target1.tfrm --ffmpeg <path to ffmpeg> --quality 12`. 15 fps is the default. At q12 a 322 px crop is ~9.8 KB a frame (25.9 MB for 3 min 10 s); the default q5 doubles that for no visible gain.
3. A new recording also needs an entry in `liveTestRecordings` (`lib/camera/recorded_camera.dart`).

**Full frame at 60 fps, with sound** (the Quick draw clip, 2026-10-14). Both boards in one picture, for timing races:
1. Cut it, scaled to 720 × 1280, without audio: `ffmpeg -ss 158.5 -i IMG_1628.mov -t 7.5 -map 0:0 -vf scale=720:1280 -c:v libx264 -crf 12 -an quickdraw.mp4`.
2. Cut the sound separately, mono: `ffmpeg -ss 158.5 -i IMG_1628.mov -t 7.5 -map 0:1 -ac 1 -c:a aac -b:a 96k assets/live/quickdraw.m4a`. Same start and length, so it lines up with the first frame.
3. Pack it at 60 fps: `dart run tool/pack_recording.dart quickdraw.mp4 assets/live/quickdraw.tfrm --ffmpeg <path to ffmpeg> --fps 60 --quality 20`. 449 frames, 34.2 MB. q12 was 53.1 MB; q31 was 23.0 MB but blocky on the boards (the grass compresses poorly).
4. Give its `Recording` the `audio` asset (see `quickDrawRecording` in `lib/camera/recorded_camera.dart`). The audio asset needs no `pubspec.yaml` change: `assets/live/` is already listed.

There's no ffmpeg on Nigel's PC. `pip install imageio-ffmpeg` brings one, at `python -c "import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())"`.

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

## Connect the App to the Amplify Backend (Accounts, Stage 2)

The full list of cloud pieces (AWS, Google, Apple; who set each up; how each secret is sourced) is in [[Cloud Config Setup]].

The backend is in this repo (`amplify/`, Gen 2; [[story-checkpoint-app-user-accounts]]), and **Amplify Hosting deploys it** from GitHub (Nigel, 2026-10-19). Nothing is deployed from the PC. The app **runs signed out** until a build has the deployed backend's settings.

**One-time, in the AWS console (Nigel):**
1. Region **Europe (London) `eu-west-2`** (Nigel, 2026-10-19), account 445567075330 (as WhereWillWeVisit).
2. **AWS Amplify → Create new app → GitHub → `nrbondnz/thrower_app`**, branch **`main`** (production). Amplify reads `amplify.yml`: it deploys `amplify/` with `ampx pipeline-deploy` and serves `web_public/` (a holding page; the privacy policy later).
3. **Service role:** **`amplify-thrower-app-backend-role`** (`AmplifyBackendDeployFullAccess`), created and attached 2026-10-19. A new region also needs **CDK bootstrapping** once: `npx cdk bootstrap aws://445567075330/<region>` (done for `eu-west-2`). Without either, the deploy fails ([[Known Issues]]).
4. The **App ID** is **`d1yhmpx84pdvnh`** (app `thrower_app`, `eu-west-2`).
5. **The dev environment:** a `dev` git branch (Claude creates and pushes it when asked), then in Amplify **Add branch → `dev`**.

**On each machine that builds the app (PC and Mac), after each backend change:**
```bash
AWS_REGION=eu-west-2 npx ampx generate outputs --app-id d1yhmpx84pdvnh --branch main --out-dir assets/config
```
- **`AWS_REGION=eu-west-2` is needed:** the default AWS profile is set to Sydney (WhereWillWeVisit's region), and without it the command says the app ID or branch can't be found. In PowerShell: `$env:AWS_REGION='eu-west-2'` first.
- Use `--branch dev` to point a test build at the dev backend.
- It writes `assets/config/amplify_outputs.json`. The file is **gitignored**: each branch has its own Cognito pool, and a committed copy goes stale, as WhereWillWeVisit found.
- It needs AWS credentials (the default profile) and `npm install` once.
- Then **rebuild** the app: the file is bundled at build time, so hot reload won't pick it up.
- Without the file, `loadAmplifyOutputs` finds nothing, `connectAccounts` returns null, and the app runs signed out.

**Checking the backend code on the PC:** `npm run typecheck` (TypeScript only; it deploys nothing).

## Set Up Google and Sign in with Apple (Accounts Task 3)

The six secrets, what each is and exactly where to get it: [[Cloud Config Setup]] → The Six Sign-In Secrets (the reference; the steps below are the short version).

Code: `amplify/auth/resource.ts` (`externalProviders`, six `secret(...)`s, return link `throwerapp://callback/`), `amplify/backend.ts` (each branch's sign-in domain), the Android intent filter and the iOS URL type for `throwerapp`. Modelled on WhereWillWeVisit's *setup* (its docs: Infrastructure → AWS Resources → "Cognito Hosted UI Domain & OAuth"), but **nothing is shared with it** (Nigel, 2026-10-20): a new Google Cloud project and client, and a new Services ID and key, all Thrower's own.

**Each branch's sign-in domain** (set in `backend.ts`, London):

| Branch | Domain | Redirect / return URL to register |
|---|---|---|
| `main` | `throwerapp.auth.eu-west-2.amazoncognito.com` | `https://throwerapp.auth.eu-west-2.amazoncognito.com/oauth2/idpresponse` |
| `dev` | `throwerapp-dev.auth.eu-west-2.amazoncognito.com` | `https://throwerapp-dev.auth.eu-west-2.amazoncognito.com/oauth2/idpresponse` |

**1. Google (Nigel, Google Cloud console):**
1. **A new Google Cloud project** for Thrower (not WhereWillWeVisit's). Go to **APIs & Services → OAuth consent screen**: External; app name **Thrower**; support email; the scopes `email`, `profile`, `openid`.
2. **Credentials → Create credentials → OAuth client ID → Web application**, named e.g. "Thrower Cognito".
3. **Authorized redirect URIs:** both URLs from the table.
4. Keep the **Client ID** and **Client secret** for step 3.

**2. Sign in with Apple (Nigel, developer.apple.com, team QCQ64RLD77):**
1. **Identifiers → App IDs → `nz.nrbond.thrower`**: tick **Sign in with Apple**.
2. **Identifiers → Services IDs → +**: e.g. **`nz.nrbond.thrower.signin`** (this, not the App ID, is Cognito's client ID). Tick Sign in with Apple, then **Configure**:
   - primary App ID `nz.nrbond.thrower`;
   - **Domains:** `throwerapp.auth.eu-west-2.amazoncognito.com` and `throwerapp-dev.auth.eu-west-2.amazoncognito.com`;
   - **Return URLs:** both URLs from the table.
3. **Keys → +**: tick Sign in with Apple, with primary App ID `nz.nrbond.thrower`. **Download the `.p8` (only once)** and note the **Key ID**.

**3. The six secrets (Nigel, Amplify console → `thrower_app` → Hosting → Secrets → Manage secrets, for all branches):**

| Secret | Value |
|---|---|
| `GOOGLE_CLIENT_ID` | the Google client ID |
| `GOOGLE_CLIENT_SECRET` | the Google client secret |
| `APPLE_CLIENT_ID` | the Services ID, e.g. `nz.nrbond.thrower.signin` |
| `APPLE_TEAM_ID` | `QCQ64RLD77` |
| `APPLE_KEY_ID` | the key's ID |
| `APPLE_PRIVATE_KEY` | the whole `.p8` file's text, including the BEGIN and END lines |

Secrets never go in git or in a chat. A deploy fails until all six exist.

**4. Deploy and finish (Claude, when Nigel says the secrets are set):**
1. Push the Task 3 commit; the `main` build makes the `throwerapp` domain.
2. Turn on Cognito's **Managed Login branding** for the app client. It's a manual step, not in CDK; without it Cognito shows "Login pages unavailable":
   ```bash
   aws cognito-idp create-managed-login-branding --user-pool-id <pool> --client-id <client> --use-cognito-provided-values --region eu-west-2
   ```
3. Regenerate the outputs (Connect the App to the Amplify Backend), rebuild, and install with `adb install -r`. The Account screen then shows Google and Apple buttons.
4. **iOS (on the Mac, in Xcode):** Signing & Capabilities → **+ Sign in with Apple**. This creates `Runner.entitlements` and sets `CODE_SIGN_ENTITLEMENTS` for Debug, Release and Profile; WhereWillWeVisit needed all three.

