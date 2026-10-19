# Story Checkpoint: Live Test (Score Real Recorded Boards)

## Story Goal
Nigel's words (2026-10-11): *"I would like the app to be able to run each live and score them, correctly! So a new button on the main screen 'live test' and then 'target 1' and 'target 2'. Note that there is at least 1 bounce out and a couple of rounds where just 1 throw is made."*

So the app should play each recorded board (`docs/thrower/reference/live-camera/1.mp4`, `2.mp4`) through the **same** calibrate → Play pipeline as the live camera, as if it were the camera. Its scores, bounce-outs and rounds should match what really happened.

## Complexity Score
8 (Large: full Story Agent protocol).
- Layers: UI, camera, vision and game (4).
- A new frame source (1).
- New ring colours (1).
- More than 3 acceptance criteria (1).
- Recorded data to build (1).

## Status
COMPLETE (2026-10-11): all 7 tasks done and committed (f68a5d7, 6a8f5c4, 5ca68ec, 00981f4); archived. Device checks and the original video moved to the [[backlog]] (Carry-overs from Live Test).

---

## What the Footage Shows (Analysis, 2026-10-11)

- **Source:** a 3 min 10 s phone video. Both boards are in it, on A-frame stands outdoors at dusk. It's 464 × 832 at 834 kb/s, which looks like a copy **compressed by a messaging app**. Each board is only **about 106 px across**, and a stuck knife is a blob of 2–6 px.
- **Camera position:** it faces the boards **from the throwing area**, roughly head-on, not 45° to the side as the app assumes. Knives point almost straight at the camera, so each looks like a short blob around its entry point, not a long blade. People walk between the camera and the boards, and pass close by it.
- **Ring colours:** both boards have *painted ring / pale ring / painted ring / pale ring / painted bull* inside a pale outer wood edge, and **the painted colours differ by ring**.
  - Board 1: red, pale, red, pale, **dark** (black/green) bull.
  - Board 2: **dark green**, pale, red, pale, **red** bull.
  - The app's ring finder learns **two** colours, so this breaks it. Treat it as **paint vs bare wood**: any paint colour against one wood colour.
- **Video compression:** a frame-wide "pulse" **once a second** (the compression refreshing the picture) changes 1–14% of the board area. The motion detector must not read that as throws.
- **Impact shake:** each hit makes the board and stand wobble for about 0.5 s (a few px of motion blur).
- **Events, roughly** (from frame-to-frame motion):
  - Board 1: impacts at about 4, 10, 33, 40, 47, 57, 98 … s.
  - Board 1: people at the board at about 21–30, 46–56, 111–119, 144–154, 164–168 and 180–184 s.
  - Board 2 has a similar pattern.
  - Most stuck knives are in or near the bull.
  - The exact throws, sticks, bounce-outs and scores **still need ground truth** (Q2).

## Questions Answered (Nigel, 2026-10-11)
- **Q1, original video:** **use what we have** (the 464 × 832 copy). Scores near ring lines are judged as well as the footage allows.
- **Q2, ground truth:** **I draft it, Nigel checks** it on a review page (Task 1).
- **Q3, ring values:** the pale outer wood edge scores **0**; the outer painted ring is **1** … the bull is **5**.
  - Board 1: red = 1, pale = 2, red = 3, pale = 4, dark bull = 5.
  - Board 2: green = 1, pale = 2, red = 3, pale = 4, red bull = 5.
- **Q4, builds:** **in TestFlight builds too**, so Nigel's brother can run the live tests. Keep the packed frames small: about 15 fps, and only as many pixels as the clip has.

---

## Story Plan (proposed)

### Task 1: Ground truth and test data
- **Setup:** the clips; Q1 and Q2 answered.
- **Work:**
  - Extract each clip at 15 fps.
  - Draft a truth table per target: event time, kind (stuck / bounce-out / board visit), score, round.
  - Build a review page with zoomed before/after crops of every event, where Nigel confirms or corrects each one.
  - Save the confirmed truth as `truth.json` next to the clips, and short frame sequences as test fixtures.
- **Verify:** Nigel confirms the truth table on the review page.

- **Status:** COMPLETE (draft). Nigel will judge the app's live run instead of checking every event first, so the [answer key page](https://claude.ai/artifact/1fAKaR23dR8D5DnWkC9WN6) stays available for corrections. Answers given there are saved in the page's `truth` collection, one document per event id.
- **Answer key:** `docs/thrower/reference/live-camera/truth.json` (Nigel's scores).
  - Board 1: 4 rounds, 11 throws, including 1 bounce-out (36.8 s, clearly seen).
  - Board 2: 5 rounds, 11 throws: 2 possible bounce-outs (107.7 s, 136.5 s), and the last two rounds are 1 throw each.
  - Unsure: board 1 at 18.2 s (a third knife?).
- **Findings that shape Tasks 3 and 5:**
  - **Whole-picture compression jumps.** A jump comes about once a second, and big ones at 4, 10, 33, 40, 112, 144, 165 and 179 s. They change the background as much as the boards. Detection must look for **local** change, never overall change.
  - **The first 4 s repeat one frame** (a still at the start of the video).
  - **The two throwers throw together**, so both boards have events at the same moments, in different places.
  - **Board 1's events from 59–104 s were on board 2**: board 1 shows no throws then.

### Task 2: Play a recording as if it were the camera
- **Setup:** Task 1.
- **Work:**
  - Camera layer: add a `RecordedCamera`, a second implementation of the camera interface. It yields `CameraFrame`s from a packed frame asset at real-time pace, and the UI gets a preview widget.
  - Pack each clip as an asset (JPEG frames at 15 fps, decoded in Dart).
  - Home screen: **Live test** → **Target 1** / **Target 2** → the existing calibration screen → Play.
  - Vision and game code stay unchanged.
- **Verify:** Nigel taps Live test → Target 1, sees the board video playing, and can tap Find target. It may fail on the new colours; that's Task 3.

- **Status:** COMPLETE: waiting for Nigel's device check.
- **What changed:**
  - `TargetCamera` interface, with `LiveCamera` and a new `RecordedCamera`.
  - `FramePack` (`.tfrm`) and `tool/pack_recording.dart`.
  - `assets/live/target1.tfrm` and `target2.tfrm`: 140 × 140, 15 fps, about 10.4 MB each.
  - `cameraProvider` (renamed from `liveCameraProvider`) and `recordingChoiceProvider`. A calibration and a game reset when the camera changes.
  - `RecordedPreview`, with the playing time shown.
  - `LiveTestScreen`: choose a target, then **1. Calibrate target**, then **2. Play**.
  - Home has a **Live test** button.
  - Play starts the recording from the beginning, and has a restart / play-again button.
- **Known:** **Find target** fails on both recordings today (target 1: "ring centres disagree"; target 2: "ring sizes out of proportion"). That's Task 3.
- **Verify (Nigel):**
  - Home → Live test → Target 1 → 1. Calibrate target: the board shows, paused on its first frame, with "Target 1 · 0:00 / 3:09".
  - Find target: expect "not found" for now.
  - Back, then Target 2: the other board.

#### Test Report (Task 2)
- **New tests:**
  - `frame_pack_test.dart`: round trip, bad signature, truncated pack; and both bundled recordings (140 × 140, 15 fps, 2,848 frames, first frame decodes).
  - `recorded_camera_test.dart`: opens paused on frame 0 and keeps delivering it; BGRA frames upright and stamped; plays at the recording's rate; stops on the last frame; pause and resume; restart after the end.
  - `live_test_screen_test.dart`: home → Live test → Target 1 and 2; calibrate needs a choice, and play needs a calibration; leaving goes back to the phone camera; switching camera means a new game and calibration; the preview shows the playing time; Play starts the recording and replays it.
- **Updated:** `camera_screen_test.dart` and `system_bars_test.dart` (`cameraProvider`).
- **Result:** `flutter analyze` clean; `flutter test` 265 passed.

#### Safety Report (Task 2): `pubspec.yaml` assets
- **Files reviewed:** `pubspec.yaml` (adds `assets/live/`), plus `assets/live/*.tfrm`.
- **Checks passed:**
  - ✅ Permissions: none added (no video plugin, no native code).
  - ✅ Platform parity: pure Dart, so the same on iOS and Android.
  - ✅ Secrets: none.
  - ✅ Identity and rollback: no ID or signing change; removing the asset line rolls it back.
  - ✅ Physical safety: no new instructions about approaching the board.
- **Flagged:**
  - ⚠️ **App size: +21 MB in every build, TestFlight included.** This is Nigel's decision (Q4). Revisit before an App Store release (backlog story 6, store hygiene).
  - ⚠️ **People in the recordings.** The throwers walk past the boards (bodies, and partly faces at 140 px). Only internal TestFlight testers get these builds today. **Before any public release**, remove the recordings or confirm the people in them are happy to be in the app.
- **Verdict:** OK to commit when Nigel says so, with the two flags accepted.

### Task 3: Find real boards (paint vs wood, any ring colours)
- **Setup:** Task 2.
- **Work:**
  - Ring finding: learn the **wood** colour and treat every paint colour as "painted".
  - Find the 5 ring edges and ignore the pale outer edge and bark.
  - Cope with small boards (about 106 px).
  - Fixture tests on frames from both clips.
- **Verify:** Find target outlines the rings correctly on both targets.

- **Status:** COMPLETE, committed (f68a5d7, with Task 4).
- **What changed:** `ColourRingLocator` gets a second, colour-blind reading (colour edges at 2, 3 and 4 bull radii per ray). It also enlarges small images to at least 420 px, keeps the best plausible pass, and rejects fits below 40% confidence. `RgbImage.upscaled`. See [[Design Decisions]] → Ring Finding on Real Boards.
- **Measured truth:** both boards have boundaries at 8.5 / 16.5 / 25–25.5 / 32.5 px, outer edge about 42 px, centres (67.6, 69.8) and (72.2, 69.0).
- **Verify (Nigel):** Live test → Target 1 → 1. Calibrate target → **Find target**. The green rings should sit on the painted edges (bull, then each ring). Lock. Then the same for Target 2.
- **For Task 5:** on the nudge frames, a 7 px noise blob (the minimum knife size there is 6.0) counts as a new knife once the target outline moves by 0.2 px. The knife-size rule is marginal at small scales; rework it with the head-on knives. `camera_nudge_test.dart` now pins its calibration, so it tests motion and classification only.

#### Test Report (Task 3)
- **New:** `live_recording_locate_test.dart`: each first frame is found with every ring within 2.5 px of the measured truth; and every 10 s, at least 13 / 8 right and at most 2 wrong.
- **Updated:** `camera_nudge_test.dart` (pinned calibration).
- **Result:** `flutter analyze` clean; `flutter test` 268 passed.

### Task 4: Zoom the camera onto the target (added 2026-10-11)
- **Setup:** Task 3.
- **Why:** Nigel: *"zoom on the target using the phone… on find it zooms to the target using camera zoom"* ("not just cutting the screen down, but camera zoom"). More real pixels on the board help every knife step that follows. It changes live use only; the recordings can't zoom.
- **Work:**
  - `TargetCamera` gains `maxZoom`, `zoom` and `setZoom`. `LiveCamera` uses the plugin's `setZoomLevel`; `RecordedCamera` can't zoom (max 1×).
  - `zoomToFit` (vision, pure Dart) works out the zoom: the board fills 70% of the shorter side, the board plus 0.3 × its radius stays in the picture (the zoom is about the centre), up to the camera's maximum, and no zoom for a gain under 1.2×.
  - `findTarget` (`lib/game/find_target.dart`): at 1×, find → zoom → wait 500 ms → find again. If the zoomed search fails, back to 1× with the first result.
  - `CalibrationState.zoom`, kept through adjusting, locking and Re-calibrate; `cameraProvider` re-applies it when the camera reopens (Calibrate → Play).
  - Status: "zoomed in 2.4×", plus *"Centre the board in the picture for a closer view."* when the board's position held the zoom back (Nigel's choice).
  - In-app Instructions: centre the target; Find target zooms in.
- **Verify (Nigel, on the phone):**
  1. Home → Calibrate target, with the board **near the middle** of the picture → **Find target**. The preview zooms in until the board fills most of the width, the rings are outlined on the zoomed picture, and the status says "zoomed in N×".
  2. Aim so the board is near one edge, then **Find again**: it zooms less and suggests centring the board.
  3. Lock, go back, then **Play**: the preview is still zoomed and a tap/knife scores where expected.
  4. Live test → Target 1 → Find target: no zoom (recordings can't), same as before.
- **Status:** COMPLETE, committed (f68a5d7). Not yet checked on a phone that `setZoomLevel` zooms the image stream (not just the preview) on both platforms; if the outline lands in the wrong place after zooming, that's why.

#### Test Report (Task 4)
- **New:**
  - `zoom_to_fit_test.dart`: centred board → 70% fill; capped at the camera's maximum; off-centre board limited by its position and flagged; a board that already fills the picture, or a gain under 1.2×, gives 1×; a camera that can't zoom gives no tip.
  - `find_target_test.dart` (fake zooming camera): finds at 1×, zooms, keeps the zoomed rings; Find again starts from 1×; a failed zoomed search goes back to 1× and keeps the first rings; nothing found stays at 1×; a recording searches once; a camera that refuses to zoom keeps the 1× rings.
- **Updated:** `calibration_screen_test.dart` (zoom and centring text), `calibration_editor_test.dart` (zoom kept through adjust / lock / unlock), `recorded_camera_test.dart` (can't zoom).
- **Not covered by tests:** `LiveCamera`'s zoom and `cameraProvider` re-applying it need the real plugin; they're in Nigel's device check.
- **Result:** `flutter analyze` clean; `flutter test` 284 passed.

#### Doc Update (Task 4)
- `Design Decisions.md`: new section *Zoom the Camera onto the Target*; Coarse-to-Fine notes the app now zooms itself; the camera section's provider name fixed (`cameraProvider`).
- `Known Issues.md`: a nudge is multiplied by the zoom.
- `lib/ui/instructions.dart`: centre the target; Find target zooms in.
- **Drift noted (not fixed):** the Code Layout table doesn't list `lib/game/` or `TargetCamera` / `RecordedCamera`; for Task 7.

#### Safety Report (Task 4)
- **Files reviewed:** `lib/camera/live_camera.dart` (no platform files, permissions or plugins change; `setZoomLevel` is in the existing `camera` plugin).
- ✅ Permissions, platform parity (same plugin call on both), secrets, privacy (frames stay on the device), identity: unchanged.
- ✅ Physical safety: the new tip ("Centre the board in the picture") is about aiming the phone, done before throwing; re-aiming happens only at calibration, which already carries *"Only adjust when no one is throwing."*
- **Verdict:** OK to commit when Nigel says so.

### Task 5: Detect throws in real footage
- **Setup:** Task 4.
- **Work:**
  - Motion detector: ignore the 1-second compression pulse, ride out the impact shake, and handle people passing close to the camera.
  - Stuck vs bounce-out with **head-on** knives (small blobs).
  - A headless test replays each clip and compares the event list with the truth.
- **Verify:** on Play, the event log for each target matches the truth table (sticks, bounce-out, board visits).

- **Status:** COMPLETE, committed by Nigel (6a8f5c4).
- **Before:** replaying the recordings gave a false bounce-out almost every second (compression jumps), board 2 "blocked" for 49 s, and missed knives.
- **Now:** both recordings give exactly the answer key's throws (stuck or bounce-out, at the right time) and collections. The only extras are harmless: "nothing" flickers, and repeat visits in rounds with no throws.
- **What changed** (each rule and its measured reason: [[Design Decisions]] → Throw Detection on Real Footage):
  - `MotionDetector`: a per-pair change threshold from each pair's robust noise (`pairNoise`); motion judged on the **largest connected changed shape** (`largestShape`, new in `image_difference.dart`); `MotionEpisode.peakShape`; a gentler threshold for the before/after comparison (`settledNoiseFactor`) and a strict one after visits (`visitThreshold`).
  - `TargetCamera.minChange`: 12 for the live camera, 20 for recordings (compression blocks); `ThrowWatcher` passes it on.
  - `classifyThrow`: a bounce-out needs a knife-sized moving shape, else the new outcome **nothing** (ignored); a person-sized shape is a visit; a knife is at most 6% of the target; "fell out" only if the shape disappeared.
  - `ThrowTracker`: 3 s after a visit, anything but a stuck knife is part of the visit.
  - Play and the status line handle **nothing** ("Nothing new").
- **Still wrong:** most head-on knives get **no entry point**, so they score 0 or the wrong ring. That's Task 6.
- **Verify (Nigel):** Live test → Target 1 → Calibrate (Find target, Lock) → Play. Throws, bounce-outs and round ends should now follow the footage: no stream of false bounce-outs, and a round ends at each collection. Then Target 2. Scores aren't right yet.

#### Test Report (Task 5)
- **New:**
  - `live_replay_test.dart`: for each recording, every answer-key throw is found (stuck or bounce-out, ±1 s); nothing else is taken for a throw; every collection is a board visit. About 20 s per recording.
  - `throw_tracker_test.dart`: changes just after a visit are part of it; 3 s later they're bounce-outs again; a stuck knife just after a visit still counts.
  - `image_difference_test.dart`: `largestShape` (diagonals join; specks stay small; empty).
  - `motion_detector_test.dart`: a whole-picture jump isn't motion; a throw is still seen when the picture jumps during it.
  - `throw_classifier_test.dart`: knife-sized motion → bounce-out, specks → nothing, person-sized → visit; a shape far bigger than a knife isn't a stick; a knife landing on a known one is a stick, not it falling out.
- **Updated:** `find_target_test.dart` (fake camera's `minChange`).
- **Result:** `flutter analyze` clean; `flutter test` 303 passed (every rendered and real-phone fixture still passes).


### Task 6: Score and rounds match
- **Setup:** Task 5.
- **Work:**
  - Entry point for a head-on knife (the blob's centre when the board is seen face-on, not the side-view axis rule).
  - Rounds of 1–3 throws (a board visit ends a round early; already supported).
  - The replay test checks every score and round total against the truth.
  - **On-screen markers** (Nigel, 2026-10-11). These are drawn over the board on the Play screen, so live play gets them too, and they clear when the round is collected:
    - each stuck knife shows a **yellow circle with its score** at the entry point (it replaces today's numbered dot)
    - each bounce-out shows a **"0" marker beside the board**
- **Verify:** Nigel plays Target 1 and Target 2, and the final scoreboards match the truth table.

- **Status:** COMPLETE, committed (5ca68ec); Nigel's device check pending.
- **Rounds match:** replayed through the real `GameSession`, both recordings give the answer key's rounds exactly, throw by throw (stuck or bounce-out), including the 1-throw rounds. That needed one more rule: someone passing close to the camera (board 2 at 97 s, 2.6 s) had ended a round, so a "visit" under 3 s that takes no known knife is now **nothing**.
- **Scores:** 11 of 19 knives exactly as Nigel scored them, and all but two within a ring.
  - **Target 1** (Nigel / app): R1 4 5 5 / 4 4 5; R2 0 5 5 / 0 2 3; R3 4 5 0 / 4 4 0; R4 3 3 4 / 3 4 4. Total 43 / 37.
  - **Target 2:** R1 5 4 5 / 5 5 5; R2 4 3 0 / 4 5 0; R3 2 0 4 / 2 0 4; R4 5 / 5; R5 3 / 4. Total 35 / 39.
  - The two misses by more than a ring, board 1 at 40.5 s and 43.2 s: the changed shape isn't where Nigel places the knife (dark knives in the dark bull barely change the picture). Rings are ~8 px apart at 140 px; the original video would help most here.
- **What changed:**
  - `faceOnEntry` and `isFaceOn` (`entry_point.dart`): on a face-on board, the entry is the knife shape's pixels nearest the bull. `ThrowWatcher` uses it at once (no full-resolution capture); side views keep `GeometricEntryEstimator`. See [[Design Decisions]] → Throw Detection on Real Footage.
  - `classifyThrow`: `minVisit` 3 s (someone passing the camera).
  - **On-screen marks** (`RoundMarks`, `round_marks.dart`; drawn by `PlayOverlayPainter`): a yellow circle with its score at each knife's entry; an orange "0" beside the board for a bounce-out, a stuck knife without an entry, or one that fell out; cleared on collection or a new round. Replaces the numbered dots.
  - In-app Instructions: the yellow circle and the 0 beside the target.
- **Verify (Nigel):** Live test → Target 1 → Calibrate → Play. Each knife gets a yellow circle with its score, bounce-outs a 0 beside the board, the marks clear when the knives are collected, and the rounds follow the footage. Then Target 2.
- **To check on the A4 printout:** a waved hand (the paper bounce-out) is now judged by size and length. A big hand held in for under 3 s could read as nothing rather than a bounce-out; if so, the paper instructions need a tweak.

#### Test Report (Task 6)
- **New:**
  - `live_replay_test.dart`: the game's rounds hold the answer key's throws, round by round; knives scored exactly as Nigel did, at least 5 of 10 and 6 of 9.
  - `round_marks_test.dart`: score circle at the entry; bounce-out → 0 beside; no entry → 0 beside; falling out moves the mark beside as 0; collection clears; a new round clears; `besidePosition` right of the board, or left if no room.
  - `throw_classifier_test.dart`: a person-sized change under 3 s that takes nothing is nothing.
- **Updated:** `throw_classifier_test.dart` (visit tests last 5 s).
- **Result:** `flutter analyze` clean; `flutter test` 316 passed.


### Task 7: Traceability and docs
- **Work:** Traceability Agent; Design Decisions (head-on cameras, paint vs wood, recorded camera); Known Issues (compression pulse).
- **Verify:** all tests pass; the docs match the code.

- **Status:** COMPLETE, committed (00981f4).
- **What changed:**
  - Orphan code removed: `RecordedCamera.pause` / `resume` (from Task 2; nothing used or asked for them), with their test.
  - Docs: the Code Layout table in [[Design Decisions]] now lists `lib/game/`, `TargetCamera`, `RecordedCamera`, `FramePack`, the throw-detection and entry-point pieces, and `RoundMarks` (drift noted in Task 4).
- **Result:** `flutter analyze` clean; `flutter test` 315 passed (one fewer: the pause/resume test).

#### Traceability Report: Live Test

**Coverage summary:** 12 requirements; 8 fully covered (design + code + test); 3 partly covered (only checkable on a device, or known to be imperfect); 1 config-only (no test possible). Orphan code: 1 found and removed.

- **R1**
  - **Requirement (source):** A **Live test** button on the main screen, then **Target 1** / **Target 2** (Nigel)
  - **Design:** Live Test: A Recording in Place of the Camera
  - **Implementation:** `HomeScreen`, `LiveTestScreen`, `recordingChoiceProvider`
  - **Test:** `live_test_screen_test.dart`
  - **Status:** ✅
- **R2**
  - **Requirement (source):** Each recording runs **live** through the same calibrate → Play pipeline, analysed every run (Nigel)
  - **Design:** Same
  - **Implementation:** `RecordedCamera`, `FramePack`, `cameraProvider`, `RecordedPreview`
  - **Test:** `recorded_camera_test.dart`, `frame_pack_test.dart`, `camera_view_test.dart`
  - **Status:** ✅
- **R3**
  - **Requirement (source):** Find the rings whatever their colours (Nigel: "the ring colors change")
  - **Design:** Ring Finding on Real Boards
  - **Implementation:** `ColourRingLocator` (edge reading), `RgbImage.upscaled`
  - **Test:** `live_recording_locate_test.dart`
  - **Status:** ✅
- **R4**
  - **Requirement (source):** Pale outer edge scores 0, bull 5 (Q3)
  - **Design:** Throwing Sport
  - **Implementation:** `TargetModel.ikthof`
  - **Test:** `target_model_test.dart`
  - **Status:** ✅
- **R5**
  - **Requirement (source):** Detect every throw, **including bounce-outs**, and nothing else (Nigel)
  - **Design:** Throw Detection on Real Footage
  - **Implementation:** `MotionDetector` (pair noise, largest shape), `classifyThrow`, `ThrowTracker`, `TargetCamera.minChange`
  - **Test:** `live_replay_test.dart` (every throw; nothing extra), `motion_detector_test.dart`, `throw_classifier_test.dart`, `throw_tracker_test.dart`, `image_difference_test.dart`
  - **Status:** ✅
- **R6**
  - **Requirement (source):** Rounds, **including rounds of just 1 throw** (Nigel)
  - **Design:** Rounds and Scoring; Throw Detection on Real Footage
  - **Implementation:** `GameSession.boardVisited`, `classifyThrow` (`minVisit`), `ThrowTracker` (cool-down)
  - **Test:** `live_replay_test.dart` (rounds, throw by throw), `game_session_test.dart`
  - **Status:** ✅
- **R7**
  - **Requirement (source):** Score each throw **correctly** (Nigel)
  - **Design:** Throw Detection on Real Footage → Where a face-on knife went in
  - **Implementation:** `faceOnEntry`, `isFaceOn`, `ThrowWatcher`
  - **Test:** `live_replay_test.dart` (floor: 5 of 10, 6 of 9 exact)
  - **Status:** ⚠️ **Partial:** 11 of 19 exact, 17 within a ring. Limited by the 140 px footage. The original video is the fix.
- **R8**
  - **Requirement (source):** A **yellow circle with the score** at each knife and a **0 marker beside the board** for a bounce-out, cleared on collection (Nigel)
  - **Design:** Rounds and Scoring (Play screen)
  - **Implementation:** `RoundMarks`, `besidePosition`, `PlayOverlayPainter`
  - **Test:** `round_marks_test.dart`
  - **Status:** ⚠️ **Partial:** the painting itself isn't tested (Nigel's visual check).
- **R9**
  - **Requirement (source):** Live test in **TestFlight builds** too (Q4)
  - **Design:** Live Test section
  - **Implementation:** `pubspec.yaml` assets
  - **Test:** none (config)
  - **Status:** ⚠️ **Config only.** Safety flags stand: +21 MB, people in the recordings (before any public release).
- **R10**
  - **Requirement (source):** **Camera zoom** onto the target on Find (Nigel)
  - **Design:** Zoom the Camera onto the Target
  - **Implementation:** `findTarget`, `zoomToFit`, `TargetCamera.setZoom`, `LiveCamera`, `CalibrationState.zoom`, `cameraProvider`
  - **Test:** `zoom_to_fit_test.dart`, `find_target_test.dart`, `calibration_editor_test.dart`
  - **Status:** ⚠️ **Partial:** that the plugin zooms the image stream, and the zoom is restored on reopening, needs a device.
- **R11**
  - **Requirement (source):** Off-centre board: zoom what it can, plus a tip (Nigel's choice)
  - **Design:** Zoom section
  - **Implementation:** `ZoomPlan.offCentre`, `calibrationStatus`
  - **Test:** `zoom_to_fit_test.dart`, `calibration_screen_test.dart`
  - **Status:** ✅
- **R12**
  - **Requirement (source):** Answer key: Claude drafts, Nigel corrects (Q2)
  - **Design:** Task 1
  - **Implementation:** `reference/live-camera/truth.json`
  - **Test:** used by `live_replay_test.dart`
  - **Status:** ✅

**Gaps and recommendations:**
1. **R7, score accuracy.** Recommend the original phone video (Q1): boards would be roughly 250–500 px across instead of 106, and the replay test's floor can then be raised towards a full match.
2. **R8, R10: device checks.** Look at the marks on Play; zoom on a real phone, including going from Calibrate to Play.
3. **A4 paper bounce-out** (waving a hand): now judged by the moving shape's size and how long it lasts; check it still reads as a bounce-out.
4. **Unconfirmed rule:** a knife that falls out scores 0 (from before this story); still waiting for Nigel to confirm.

**Backward check:** every class and function added in this story traces to R1–R12. `GeometricEntryEstimator` stays for side-view mounts (the app's intended set-up). `RecordedCamera.pause` / `resume` had no requirement and was removed.


---

## Plan Changes Log
- 2026-10-11: plan drafted.
- 2026-10-11: Nigel's corrections to the draft:
  - board 1 round 1 has a **4** that was drafted as a 5 (taken to be the 12.0 s knife)
  - **bounce-outs were missed**: found at 109.0 s and 162.1 s on board 1
  - he'll review the live analysis rather than the page first.
- 2026-10-11: **Nigel gave the answer key** (his reading of the footage, not always clear). Saved as `reference/live-camera/truth.json`.
  - Board 1: 4 5 5 · bounce 5 5 · 4 5 bounce · 3 3 4 · bounce · bounce.
  - Board 2: 5 4 5 · 4 3 bounce · 2 bounce 4 · 5 · 3.
  - Changes from Claude's draft: B1 40.5 s 1→5; B1 R4 4,3,5→3,3,4; B1 R6 a bounce-out (~177 s); B2 R1 5,5,5→5,4,5; B2 105.2 s 4→3; B2 133 s 1→2.
- 2026-10-11: Nigel confirmed that recordings are analysed live on every run (no stored answers in the app). Added the score circles and bounce-out markers to the scoring task (now Task 6).
- 2026-10-11: **Nigel asked for camera zoom on Find target** (the phone's zoom, not a crop). Added as a new **Task 4** after Task 3 (his choice); the old Tasks 4–6 are now 5–7. Off-centre board: zoom what it can, plus a tip to centre it (his choice).
- 2026-10-11: Tasks 3 and 4 committed (f68a5d7); Task 5 started.
- 2026-10-11: Task 5 committed by Nigel (6a8f5c4, with the docs and reference videos); Task 6 started.
- 2026-10-11: Task 6 committed (5ca68ec); Task 7 (traceability) done and committed (00981f4). Nigel said "commit this": story archived; open checks moved to the backlog.

## Notes
- **Why the original video matters (Q1).** At 106 px per board, the ring edges are 2–3 px apart near the bull, and a knife is a few pixels. Scores near a line will be guesses. The original phone file, sent by AirDrop, an iCloud/Google Photos link, or email "actual size", is probably 1080 × 1920 or 4K, which makes each board roughly 250–500 px across. The plan works either way, but "correctly" is far more achievable with the original.
- The recorded camera position (head-on, from the throwing line) differs from the app's intended side mount. Handling both is good: real users will mount phones in different places.
