# Story Checkpoint: Setting Up Throwing App

## Story Goal

Turn the default `flutter create` scaffold into a properly set-up project for an app that **scores throws at a physical round target using the phone camera**. Purpose and architecture are agreed and recorded, the docs/agents workflow is in place, source control is ready, and the skeleton is structured for the vision, scoring and accounts work that follows.

**Product, in Nigel's words (2026-10-04):** "Users will point a camera at a physical round target. The target will be round but the camera will likely be off to centre so it will need to identify the target. Big picture, the user will throw at the target and the app will register the score. The target will have a number of rings, the inner most ring scores 5 and the outer most ring scores 1, so 5 rings, each alternating colors to differentiate. We will need to refine this a lot but start there."

**Scope note:** this story is **setup**, not the full scoring feature. Target detection and throw detection each get their own story once the foundations exist (see Follow-on Stories).

## Complexity Score

| Factor | Score |
|---|---|
| Layers: Flutter UI, camera, vision, scoring domain | 4 |
| Infrastructure: git/GitHub, platform trimming, iOS/Android camera permissions | 1 |
| More than 3 acceptance criteria | 1 |
| **Total** | **6 (Large): full Story Agent protocol** |

## Status

**COMPLETE (2026-10-05)**: all tasks done; archived. Commits: `d389575` (initial), `8ff0405` (skeleton + scoring), `12ee9bf` (camera), `7e3cf2a` (printable target tool). **One carry-over:** the iOS camera check on the Mac (see the R4 row). Next story: [[story-checkpoint-target-calibration]]; everything else is in [[backlog]].

---

## Architecture Questions

| # | Question | Answer (2026-10-04) |
|---|---|---|
| A1 | What does the app do? | Camera on a round 5-ring target (5 = inner, 1 = outer, alternating colours); detects the target off-centre; registers the score of each throw. To be refined. |
| A2 | Target platforms | **iOS and Android** |
| A3 | Backend | **Later** |
| A4 | Auth / accounts | **Accounts needed** (provider deferred with the backend) |
| A5 | Payments | **Later** |
| A6 | Structure / AI | AI for **visual and timing** tasks. Proposed: on-device, 3-layer split. See [[Design Decisions]]. |
| A7 | Source control | **GitHub, private repo `thrower_app`, `main` only** |
| A8 | CI/CD | Not yet discussed. Revisit with the backend decision. |

## Open Questions (refining the product)

| # | Question | Why it matters |
|---|---|---|
| Q1 | What's being thrown? | **Knives or axes** into a wooden board (Nigel, 2026-10-04; corrects an earlier "darts"). Score is where the blade meets the board; a throw that doesn't stick scores 0. See [[Design Decisions]] → Throwing Sport. |
| Q2 | Target size, and how far is the phone from it? Tripod or handheld? | **Static camera** (2026-10-04). Board size and distance are still open; IKTHOF's is 50 cm with throws from about 12–21 ft. |
| Q3 | Ring colours? Real photos? | Close example: red paint and bare wood alternating, red bull (`reference/target-example.png`). **Nigel's own photos to follow.** |
| Q4 | A throw on a line: higher or lower score? A miss scores 0? | **Backlog** (refine scoring by hit point). Interim: IKTHOF, i.e. touching blade scores the higher ring, no stick = 0. Make it a setting. |
| Q5 | Players, rounds and throws per round? Single-player first? | **Single player first** (2026-10-04). Throws per round still open. |
| Q6 | Repo name and public/private; dev/prod branches as in WhereWillWeVisit? | **`thrower_app`, private, on GitHub; `main` only for now** (2026-10-04). |
| Q7 | Remove the web/desktop platform folders? | **Yes**: done 2026-10-04 |

## Traceability Matrix (final, 2026-10-05)

| ID | Requirement | Design ref | Implementation | Test | Status |
|---|---|---|---|---|---|
| R1 | Project has a docs area matching WhereWillWeVisit's workflow | `working-with-nigel.md` | `docs/`, `CLAUDE.md` | n/a (docs) | ✅ Task 0 |
| R2 | Runs on iOS and Android only, as `nz.nrbond.thrower` | Design Decisions | web/desktop folders removed; bundle IDs set | Android debug build; Nigel ran it on both platforms | ✅ Task 2 |
| R3 | Scores a point on a 5-ring target: 5 inner → 1 outer, 0 outside; line-touch rule is a setting (default: higher) | Design Decisions → Throwing Sport | `TargetModel.scoreAt` | `target_model_test.dart` (17); `debug_target_screen_test.dart` (4); Nigel on device | ✅ Task 3 |
| R4 | Live camera preview of the target on iOS and Android; frames available to vision; denied access handled | Design Decisions → Camera | `LiveCamera`, `liveCameraProvider`, `CameraScreen` | `camera_screen_test.dart` (7), `live_camera_test.dart` (4), `frame_rate_meter_test.dart` (3); Android device: first-run prompt → preview (Claude), preview (Nigel) | ⚠️ Android ✅; **iOS device check outstanding**; Android "Don't allow" path tested in widget tests only |
| R5 | Finds the round target when viewed off-centre | Design Decisions | | | ➡️ [[story-checkpoint-target-calibration]] (C1–C5) |
| R6 | Detects a thrown knife or axe that sticks and registers its score; a throw that doesn't stick scores 0 | Design Decisions | | | ➡️ [[backlog]] #2 |
| R7 | User accounts | Design Decisions | `AuthService` interface, `authServiceProvider` (unimplemented) | n/a (interface only) | ➡️ Interface done; provider in [[backlog]] #4 |
| R8 | Printable test target for development before the real board is set up (Nigel, 2026-10-05) | Plan Changes Log 2026-10-05 | `tool/printable_target.dart` → `reference/printable/*.pdf` | visual check (dev utility; no automated test) | ✅ |

---

## Story Plan (APPROVED 2026-10-04, COMPLETE 2026-10-05)

### Task 1: Settle architecture and adapt the agents
- **Work:** Record answers to Q1–Q7 in [[Design Decisions]]. Confirm or amend the proposed 3-layer vision/scoring split. Rewrite the "Be Careful" Review Agent checklist for this stack (camera permissions, iOS `Info.plist` / Android manifest, signing, secrets). Strip the WhereWillWeVisit-only examples from the agents.
- **Verify (Nigel):** read Design Decisions and the Review Agent and agree they describe this app.

### Task 2: Git, GitHub and platform trimming
- **Work:** `git init`, `.gitignore` check, private GitHub repo `thrower_app` under `nrbondnz` (Nigel creates it on github.com, or installs `gh`, which isn't installed yet), initial commit on `main`. ~~Remove the web/desktop folders~~ (done early, 2026-10-04). Set the app name and bundle IDs.
- **Verify (Nigel):** the repo is visible on GitHub; the app still runs from the JetBrains `main.dart` run configuration on an Android device and on iOS.

### Task 3: App skeleton and scoring domain
- **Work:** Replace the counter demo. Set up the `lib/` layout (`camera/`, `vision/`, `scoring/`, `auth/`, `ui/`), state management (recommendation to be presented as options), routing and theme. The pure-Dart `TargetModel` maps a normalised point to a score (5→1, 0 outside, edge rule per Q4). Add an `AuthService` interface (no provider yet). Test Agent: table-driven scoring tests.
- **Verify (Nigel):** a debug screen where tapping a drawn target shows the score for that point; `flutter test` passes.

### Task 4: Camera preview with permissions
- **Work:** Add a camera package, request permission on iOS and Android, and show a full-screen preview with a frame stream ready for the vision layer. Review Agent (permissions, manifest/plist).
- **Verify (Nigel):** on both phones, the app asks for camera permission and shows the live preview of the target.

### Task 5: Traceability review and close
- **Work:** Traceability Agent pass; update docs; archive this story; open the follow-on stories.
- **Verify (Nigel):** the matrix is complete and the follow-on stories are listed.

## Follow-on Stories (not this story)
Moved to [[backlog]]. The first, [[story-checkpoint-target-calibration]], is in planning.

---

## Task Records

### Task 0: Create the docs area — COMPLETE
- **What changed:**
  - `CLAUDE.md`: auto-loads the docs below at session start.
  - `docs/working-with-nigel.md`: adapted from WhereWillWeVisit; working habits kept, project sections as placeholders.
  - `docs/dont-ask-again.md`: general settled answers carried over.
  - `docs/agents/`: the five agent definitions copied, with a note that their examples come from WhereWillWeVisit.
  - `docs/thrower/`: vault with `Index.md`, `Architecture/`, `stories/`.
- **Verified by:** Nigel to review the files.
- **Checkpoint saved:** 2026-10-04

### Task 1: Settle architecture and adapt the agents — COMPLETE (awaiting Nigel's review)
- **What changed:**
  - `Architecture/Design Decisions.md`: the 3-layer pipeline and the throw-detection approach changed from PROPOSED to confirmed; branch model `main` only; single player first; knives/axes scoring research (IKTHOF/WATL/IATF).
  - `docs/agents/review-agent/review-agent.md`: **rewritten checklist** for this app: platform permissions, iOS/Android parity, debug leaking into release, secrets/signing, privacy of camera data, app size and performance, **physical safety** (never encourage the phone or the user to be in the line of throw), app identity and rollback.
  - `docs/agents/test-agent/test-agent.md`: per-layer testing (pure-Dart scoring; vision against **fixture images with tolerances**; widget tests); Java/TypeScript sections removed.
  - `docs/agents/docs-agent/docs-agent.md`: vault-only (there's no `docs/web/` site here); new sections on the vision pipeline and scoring rules; examples use this app's components.
  - `docs/agents/story-agent/story-agent.md`: protocol unchanged; the complexity table, checkpoint example and worked example ("Detect and Score Throws") rewritten for this app.
  - `docs/agents/traceability-agent/traceability-agent.md`: examples rewritten.
  - `docs/agents/index.md`, `docs/working-with-nigel.md`: trigger tables and branch rules updated.
- **Verified by:** the agent docs contain no references to Stripe, Amplify, Lambda, Java, GraphQL or `whereinnz` (scanned). **Nigel to read Design Decisions and the Review Agent** and confirm they describe this app.
- **Not covered by Task 1 (still open, not blocking):** board size and throwing distance (Q2), throws per round (Q5), Nigel's photos (Q3), CI/CD (A8).
- **Checkpoint saved:** 2026-10-04

### Task 2: Git, GitHub and platform trimming — COMPLETE
- **What changed:**
  - Web/desktop folders removed (done early, see Plan Changes Log).
  - **Bundle ID `nz.nrbond.thrower`** (Nigel, 2026-10-04):
    - Android: `namespace`/`applicationId` in `android/app/build.gradle.kts`; `MainActivity.kt` moved to `kotlin/nz/nrbond/thrower/`.
    - iOS: `PRODUCT_BUNDLE_IDENTIFIER` in `project.pbxproj` (`nz.nrbond.thrower`; tests: `nz.nrbond.thrower.RunnerTests`).
  - Display name **"Thrower App"** on both platforms (Android `android:label`; iOS `CFBundleDisplayName` was already this).
  - `git init -b main`; initial commit `d389575` (81 files: scaffold, platform changes, docs and `CLAUDE.md`). Docs were included because this is the repo's first commit; the "leave docs unstaged" rule applies from now on.
- **Safety Report (Review Agent checklist):**
  - ✅ Secrets: no keystore, `key.properties`, `local.properties` or `.env` staged (all gitignored).
  - ✅ Identity: bundle ID changed before any store publication, so no rollback concern.
  - ✅ Platform parity: changed on both Android and iOS.
  - n/a: permissions, privacy, app size, physical safety (no features yet).
- **Verified by:** `flutter test` passes; `flutter build apk --debug` builds; pushed to `https://github.com/nrbondnz/thrower_app` (`main`, after Nigel created the repo); **Nigel ran it ("works", 2026-10-05).**
- **Checkpoint saved:** 2026-10-05

### Task 3: App skeleton and scoring domain — COMPLETE
- **What changed** (all Dart, **unstaged** for Nigel to hot-reload):
  - `pubspec.yaml`: `flutter_riverpod: ^3.4.3` (pure Dart, no native code, so no Review Agent needed).
  - `lib/scoring/target_model.dart`: `TargetPoint` (normalised: centre 0,0; outer edge radius 1), `Ring`, `LineTouchRule`, `TargetModel.ikthof()` (radii 0.2/0.4/0.6/0.8/1.0 → 5/4/3/2/1), `scoreAt(point, bladeHalfWidth:)`.
  - `lib/auth/auth_service.dart`: `AuthService` interface and `AppUser`.
  - `lib/providers.dart`: `targetModelProvider`, `authServiceProvider` (throws until a provider is chosen).
  - `lib/ui/`: `HomeScreen`; `DebugTargetScreen` (tap to score, with a higher/lower line-rule toggle and a simulated blade 0.03 wide); `TargetPainter` (red/wood rings, red bull).
  - `lib/main.dart`: `ProviderScope` → `ThrowerApp`; counter demo removed; theme seeded from target red.
- **Test Report:**
  - New: `test/scoring/target_model_test.dart`: 17 tests (table-driven ring cases, points exactly on a line, blade touching a line under both rules, ring ordering).
  - New: `test/ui/debug_target_screen_test.dart`: 4 widget tests (prompt, centre = 5, outside = 0, the toggle rescoring a hit on a line 4 → 3).
  - Replaced: `test/widget_test.dart`: counter test → home screen opens the test target.
  - Result: `flutter test` **21 passed**; `flutter analyze` no issues.
- **Doc Update Log:** `Design Decisions.md`: added State Management: Riverpod and Code Layout; noted the line-touch implementation under Throwing Sport.
- **Verify (Nigel):** Home → "Scoring test target". Tap the centre (5), each ring (4–1) and outside (0). Tap just outside the bull's edge, then switch the toggle to "Line = lower" and watch the score drop. **Nigel: "works" (2026-10-05).** Committed `8ff0405` (code + tests; docs unstaged).
- **Checkpoint saved:** 2026-10-05

### Task 4: Camera preview with permissions — COMPLETE
- **What changed** (unstaged until Nigel says commit):
  - `pubspec.yaml`: `camera: ^0.12.1`.
  - `lib/camera/`: `CameraFrame`, `CameraSource`, `LiveCamera` (back camera, `ResolutionPreset.high`, no audio; BGRA on iOS / YUV420 on Android; broadcast `frames()` that streams only while listened to; plugin error codes → `CameraFailure`), `FrameRateMeter`.
  - `lib/providers.dart`: `liveCameraProvider` (autoDispose, **no automatic retry**).
  - `lib/ui/camera_screen.dart`: full-screen preview; releases the camera when backgrounded and re-opens on return; error view per failure; **debug-only** frames/s label (proves frames reach the app).
  - `lib/ui/home_screen.dart`: "Camera" button.
  - `ios/Runner/Info.plist`: `NSCameraUsageDescription`.
  - `android/app/src/main/AndroidManifest.xml`: removes the plugin's `RECORD_AUDIO`, `WRITE_EXTERNAL_STORAGE` and the implied `READ_EXTERNAL_STORAGE`.
- **Safety Report (Review Agent):**
  - ✅ Permissions: iOS camera string present; Android merged manifest = `CAMERA` + no-prompt `ACCESS_NETWORK_STATE` (+ debug-only `INTERNET`). Unused audio/storage permissions removed. Denied / permanently denied / restricted handled without crashing.
  - ✅ Platform parity: plist and manifest both changed. Android `minSdk` 24 meets CameraX.
  - ✅ Debug leakage: the frames/s label is behind `kDebugMode`.
  - ✅ Secrets: none.
  - ✅ Privacy: frames stay in memory on the device; nothing saved or sent.
  - ✅ Rollback: no data or identity changes.
  - ⚠️ **To watch (iOS):** some App Store submissions with the `camera` plugin have been flagged for a missing `NSMicrophoneUsageDescription` even with audio off. Not added now (the app uses no mic); add an honest string if App Store Connect raises it, or when impact-sound detection is built.
  - ⚠️ **Not verified here:** iOS build (needs the Mac).
  - Verdict: **OK to commit** once Nigel has checked it on both phones.
- **Test Report:**
  - New: `test/camera/frame_rate_meter_test.dart` (3), `test/camera/live_camera_test.dart` (4: error-code mapping), `test/ui/camera_screen_test.dart` (7: spinner, each failure's message and whether retry is offered, retry re-requests).
  - Found and fixed while testing: Riverpod 3's automatic retry kept failed camera starts in loading. On Android it would have re-shown the permission prompt. Retry is now disabled for this provider.
  - Result: `flutter test` **35 passed**; `flutter analyze` no issues; `flutter build apk --debug` OK.
  - Not unit-tested: `LiveCamera.open`/`frames` against a real camera (needs a device); covered by Nigel's check.
- **Doc Update Log:** `Design Decisions.md`: added Camera (plugin, permissions, lifecycle, no retry, denied handling); Code Layout row for `lib/camera/`.
- **Issue found by Nigel (2026-10-05):** the first attempt showed "The camera couldn't start" (the `unknown` failure), which hid the real error.
  - Changes: `LiveCamera.open` now wraps any exception (not only `CameraException`) with its code and description. In debug builds the error view shows that detail, and the error is logged with `debugPrint`.
  - Re-run on the Samsung SM A065F (Android 16): **preview works at about 12 frames/s**. Nigel confirmed it worked on his re-run too. The original cause wasn't captured; it was most likely a session started before the native plugin was built in (a new native plugin needs a full stop and re-run, not a hot reload/restart). If it recurs, the on-screen detail will show the cause.
  - **First-time permission flow tested by Claude on the Samsung:** with camera access revoked, tapping Camera showed the Android prompt ("Allow Thrower App to take pictures and record video?"); "While using the app" led straight to the live preview at 16 frames/s, with no errors. The deny path is covered by widget tests; not yet tried on a device.
  - Analyze clean; 35 tests pass.
- **Verify (Nigel):** on each phone, Home → "Camera":
  1. First time: the permission prompt appears; allow → live preview of the target, with a frames/s label top-left (expect roughly 20–30).
  2. Background the app and return: the preview comes back.
  3. Deny (or turn camera access off in Settings) → a clear message; on Android "Try again" re-asks; on iOS it points to Settings, and turning it on there and returning shows the preview.
- **Checkpoint saved:** 2026-10-05

### Task 5: Traceability review and close — COMPLETE
- **Traceability Report:**
  - Requirements: 8. Fully covered: **5** (R1, R2, R3, R8 + R4 on Android). Partly: **R4** (iOS device check outstanding). Handed on: **R5, R6** (target calibration, throw detection), **R7** (interface only; provider in the backlog).
  - **Gaps found and fixed:** (1) `tool/printable_target.dart` traced to no requirement; added **R8** (Nigel's request). (2) The Docs Agent's Known Issues / Common Tasks pages didn't exist, although Task 4 produced operational lessons; created both.
  - **Orphan code:** none. Every `lib/` file traces to R3, R4 or R7 (`FrameRateMeter` is the R4 "frames reach the app" proof; `CameraFrame`/`CameraSource` are the R4 hand-off to vision).
  - **Unexplained constants checked:** `debugBladeHalfWidth` 0.03 (debug only, commented), `ResolutionPreset.high` (Design Decisions → Camera), the 1 s window in `FrameRateMeter` (debug only). No action.
  - **Drift items logged (not fixed; out of scope):** no component→function tree or concept glossary yet; no System Diagram / Data Flow pages. Both are scheduled in target calibration Task 5 (see [[backlog]]).
- **Doc Update Log:**
  - Created: `Operations/Common Tasks.md` (running after native plugins, tests, regenerating targets, `adb` on this PC, resetting camera permission), `Troubleshooting/Known Issues.md` (camera couldn't start, Riverpod auto-retry, wireless `adb` ID changes, plugin permissions), `stories/backlog.md`, `stories/story-checkpoint-target-calibration.md`.
  - Updated: `Index.md`, `working-with-nigel.md`, `CLAUDE.md` (current story → target calibration).
  - Moved: this file to `stories/archive/`.
- **Verified by:** `flutter test` 35 passed; `flutter analyze` clean (after commit `7e3cf2a`).
- **Checkpoint saved:** 2026-10-05

---

## Plan Changes Log

- **2026-10-05:** Tool committed (`7e3cf2a`). Task 5 executed; story closed and archived.

- **2026-10-05:** Task 4 committed (`12ee9bf`) at Nigel's request; the iOS device check is still pending. **Added (Nigel's request): printable test target.** `tool/printable_target.dart` (`dart run tool/printable_target.dart`) takes ring sizes from `TargetModel.ikthof()` and writes `docs/thrower/reference/printable/target-A4.pdf` (180 mm), `target-A3.pdf` (270 mm) and `target-A1-full-size.pdf` (500 mm, for a print shop). Each has a 100 mm scale bar to check the print scale. It's a stand-in for early ring-finding work until Nigel's real board and photos are available. No test (dev utility); checked visually.

- **2026-10-05:** Task 3 verified and committed (`8ff0405`). Task 4 executed.

- **2026-10-05:** Task 2 complete (pushed). State management: Riverpod (Nigel). Task 3 executed. Routing kept to plain `Navigator` (minimal); `camera/` and `vision/` folders are created with their first code rather than empty now.

- **2026-10-04:** Plan approved by Nigel; branch model `main` only. Task 1 executed.

- **2026-10-04:** Q5/Q6 answered: single player first; repo `thrower_app`, private.

- **2026-10-04:** Q1 corrected: **knives and axes, not darts**. Camera is static; wooden board with 5 painted circles (example photo saved). Researched IKTHOF/WATL/IATF scoring; refining scoring by hit point goes to the backlog. Follow-on stories updated.

- **2026-10-04:** Q1 answered: darts, which stick in the target. Detection is a before/after frame comparison; the follow-on story was renamed to dart detection.

- **2026-10-04:** Nigel approved Q7 early. `web/`, `windows/`, `macos/`, `linux/` deleted and `.metadata` cleaned; `flutter analyze` shows no issues. Brought forward from Task 2.

- **2026-10-04:** Story created.
- **2026-10-04:** A1–A7 answered. Draft plan written (Tasks 1–5); target and throw detection split into follow-on stories.

## Notes
- Project is not yet a git repository.
- The source of truth for decisions is [[Design Decisions]]; this file tracks progress.
