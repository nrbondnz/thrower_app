# Story Checkpoint: Quick Draw

## Story Goal
Two throwers, one board each, both in one camera view. After a countdown they throw at the same moment. The app finds which knife reaches its board first, and whether each one sticks, plus its score. Nigel, 2026-10-14: *"two throwers given a count down and throwing at the same time. The app measures who gets to the board first, and their scores, bounce out means a loss."* The first version is a Live test on Nigel's original video (158.5–166 s), played full screen.

## Complexity Score
6 (Large): crosses camera → vision → game → UI (4), conditional branches (stick / bounce / false start / tie) (1), more than 3 acceptance criteria (1). Audio playback may add a plugin (+1).

## Status
IN PROGRESS: Tasks 1–3 complete; Task 4 built, waiting for Nigel's device check (2026-10-15). iPhone: ~42 frames a second (2026-10-15). Plan approved 2026-10-14; "go" at 161.3 s (Nigel, by ear).

## Decisions (Nigel, 2026-10-14)
- **Winner:** the first knife to **stick** wins. A bounce-out loses. If both stick, the faster one wins; ring scores are shown but don't decide it. If both bounce, there's no winner.
- **Recording:** the full frame, **720 × 1280, 60 fps** (boards ~163 px across), JPEG q20: **34.2 MB** (the grass compresses badly; see the Plan Changes Log).
- **Countdown, this story:** **follow the footage's audio** (Nigel, 2026-10-14, replacing "both"). The clip's own quiet countdown is heard; "go" is the answer key's go time (2.8 s). The app plays no countdown of its own on the Live test.
- **Countdown, final version (live camera):** the app counts down itself, **like Formula 1**: 5 beeps, then a **random pause**, then a final **longer beep for go** (Nigel, 2026-10-14). The random pause stops throwers anticipating "go". Not in this story: backlog #9.
- **Order:** before [[story-checkpoint-entry-point]] (paused while waiting for new footage). This clip's two results (a clear 5 and a bounce-out) don't depend on the shadow problem.

## The Footage (`IMG_1628.mov`, 158–166 s; measured by Claude, 2026-10-14)
- **Countdown:** quiet voice at 160.0–160.2 s and 160.6–161.4 s, then silence. **"Go" is at 161.3 s** (Nigel, by ear): 2.8 s into the clip.
- **Board 2** (right, green/red): the knife arrives at about **162.12 s** (60 fps frames) and sticks: **5** (`b2-t10` in `truth.json`).
- **Board 1** (left, red): the knife arrives at about **162.15 s**, hits the bull and slides off: **bounce-out** (`b1-t13`).
- **Sound:** one sharp onset at 162.132 s (Mark's knife); the Captain's impact can't be picked out of the ~70 ms rattle that follows (corrected 2026-10-15, as the Mac session found on 2026-10-14: "two thuds 37 ms apart" was an artefact of reading peaks in that rattle). So the margin, **2 frames (about 33 ms)**, rests on the video.
- **Result:** board 2 wins (first, and stuck).
- The throwers are out of shot until they walk up at ~164 s.

**Timing resolution:** 33 ms is 2 frames at 60 fps, but under one frame at 15 fps (67 ms). So at the current 15 fps this race could come out as a tie or the wrong way. Hence 60 fps. The sound separates impacts to ~5 ms but can't say which board; it could refine timing later (not in this story).

## Acceptance Criteria
1. **Live test → Quick draw** plays the clip full screen, with its audio.
2. The user taps the centre of Player 1's board, then Player 2's (there may be more boards in shot); each is found and outlined, then locked, and each is scored separately.
3. "Go" is the footage's own (2.8 s into the clip, from the answer key); times are measured from it.
4. On the clip: board 2 is first and sticks (5), board 1 bounces out, so **board 2 wins**. Impact times are within 1 frame (17 ms) of the answer key.
5. A knife that reaches its board before "go" is a false start (a loss).
6. A results screen shows each board's time after "go", stuck/bounce, score and the winner.
7. The existing Live test (Target 1 / Target 2) and its replay tests are unchanged.

---

## Task 1: The clip, answer key, and full-screen playback
- **Status:** BUILT, waiting for Nigel's device check (2026-10-14)
- **What changed:** `assets/live/quickdraw.tfrm` (449 frames, 720 × 1280, 60 fps, q20) and `quickdraw.m4a`; `audioplayers` ^6.8.1; `RecordingSound` / `AssetRecordingSound` (`lib/camera/recording_sound.dart`); `Recording.audio`, `RecordedCamera.sound`, `quickDrawRecording`; `quickDrawCameraProvider`; `QuickDrawScreen`; Live test → Quick draw. Answer key `reference/live-camera/quickdraw.json`: go 2.8 s; right board frame 217 (3.617 s) stuck 5; left frame 219 (3.650 s) bounce-out; right wins.
- **Test Report (2026-10-14):** `flutter analyze` clean; `flutter test` 332 passed, 0 failed. New: `recorded_camera_test.dart` → sound track (silent until play, plays on each restart, stops on rewind, released with the camera, a failing sound leaves frames playing); `frame_pack_test.dart` → Quick draw clip (720 × 1280, 60 fps, 449 frames, first frame decodes) and its sound bundled; `quick_draw_screen_test.dart` (opens full screen with the bars hidden, Play starts clip and sound and comes back as "Play again", leaving restores the bars).
- **Safety Report (2026-10-14): OK for development; NOT OK for a store build.**
  - ✅ No new permissions (audioplayers' Android manifest is empty; no Info.plist key; `http` is web-only). minSdk / iOS 15 fine. `kDebugMode` on the frame-rate label. Commit `ios/Podfile.lock` after the next iOS build.
  - ✅ **Audio context:** Nigel chose **duck others** (2026-10-14): `AssetRecordingSound.audioContext`. Still plays with the silent switch on.
  - ⚠️ App size: `assets/live/` is now ~87 MB (backlog #6).
  - ⚠️ Privacy: this clip is the **full frame with people walking up, and has sound (voices)**: consent, blur/strip, or keep it out of release (backlog #6).
  - ⚠️ Physical safety, for the Task 4 instructions and UI: experienced throwers and venue rules only; separate side-by-side lanes; "go" never means the lane is clear; nobody goes forward until both have finished; the phone out of both lines of throw and not between the lanes (behind the throwers is fine); a bounce-out loses (don't throw harder); no re-throw after a false start until retrieved; the countdown must be audible; results readable without walking up to the phone.
- **Work:**
  - Cut 158.5–166 s from the original: full frame, 720 × 1280, 60 fps; pack it as `assets/live/quickdraw.tfrm`, and its audio as a separate asset.
  - `quickdraw.json`: go time, and for each board: impact time, stuck or bounce, score.
  - **Live test → Quick draw** plays it full screen with sound. Playing audio needs an audio plugin (a `pubspec.yaml` native plugin): **"Be Careful" Review Agent first**.
- **Verify:** Nigel opens Live test → Quick draw on his phone, sees the whole picture full screen and hears the countdown and the knives hitting.
- **Save:** pack test (size, 60 fps, frame count).
- **Doc Update Log (2026-10-14):**
  - `Architecture/Design Decisions.md`: camera layer row (`RecordingSound`, `AssetRecordingSound`); Live Test section: the Quick draw clip (full frame, 60 fps, q20, 34.2 MB and why), sound (`Recording.audio`, `RecordedCamera.sound`, `audioplayers`, failures don't stop frames), `quickDrawCameraProvider`, `QuickDrawScreen`.
  - `Architecture/Glossary.md`: `RecordedCamera` (with `RecordingSound`) and `QuickDrawScreen` in the component tree; concept **Quick draw**.
  - `reference/live-camera/README.md`: the Quick draw clip, and an Answer Key section for `quickdraw.json`.
  - `Operations/Common Tasks.md` → Make a Live Test Recording: the full-frame, 60 fps, with-sound variant (the three commands).
  - In-app Instructions (`lib/ui/instructions.dart`): no change; they don't mention the Live test. Quick draw instructions are Task 4.

## Task 2: Choose both boards by tapping them
- **Status:** COMPLETE (2026-10-15): Nigel, on the phone: "It finds the boards".
- **Depends on:** Task 1
- **Work (as built):** on Quick draw, tap the centre of Player 1's board, then Player 2's; each tap is searched (`locateTargetAt`) and the board outlined with its player number; **Lock boards**, or **Start again** (which also rewinds the clip). Taps are ignored while the clip plays. No drag-to-adjust yet: a wrong outline → Start again.
  - `locateTargetAt` (`lib/vision/tapped_target_locator.dart`): a square window (0.45 × the picture's shorter side) around the tap, **enlarged 3×**, with the tap tried first as the centre (`ColourRingLocator.seed`) and then the centres of the colour regions under and around the tap (the bull, or the ring tapped, is centred on the board). `locateTappedInFrame` runs it in a background isolate.
  - `QuickDrawTargets` / `quickDrawTargetsProvider` (tap order, two players, lock), `tapLocatorProvider`, `boardAt` (`lib/game/quick_draw_targets.dart`); `QuickDrawScreen` (instruction line, `BoardsPainter`, Start again / Lock boards / Play).
- **Measured on the clip's 16 still frames (taps at the measured centres, 2026-10-14):**
  | Approach | Player 1 (red on wood) | Player 2 (green and red) |
  |---|---|---|
  | Whole picture, then search beside the first board (dropped) | 16 of 16 in a window; the whole-picture pass failed on 3 of 8 frames | 8 of 16, 1 wrong ring |
  | Window at the tap, 1.3× (the finder's usual) | 15 | 10 |
  | Window at the tap, **3×** | **16** | **15–16** |
  | 3×, tap 10 px off centre, with snapping to the region under the tap | 16 | 15 |
  | 3×, tap 15–30 px off centre | 15–16 | 10–12 |
  About 1–1.5 s per board on the PC. The cause of the misses isn't resolution or compression: the right board fails as often on the uncompressed original at full size.
- **Verify:** Nigel opens Quick draw, taps the left board's centre (outlined, "1"), then the right's ("2"), and locks them. A tap that misses says so; Start again clears.
- **Test Report (2026-10-14):** `flutter analyze` clean; `flutter test` 355 passed, 0 failed (Live test replay unchanged). New `tapped_target_locator_test.dart` (each board found where measured on frames 0, 30, 60, 90, 120, 150; a tap 10 px off; a tap on the grass finds nothing; a camera frame's taps in tap order), `quick_draw_targets_test.dart` (`boardAt`; tap order, two players, lock needs both, start again), `quick_draw_screen_test.dart` (asks for Player 1 then 2 and passes taps in image pixels; a miss says so; taps stop and Lock once both are found; Start again clears and rewinds; no taps while playing). Sound: `recording_sound_test.dart` (ducks on Android and iOS; plays with the silent switch on).
- **Doc Update Log (2026-10-14):**
  - `Architecture/Design Decisions.md`: new section **Quick Draw: Choosing the Boards by Tapping** (why tapping, not automatic; window 0.45×, enlarged 3×, seed then region snapping; the measurements table; `QuickDrawTargets` and its providers; the screen and Start again's rewind); Live Test → Sound: the audio context (duck others, silent switch ignored); `QuickDrawScreen` bullet; code layout rows for vision (`locateTargetAt`, `locateTappedInFrame`) and game (`QuickDrawTargets`).
  - `Architecture/Glossary.md`: `QuickDrawScreen` (tap flow, `BoardsPainter`), `QuickDrawTargets`, `locateTappedInFrame` / `locateTargetAt`, `ColourRingLocator` candidate centres (`seed`, `_regionCentresNear`), `CoarseToFineLocator.moved`, `AssetRecordingSound.audioContext`; concepts **Seed (tap) centre** and **Ducking**; Quick draw concept updated.
  - `Architecture/System Diagram.md`: `BoardsPainter` (UI), `quickDrawTargetsProvider` / `tapLocatorProvider` (wiring), `QuickDrawTargets` (game), `locateTappedInFrame` → `locateTargetAt` (vision), "tap boards 1, 2 → lock" and the still-to-come line (Tasks 3–4).
  - `Architecture/Data Flow.md`: new box diagram **Quick Draw: Choosing the Boards**, replacing the "will add its own flow" sentence.
  - `Troubleshooting/Known Issues.md`: **Quick Draw: a Board Isn't Found, or the Wrong Outline** (tap the bull; Start again).
  - In-app Instructions (`lib/ui/instructions.dart`): no change; they don't mention the Live test or Quick draw. Quick draw instructions are Task 4.
  - Drift (fixed 2026-10-15): the Notes size and `locateTargetAt`'s doc comment now match the table.

## Task 3: Impact time and result per board
- **Status:** COMPLETE (2026-10-15). Nigel, on the Samsung SM-A065F: "it shows the scores and the times". Playback ran at **11–12 frames a second** there (not 60), and a couple of runs gave both players the same time: at that rate the two knives (2 frames, about 33 ms apart) can land in one delivered frame. Nigel: both throwers are professionals, so a draw at that frame rate is no surprise; the Target 2 thrower always draws or wins on time, as analysed. He'll check on his iPhone, expecting a clearer difference at a higher frame rate. **iPhone (2026-10-15, debug build from Xcode, on the Mac):** about **42 frames a second**, and "quite often" both players still got the same time. Fix chosen for Task 4 (Plan Changes Log).
- **Depends on:** Task 2
- **Work (as built):**
  - `CroppedCamera` (`lib/camera/cropped_camera.dart`): a part of another camera's picture as a camera of its own, frames as views into the source's bytes (BGRA and YUV; upright sources only). `TargetCalibration.within` moves a board's rings into its crop.
  - `QuickDrawWatcher` (`lib/game/quick_draw_watcher.dart`): per board, a crop 4 × the board's radius around it and the single-board `ThrowWatcher` on it, looking at **every** frame (`ThrowWatcher.interval`, new, default 60 ms; zero here). Keeps each player's first throw (`QuickDrawThrow`: impact, stuck or not, score).
  - **Impact = `MotionEpisode.impact`** (new): the frame with the largest moving shape on the target. Not the episode's start: seen from behind the thrower, a knife in flight is over the board all the way in. On the clip, motion started 1 and 7 frames before the answer key's impact frames, the first shape on the target 1 and 5 before; the largest was on them.
  - **`classifyThrow` visitArea 2% → 3%:** the right board's knife, flying in close to the camera, moved a shape of 2.2% of the region and was taken for a person (people are 4%+; knives on the Target 1/2 recordings at most 1.1%).
  - `RecordedCamera.playbackTime`: a frame's time on the recording's own timeline.
  - Quick draw screen: Play with the boards locked starts a fresh watcher; each board shows "3.62 s · 5" or "3.65 s · bounced" under it.
- **Verify:** Nigel locks both boards and presses Play: under the right board "3.6x s · 5", under the left "3.6x s · bounced" (left about 0.03 s later).
- **Test Report (2026-10-15):** `flutter analyze` clean; `flutter test` 373 passed, 0 failed (Target 1/2 replays unchanged with visitArea 3%). New: `quick_draw_replay_test.dart`, `cropped_camera_test.dart`, `motion_detector_test.dart` → impact, `target_calibration_test.dart` → within, `quick_draw_screen_test.dart` → the line under each board.
- **Save:** `quick_draw_replay_test.dart` (the clip through `RecordedCamera` → `QuickDrawWatcher`, boards tapped at their centres): Player 1 bounce-out, Player 2 stuck 5, each impact within a frame of the answer key, Player 2 first. Watch on the Samsung whether 60 fps playback keeps up (skipped frames make timing coarser).
- **Doc Update Log (2026-10-15):**
  - `Architecture/Design Decisions.md`: new section **Quick Draw: Timing and Scoring Each Board** (crop 4 × radius + single-board `ThrowWatcher` at every frame; impact = largest on-target moving shape, with the 1/7 and 1/5 frame evidence; `visitArea` 2% → 3% and why; `throwText` / `playbackTime`; the replay test). Visit threshold updated in Stuck or Bounced Off (now `peakArea` ≥ 3%) and Throw Detection on Real Footage (People are judged by area). Motion and Settle: `ThrowWatcher.interval` (was "`WatchStatus` ... 60 ms"), and "episodes start at the impact" qualified for Quick draw. `QuickDrawScreen` bullet: times and results shown, no winner yet. Code layout: `CroppedCamera`, `RecordedCamera.playbackTime` (camera); `QuickDrawWatcher` / `QuickDrawThrow` (game).
  - `Architecture/Glossary.md`: `CroppedCamera` (`crop`), `RecordedCamera.playbackTime`, `QuickDrawWatcher` / `QuickDrawThrow`, `TargetCalibration.within`, `ThrowWatcher.interval`, `MotionEpisode.impact` / `impactFrame`, `classifyThrow`'s visit rule, `QuickDrawScreen` (Play starts a watcher, `throwText`, `BoardsPainter.results`); concepts **Impact (frame)**, **Board crop**, **Board visit** (3%); Quick draw concept updated.
  - `Architecture/System Diagram.md`: `CroppedCamera` (camera), `QuickDrawWatcher` → `ThrowWatcher` × 2 (game); Play flow "Quick draw: all" frames; Quick draw box "Play → QuickDrawWatcher: time · score per board"; still-to-come line (Task 3 done; go, false start, winner in Task 4). All lines 71 wide.
  - `Architecture/Data Flow.md`: new box diagram **Quick Draw: a Throw per Board**; the "will be added" note now covers Task 4 only; Coordinate Spaces row **Board crop**.
  - `Troubleshooting/Known Issues.md`: **Quick Draw: Dropped Frames Make Times Coarser**.
  - In-app Instructions (`lib/ui/instructions.dart`): no change; they don't mention the Live test or Quick draw. Quick draw instructions are Task 4.
  - Drift: Design Decisions → Throw Detection: Before/After and Motion and Settle still describe `peakShape` as the person test in places written before 2026-10-12 (left as history); `RecordedCamera`'s class doc comment has one over-long line (source, not docs).

## Task 4: The Quick draw game
- **Status:** BUILT, waiting for Nigel's device check (2026-10-15)
- **What changed:**
  - `RecordingAnalysisFeed` (`lib/camera/recording_analysis_feed.dart`): every frame of the recording, decoded again in order, never ahead of the picture, each stamped with its **place in the clip** (frame ÷ 60); decodes only while listened to; starts over when playback restarts. `QuickDrawWatcher` now watches this feed, not the picture's frames. The screen and sound keep their own pace; the result may come late.
  - `Recording.go` (`quickDrawRecording`: 2.8 s). `judgeQuickDraw` (`lib/game/quick_draw_judge.dart`): per player `none` / `falseStart` (impact before go) / `bounced` / `stuck`, time after go; the first knife to stick wins; same frame = draw; none stuck = no winner. `judgedText`, `verdictText`.
  - Screen: **GO!** for 0.7 s at go; the line under each board is the time **after go** ("0.82 s · 5", "0.85 s · bounced", "false start"); the bottom line says "Watching…", "Analysing… 0.4 s behind the picture." while analysis catches up, then the verdict, e.g. "Player 2 wins: stuck 5, 0.82 s after go. Player 1 bounced out."
  - `RecordedCamera.playbackTime` removed (clip time no longer shown).
  - **Analysis starts 1 s before go** (Nigel, 2026-10-15: "it will be super obvious if they go earlier than that"): `RecordingAnalysisFeed(from:)`, `quickDrawLeadIn`; frame 108 of the clip. Tests: the feed never analyses frames before `from`, waits for the picture to reach it, and restarts from it; the replays (all frames, and skipping 2 of 3) start there too, as the app does.
- **Test Report (2026-10-15):** `flutter analyze` clean; `flutter test` 397 passed, 0 failed. New: `recording_analysis_feed_test.dart` (every frame up to the one shown, in order, when the picture skipped them; stamped by place in the clip; never ahead of the picture; starts over on replay; no decoding without a listener), `quick_draw_judge_test.dart` (11 rule cases: faster stuck wins, same frame draws, a bounce or false start loses, none stuck no winner, a knife exactly at go counts; times after go; the result line), `quick_draw_replay_test.dart` (through the feed; the verdict: Player 2 wins, ~0.82 s after go; **playback skipping 2 of every 3 frames gives the same impact frames**), `quick_draw_screen_test.dart` (GO! at go only; lines after go; the bottom line from "Watching…" to the verdict).
- **Depends on:** Task 3
- **Work, first (Nigel, 2026-10-15): analyse every frame, report late.** Playback stays as it is (it may skip frames to keep up with the sound), but **analysis must see every one of the clip's frames, in order**, and time each by its **place in the clip** (frame number ÷ 60), not by when it arrived. Results may appear late: Nigel, "analysis can come back with the actual result 1/2 second later". Points for the design:
  - Today one decoded frame feeds both the preview and the watchers, and `RecordedCamera` skips to the newest when decoding falls behind (`_show` / `_wanted`), so the watchers never see the skipped frames. The analysis needs its own in-order path (a queue of frame indices), separate from what's on screen.
  - Lag: if the phone analyses ~42 frames a second, analysis falls behind by ~0.4 s per second of clip, about **1.5 s** by the throws at 3.6 s (less in a release build). If that's too slow, only the frames that matter need full analysis, or decode only the two board crops (the colour swap, `rgbaToBgra`, runs over the whole 720 × 1280 frame on the UI thread today).
  - Timing by clip position also removes decode jitter from the times (`_deliver` stamps frames with `_now()`).
  - Tests: the replay test already delivers every frame; add one where playback skips frames and the result is still the answer key's times.
- **Work:** "go" from the answer key (the footage's audio gives the countdown; shown on screen as a "Go" marker at 2.8 s); false start if an impact comes before go; the winner rule (Decisions above); results screen.
- **Times shown from "go", not from the clip's start** (Nigel, iPhone, 2026-10-15: "the timer start is wrong ... they took about 1.2 seconds to strike the board and this says 3.69"). Task 3's line under each board is the time **into the clip** (`throwText` → `playbackTime`), which starts 2.8 s before "go". Task 4 must show the time **after go** (about 0.85–0.9 s here) under each board and in the results, so no clip time is left on screen. The 1.2 s came from the Mac's early guess at "go" (a speech burst at 160.9–161.4 s, backlog → Duel Test Case); Nigel's by-ear "go" at 161.3 s gives about 0.85 s.
- **Verify:** Nigel plays Quick draw: "Go" shows as he hears it in the footage, and the result says board 2 wins (5, stuck, ~0.8 s after go) and board 1 bounced.
- **Save:** unit tests for the winner rule (both stick, one bounces, both bounce, false start, a tie on the same frame).
- **Doc Update Log (2026-10-15):**
  - `Architecture/Design Decisions.md`: two new sections, **Quick Draw: Analysing Every Frame, Reporting Late** (Nigel's decision and quote; why: skipped frames, iPhone ~42 and Samsung 11–12 of 60, arrival-time jitter; `RecordingAnalysisFeed`: own decode, in order, never ahead of the picture, `timeOf`, `analysed`, restarts with playback; the cost; the "Analysing… x s behind the picture." line; tests) and **Quick Draw: Go, False Starts and the Winner** (the rule; `Recording.go` 2.8 s; `judgeQuickDraw` / `JudgedThrow` / `QuickDrawVerdict`; times shown from go and why, `playbackTime` removed; GO! flash; `boardLines` / `judgedText` / `verdictText`; on the clip ~0.82 s; tests). Timing and Scoring Each Board: "Shown" now says the line is time after go since Task 4, the replay goes through the feed, "Not yet" replaced by the dropped-frames history, confirmed by Nigel's Samsung check. `QuickDrawScreen` bullet (no "No winner yet"). Code layout: camera row (`Recording.go`, `RecordingAnalysisFeed`; `playbackTime` removed), game row (`judgeQuickDraw`).
  - `Architecture/Glossary.md`: `RecordingAnalysisFeed` (`frames`, `timeOf`, `analysed`, `dispose`); `Recording.go` (replaces `playbackTime`); `judgeQuickDraw` → `QuickDrawVerdict`, `JudgedThrow`, `QuickDrawResult`, `judgedText`, `verdictText`; `QuickDrawScreen`: feed + watcher on Play, `boardLines` (replaces `throwText`), `_GoFlash`, `_progress`; `QuickDrawWatcher` on the feed. Concepts **False start**, **Time after go**, **Analysis feed / report late**; Quick draw concept updated.
  - `Architecture/System Diagram.md`: `RecordingAnalysisFeed` (camera), `judgeQuickDraw` (game); Quick draw box: GO!, feed → watcher → judge; still-to-come line (Task 4 built; Task 5 docs, traceability, in-app instructions). All diagram lines 71 wide (the Backend box 39, as before).
  - `Architecture/Data Flow.md`: the Quick draw box diagram is now **Quick Draw: a Throw per Board, and the Winner** (RecordedCamera → RecordingAnalysisFeed → CroppedCamera → ThrowWatcher → QuickDrawThrow → judgeQuickDraw(go) → board lines, bottom line, GO!), replacing `throwText` / `playbackTime` and the "will be added" note; a note under Frame Sources on the feed. All lines 71 wide.
  - `Troubleshooting/Known Issues.md` → Quick Draw: Dropped Frames Make Times Coarser: marked resolved by the analysis feed (the result may lag; "Analysing… x s behind the picture."); history kept; the replay test now covers skipped frames.
  - `reference/live-camera/README.md`: Answer Key: how the app uses it (go 2.8 s, times after go ~0.82 / 0.85 s, the replay test). It had no `throwText` / clip-time mention.
  - `stories/backlog.md` #9: Task 4 built, waiting for the device check; Task 5 next.
  - In-app Instructions (`lib/ui/instructions.dart`): no change now; they don't mention the Live test or Quick draw, and Quick draw only plays a recording. **Task 5** must add a Quick draw section with the Task 1 Safety Report points: experienced throwers and venue rules only; separate side-by-side lanes; "go" never means the lane is clear; nobody goes forward until both have finished; the phone out of both lines of throw and not between the lanes (behind the throwers is fine); a bounce-out loses (don't throw harder); no re-throw after a false start until retrieved; the countdown must be audible; results readable without walking up to the phone.
  - Drift (not fixed): `Operations/Mac Handoff.md` still says Task 4 is "not built yet" and that times on screen are clip time (a dated handover note; left as history). `quick_draw_screen.dart`: the `_line` function sits between `_BoardsOverlay`'s doc comment and the class, so that comment now documents `_line` (source, not docs).

## Task 5: Docs and traceability
- **Status:** NOT STARTED
- **Depends on:** Task 4
- **Work:** Design Decisions (Quick draw, two targets, 60 fps timing), Glossary (impact time, false start), the in-app Instructions, Known Issues; Traceability Agent over criteria 1–7.
- **Verify:** Nigel reads the summary.
- **Save:** story archived.

---

## Plan Changes Log

- **2026-10-15:** iPhone ran Quick draw at ~42 frames a second (debug) with frequent equal times. Nigel: leave the playback frame rate; analysis may come back late ("1/2 second later"). Task 4 now starts with in-order analysis of every frame, timed by clip position. The live-game timing questions (60 fps capture, capture timestamps) went to backlog #9; they're for the live version, not this story.

- **2026-10-14:** Task 2 changed from automatic to **tapping**: Nigel, "selecting the two targets by touching the camera is the way to go, there might actually be more than 2 targets in shot, so for this test assume the centre of the boards is selected in order, 1 then 2". The automatic search (find one board, then search beside it) found the right board on only 8 of 16 frames. Drag-to-adjust per board isn't in this task.
- **2026-10-14:** Sound: **duck others** (Nigel), so other apps' audio is turned down, not stopped; the silent switch is still ignored so the countdown is heard.
- **2026-10-14:** Countdown changed from "both" to **the footage's audio only** for this story; the app's own Formula 1-style countdown (5 beeps, random pause, long go beep) is for the final, live-camera version (backlog #9). Task 4 no longer plays a countdown.
- **2026-10-14:** Task 1: the clip is 34.2 MB at q20, not the planned 15–20 MB (full frames of grass compress badly: q12 53.1 MB, q31 23.0 MB but blocky). Nigel chose q20.
- **2026-10-14:** Plan approved by Nigel; "go" is at 161.3 s (2.8 s into the clip).
- **2026-10-14:** Plan drafted; Nigel's decisions on winner rule, recording size, countdown and order recorded above.

---

## Notes
- Size: the Live test recordings are already 51.8 MB; this adds 34.3 MB (the clip and its sound) (backlog #6, store-release hygiene).
- Real games (live camera) will need a phone that sees both boards, and 60 fps analysis on the device; this story proves it on the recording first.
