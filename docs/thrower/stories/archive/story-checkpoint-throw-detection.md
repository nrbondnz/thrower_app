# Story Checkpoint: Throw Detection and Scoring

## Story Goal

With the target calibrated and locked ([[story-checkpoint-target-calibration]]), watch the board and, for every throw, decide **stuck or bounced off**, find **where the blade entered the wood** (not where the handle is), and **score** it with `TargetMapping` + `TargetModel`. A single-player session shows each throw's score and the running total, and starts a new round when the knives are pulled out.

The approach is already decided (Design Decisions → Throw Detection): a static camera; keep a **reference frame** of the settled board; motion means a throw is happening; once still again, **compare with the reference**: a new object means a stick, nothing new means a bounce-out (0); find the blade's entry point; make the new frame the reference; a person at the board followed by knives removed means end of round.

## Complexity Score

| Factor | Score |
|---|---|
| Layers: camera stream (continuous), vision (motion, difference, entry point), scoring, UI (session) | 4 |
| Models: throw, session/round | 2 |
| Branching: stick / bounce-out / retrieval / fall-out | 1 |
| More than 3 acceptance criteria | 1 |
| **Total** | **8 (Large): full Story Agent protocol** |

## Status

**COMPLETE (2026-10-08)**: all tasks done; archived. Commits: `2e9223b` (sequences), `93c6c27` (motion), `e51d7da` (stuck/bounce), `f0e4bd2` (entry point), `e792eb4` (play screen), plus the Task 6 clean-up. **Carry-overs** in [[backlog]]: device checks (iOS; real board), the fall-out scoring rule to confirm, performance on the phone.

---

## Questions for Nigel

| # | Question | Why it matters |
|---|---|---|
| T1 | **Knives first, axes later?** | **Yes: knives first** (Nigel, 2026-10-08). Axes go to the backlog. |
| T2 | **Throws per round** (Q5) | **3** (Nigel, 2026-10-08). |
| T3 | **Throwing distance?** | **4 m** (Nigel, 2026-10-08). |

## Decisions Needed

### D1: How to find the blade's entry point (the hard part)

| Option | What it means | Pros | Cons |
|---|---|---|---|
| **A. Geometry on the difference (recommended first)** | The new knife is the region that changed between reference and settled frame. The handle sticks out towards the camera, so in the image the blade enters at the end of that region **nearest the board's surface**: with a calibrated, static camera, the end that lies on the board plane (low parallax), found from the region's shape and its shadow-free core. | Pure Dart, testable on the rendered views (known entry points), no training data | Heuristic; a handle hiding its own entry point, shadows and neighbouring knives make it harder |
| B. Trained model (keypoint) | A small model predicts the entry point from a crop | Copes with messy cases | Needs many labelled images (renders can supply many) and an ML runtime |

**Decided (Nigel, 2026-10-08): A first, measured against the renders' known entry points;** keep the interface (`EntryPointEstimator`) so B can replace it if A's error is too large.

## Traceability Matrix (final, 2026-10-08)

| ID | Requirement | Design ref | Implementation | Test | Status |
|---|---|---|---|---|---|
| T-R0 | Realistic throw sequences with known answers (stick, bounce-out, retrieval) from the camera's position, with Nigel's all-steel knives | Plan Task 1; Design Decisions → The Knives | `SyntheticScene` (`FlyingKnife`, `Person`, steel knife), `tool/render_throw_sequences.dart`, `tool/reference_board.dart` | `synthetic_scene_test.dart`; used by every T-R test | ✅ Task 1 (added in Task 6: was untraced) |
| T-R1 | Detect a throw (motion) and wait for the board to settle; not fooled by a person standing at the board, noise or slow light changes | Design Decisions → Motion and Settle | `MotionDetector`, `WatchRegion`, `frameToLuma`, `WatchStatus` | `motion_detector_test.dart` (7: one episode per rendered sequence in the right place, person ≫ throw, noise σ 4 and light drift never trigger), `luma_image_test.dart` (5) | ✅ Task 2 |
| T-R2 | Tell a stick from a bounce-out (0 points), and from someone at the board | Design Decisions → Stuck or Bounced Off | `classifyThrow`, `findNewObject`, `ThrowOutcome`; shown in `WatchStatus` | `throw_classifier_test.dart` (9: 4 rendered sequences → stuck / stuck / bounce-out / board visit, the shape covers the true entry point; noise, blocked, big change, new scene, shape off the target) | ✅ Task 3; the fall-out gap closed in Task 5 (T-R5) |
| T-R3 | Find the blade's entry point, not the handle (or its shadow) | Design Decisions → Blade Entry Point | `GeometricEntryEstimator` (`EntryPointEstimator`), `outwardDirection`; full-resolution before/after in `ThrowWatcher` | `entry_point_test.dart` (7: 6 rendered throws within 4% of the target radius with the right score (actual 0.7–1.7%); outward direction) | ✅ Task 4 |
| T-R4 | Score the throw and keep a single-player session: rounds of 3, totals | Design Decisions → Rounds and Scoring | `GameSession`, `GameNotifier`/`gameProvider`, `ThrowWatcher`, `PlayScreen` | `game_session_test.dart` (8), `game_notifier_test.dart` (11), **`play_through_test.dart`: recorded frames of a whole round → 4 · 3 · 0 = 7** | ✅ Task 5 |
| T-R5 | Detect retrieval (end of round) and reset; a knife falling out isn't taken for a new one | Design Decisions → Motion and Settle, Stuck or Bounced Off, Rounds and Scoring | `MotionDetector` (blocked), `ThrowTracker` (known knives), `classifyThrow(knownKnives:)` | `throw_classifier_test.dart` (+3 fell-out), `play_through_test.dart` (retrieval closes the round, knives forgotten) | ✅ Task 5 |
| T-R6 | Never imply the lane is safe; no prompts to approach the board while armed | Review Agent §7 | `gameText` ("Collect your knives when no one is throwing"), `playStateText` | `game_notifier_test.dart` (play screen text) | ✅ Task 5 |

---

## Story Plan (APPROVED 2026-10-08)

### Task 1: Test sequences
- **Work:** extend the renderer to produce **frame sequences** (settled → arm/knife in motion → settled with a new knife; a bounce-out; a person retrieving), with known answers. Same camera (2 m, 45°), reference board.
- **Verify (Nigel):** look at the sequences; they read like a real throw.

### Task 2: Motion and settle (state machine)
- **Work:** `ThrowDetector` states: **armed → motion → settling → settled**, from frame differences inside the calibrated target area, on downscaled frames at the camera's frame rate.
- **Verify (Nigel):** on the phone with the locked A4 target, wave a hand in front of it: a debug label goes motion → settling → settled.

### Task 3: Stick or bounce-out
- **Work:** compare the settled frame with the reference: a new object inside the target means a stick; otherwise a bounce-out (0).
- **Verify (Nigel):** tape a pen to the printout (stick), or wave without leaving anything (bounce-out); the app labels each correctly.

### Task 4: Entry point (D1)
- **Work:** `EntryPointEstimator` (option A); measure the error on the renders' known entry points; show a dot where the blade went in.
- **Verify (Nigel):** the dot sits where the pen or knife meets the paper/board.

### Task 5: Score, session and round
- **Work:** entry point → `TargetMapping` → score; a play screen with throw list and total; the new frame becomes the reference; retrieval resets the round.
- **Verify (Nigel):** three "throws" (taped pens) give the right scores and total; removing them starts a new round.

### Task 6: Traceability review and close

---

## Task Records

### Task 1: Test sequences — COMPLETE
- **Knife details from Nigel (during the task):** blade ~10 cm, handle ~10 cm; then a photo: **all-steel throwing knives** with see-through holes in the handle. The renderer's knife was changed from "steel blade + dark handle, 12 + 13 cm" to match (Design Decisions → The Knives).
- **What changed** (unstaged):
  - `lib/vision/synthetic_scene.dart`:
    - `FlyingKnife` (a whole knife at any pose: in flight, bouncing, lying) and `Person` (legs, torso, head boxes).
    - The steel knife: tapered blade profile, handle holes (`_Box.widthProfile` / `holes`; rays outside the profile or through a hole miss), steel shading.
    - Public `embeddedLength` / `bladeLength` / `handleLength` / `groundY`.
  - `tool/reference_board.dart` (new; shared by the render tools: reference board texture, painted rings, camera, board size, `saveJpg`); `tool/render_camera_views.dart` now uses it (output unchanged).
  - `tool/render_throw_sequences.dart` (new):
    - 15 fps, 640 × 360 (half the 1280 × 720 stream), 1/60 s motion blur (4 samples), sensor noise σ 2.5.
    - Release point 4 m out; 0.45 s flight with a ballistic sag and one spin; 9 Hz handle wobble decaying over ~0.3 s.
    - Full-resolution `before.jpg` / `after.jpg`, `preview.gif`, `truth.json` (per-frame phase + event answer).
  - Output in `docs/thrower/reference/sequences/`:

    | Sequence | Frames | Phases | Answer |
    |---|---|---|---|
    | `throw-stick-ring4` | 30 | 10 settled, 11 motion, 9 settled | stick, entry (0.18, 0.27), score 4 |
    | `throw-stick-ring3` | 30 | same | stick (knife 1 already in), entry (−0.45, −0.38), score 3 |
    | `throw-bounce-out` | 39 | 10 settled, 18 motion, 11 settled | bounce-out at (0.05, −0.12), 0 |
    | `retrieve-knives` | 90 | 6 settled, 79 person, 5 settled | retrieval, 2 knives removed |
- **Findings:**
  - From the camera's position (2 m, 45°), a knife thrown from 4 m is **in view for only its last ~1.2 m: one or two frames, motion-blurred**. Detection has to work from the impact, the handle's wobble and settling, not from tracking the flight.
  - The bounced knife **falls below the frame**: from a camera at board height the ground in front of the board isn't visible. (The plan had it as a "new object outside the target" trap; corrected in the answer file and tool.)
  - The approaching thrower is close to the camera, so they cover much of the frame (a big, slow occlusion), unlike a throw (small, fast).
  - About **21 MB** of frames; see the question about git below.
- **Tests:** `synthetic_scene_test.dart` still passes. The camera-view renders and fixtures are being re-rendered with the steel knives, so the end-to-end tests run on them.
- **Verify (Nigel):** watch `preview.gif` in each folder under `docs/thrower/reference/sequences/`; do they read like real throws and a retrieval?
- **Nigel:** "don't commit the sequences, commit this and continue". `docs/thrower/reference/sequences/` git-ignored; committed `2e9223b`.
- **Checkpoint saved:** 2026-10-08

### Task 2: Motion and settle — COMPLETE
- **What changed** (unstaged):
  - `lib/vision/luma_image.dart`: `LumaImage`, `frameToLuma` (Y plane / BGRA → brightness, upright, ~320 px).
  - `lib/vision/motion_detector.dart`: `WatchRegion.fromCalibration`, `MotionDetector` (watching / motion / settling / **blocked**), `MotionEpisode` (peak change, change from before, accepted-new-scene flag).
  - `lib/ui/watch_status.dart`: `WatchStatus` (listens to frames while locked, at most every 60 ms) + `watchStatusText`; shown on the calibration screen once locked.
  - `test/fixtures/sequences/` (1.9 MB: the 4 sequences as 320 × 180 greyscale, a 640 × 360 `before.jpg`, trimmed `truth.json`).
- **Found while testing:**
  1. A person **standing still** at the board was reported as "settled" (3 episodes for one retrieval). Fixed with the reference-frame check and the **blocked** state: now 1 episode (frames 26–68).
  2. The answers' phases describe the whole scene, not what's visible in the watched region (the bounced knife falls out of view; the thrower leaves the region before reaching the line). The tests were adjusted per event type (documented in the test).
- **Results on the renders:**

  | Sequence | Episode | Peak | Changed from before |
  |---|---|---|---|
  | stick ring 4 | 16–26 | 0.6% | 0.7% |
  | stick ring 3 | 16–22 | 0.6% | 0.6% |
  | bounce-out | 16–27 | 1.5% | 0.0% |
  | retrieval | 26–68 (blocked while at the board) | 25.0% | 1.2% |

  Episodes start at the impact (frame 16), not during the one faint flight frame.
- **Test Report:** new `motion_detector_test.dart` (7), `luma_image_test.dart` (5), `calibration_editor_test.dart` +2 (`watchStatusText`). **156 passed**; analyze clean.
- **Safety:** watching only displays state; nothing tells anyone to approach the board. ✅
- **Verify (Nigel):** A4 printout → Calibrate → Find → **Lock** → under the picture: "Board still: watching". Wave a hand in front of the printout: **Motion → Settling… → watching**, with a "Last: …" line. Hold a hand still in front of it: **"Something is in front of the board"** until you move it away. Tape a pen on (a "stick"): the last line should show a small "changed from before".
- **Nigel:** "commit this and continue". Committed `93c6c27`.
- **Checkpoint saved:** 2026-10-08

### Task 3: Stuck or bounced off — COMPLETE
- **What changed** (unstaged):
  - `lib/vision/motion_detector.dart`: `MotionEpisode` now carries `before` / `after` frames, the `threshold` in use, and `wasBlocked`.
  - `lib/vision/throw_classifier.dart` (new): `classifyThrow`, `findNewObject` (connected new shapes near the target), `ThrowOutcome` / `ThrowOutcomeKind` (stuck, bounceOut, boardVisit, sceneChanged), `NewObject`.
  - `lib/ui/watch_status.dart`: classifies each finished episode and says what it was ("Stuck in the board" / "Bounced off (0)" / "Someone was at the board" / "The view changed: re-calibrate?").
  - `test/vision/motion_detector_test.dart`: the fixture keeps its calibration.
- **Results:** stick ring 4 → stuck (84 px shape); stick ring 3 → stuck (68 px); bounce-out → bounce-out (0 px); retrieval → board visit. Minimum for a stick: 12 px.
- **Test Report:** new `throw_classifier_test.dart` (9); `calibration_editor_test.dart` +1. **166 passed**; analyze clean.
- **Known limitation:** a knife falling out on its own would be read as stuck (see Design Decisions). Planned for Task 5.
- **Verify (Nigel):** locked A4 target: **tape a pen on** at an angle → "Stuck in the board"; **wave a hand** past without leaving anything → "Bounced off (0)"; **stand/hold a hand** in front for a couple of seconds, then take the pen off → "Someone was at the board".
- **Nigel:** "commit this and continue". Committed `e51d7da`.
- **Checkpoint saved:** 2026-10-08

### Task 4: Entry point — COMPLETE
- **What changed** (unstaged):
  - `lib/vision/entry_point.dart` (new): `EntryPointEstimator`, `GeometricEntryEstimator`, `EntryEstimate`, `outwardDirection`.
  - `lib/ui/watch_status.dart`: keeps a full-resolution upright "before" while still (every 1 s, `compute`); on **stuck**, takes the next frame as "after" and finds the entry in the background (`uprightFullRgb`, `findKnifeEntry`); `onKnifeEntry` callback; the after becomes the next before.
  - `lib/ui/calibration_screen.dart`: a detected knife's entry → yellow dot + "Knife went in at the yellow dot: scores N" (`lockedStatus(..., knife:)`).
  - `test/fixtures/entry/` (full-resolution before/after of both stick sequences, 4 × ~167 KB) + `cases.json` (6 cases incl. the camera-view pairs already in fixtures).
- **Found while testing:** the first version compared **brightness** and missed the ring-3 knife's shaded blade (same brightness as the red paint): 6.4 px off, scored 2 instead of 3. Switched to **colour** difference: 2.1 px, scores 3.
- **Results:** ring4 seq 2.7 px (1.7%), ring3 seq 2.1 px (1.3%), 1× 1-knife 2.4 px (1.2%), 1× 2-knives 1.8 px (0.9%), 2× 1-knife 3.0 px (0.8%), 2× 2-knives 2.7 px (0.7%). **All 6 scores correct.**
- **Test Report:** new `entry_point_test.dart` (7); `calibration_editor_test.dart` +1. **174 passed**; analyze clean.
- **Verify (Nigel):** locked A4 target. **Stand a grey or silver pen/pencil out of the paper** at an angle (push it into a lump of Blu Tack on the printout, so it sticks out ~10 cm like a knife). After it settles: "Stuck in the board", a **yellow dot where it meets the paper**, and its score. (A pen taped flat, or a coloured one, won't find the right end; see Design Decisions.)
- **Nigel:** "commit this and continue". Committed `f0e4bd2`.
- **Checkpoint saved:** 2026-10-08

### Task 5: Score, session and round — COMPLETE
- **What changed** (unstaged):
  - `lib/scoring/game_session.dart` (new): `GameSession`, `RoundRecord`, `ThrowRecord`, `ThrowResult`.
  - `lib/vision/throw_classifier.dart`: `fellOut` outcome via `knownKnives` (≥ 50% overlap with a known knife).
  - `lib/game/throw_tracker.dart` (new, pure): classification + knives in the board.
  - `lib/game/throw_watcher.dart` (new): camera → detector → tracker → full-resolution entry, emitting `ThrowEvent`s; the capture logic moved here from `WatchStatus`.
  - `lib/ui/watch_status.dart`: now a thin view over `ThrowWatcher`.
  - `lib/providers.dart`: `GameNotifier` / `gameProvider`.
  - `lib/ui/play_screen.dart` (new): **Play** (live picture, locked rings, numbered dots, round and game totals, New game; asks to calibrate first if not locked).
  - Home: **Play** button at the top.
- **Test Report:**
  - New: `game_session_test.dart` (8), `game_notifier_test.dart` (11: scoring, unscored, fell out → 0, board visit closes, play-screen text), `play_through_test.dart` (1: **the four sequences back to back through the real detector, tracker, entry finder and game → stuck, stuck, bounce-out, board visit; Round 1 = 4 · 3 · 0 = 7; knives forgotten**).
  - `throw_classifier_test.dart`: +3 (a known knife disappearing is "fell out"; without tracking it would look like a stick; a new knife elsewhere is still a stick).
  - **197 passed**; analyze clean.
- **Assumed rule (to confirm):** a knife that sticks then falls out scores 0.
- **Verify (Nigel):** Home → **Play** (target locked). Three "throws" with a grey pen in Blu Tack (move it to a new spot each time, or use three pens), one wave-past (bounce-out) → "Round 1: …" with the right scores and numbered dots. Then stand in front and remove the pens → the round closes; the next "throw" starts Round 2.
- **Nigel:** "commit this and continue". Committed `e792eb4`. The fall-out rule (0) wasn't confirmed or changed: it stays an assumption in the backlog.
- **Checkpoint saved:** 2026-10-08

### Task 6: Traceability review and close — COMPLETE
- **Traceability Report:**
  - Requirements: 7 (T-R0 – T-R6), all covered by design + code + tests on rendered data.
  - **Device verification:** each task was approved with "commit this and continue"; no device results were reported for Tasks 2–5, so device behaviour (Android with the A4 printout; iOS not at all) is **unconfirmed** → [[backlog]].
  - **Gaps fixed:**
    1. **Untraced:** the sequence renderer and tools (Task 1) → **T-R0**.
    2. **Orphan code:** `EntryEstimate.handleEnd` (computed, never used) **removed**, with its unused 98th-percentile end; doc comment updated.
    3. The T-R2 warning (fall-out) is closed by T-R5.
  - **Orphans remaining:** `NewObject.centroid` is used only in a test's failure message (kept: diagnostic).
  - **Constants checked** (all documented in code or Design Decisions): motion 0.2% / 0.08% / 0.3 s / 8% blocked / 5 s new scene; visit 10%; knife ≥ 0.25% of the target area; fall-out 50% overlap; entry colour threshold 20, steel saturation 0.3; watcher 60 ms / before every 1 s.
- **Doc Update Log:**
  - `Data Flow.md`: "A Throw → a Score" sequence; brightness-frame coordinate space.
  - `Glossary.md`: 6 components (`ThrowWatcher`, `MotionDetector`, `ThrowTracker`, `classifyThrow`, `GeometricEntryEstimator`, `GameSession`/`GameNotifier`), 7 concepts (episode, reference/blocked, noise-adaptive threshold, known knives, colour vs brightness, steel vs shadow, outward direction).
  - `System Diagram.md`: game layer (Task 5).
  - `stories/backlog.md`: story 2 done; carry-overs; next-story choice.
  - Moved: this file to `stories/archive/`.
- **Verified by:** `flutter test` 197 passed; `flutter analyze` clean.
- **Checkpoint saved:** 2026-10-08

## Plan Changes Log

- **2026-10-08:** Task 5 committed (`e792eb4`). Task 6 executed; story closed and archived.

- **2026-10-08:** Story drafted.
- **2026-10-08:** Nigel approved the plan: knives first, 3 throws per round, throwing from 4 m, D1 = A.
