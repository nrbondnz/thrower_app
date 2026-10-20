# Story Checkpoint: Quick Draw: Draw Round the Boards

## Story Goal
Mark (Nigel's brother), 2026-10-21: in Quick draw, "draw his finger round the board as a single hit point, not worrying about rings for scoring, just relying on hit time in the area he draws". Quick draw only. For build 9, before it goes to Mark.

## Complexity Score
3 (Medium): game logic (boards, throws, judge) → UI (drawing) → docs.

## Status
IN PROGRESS: plan approved 2026-10-21 ("yes, go ahead"); run whole, committing per task ([[dont-ask-again]]). Task 1 complete; Task 2 next.
(Paused 2026-10-21 ~10:05 for a Flutter SDK repair: the IDEs' Dart analysis servers held the SDK files; see [[Known Issues]]. Resumed the same day.)

## Plan
- **Task 1: area boards (logic, tested).** A finger-drawn loop → a board: the ellipse fitted to the loop (`areaBoard`), its rings the same ellipse scaled (0.2 … 0.8, needed by the entry-point code; never scored). Drawn boards are timed only: the result shows "1.52 s", no score; a same-frame finish is a drawn round (the judge already treats an unknown score as a draw), then an extra round if level. Any knife stuck in the board's watched region counts (as today).
- **Task 2: the screen.** Choose boards: **Tap the boards** (rings, as now) or **Draw round the boards**; drag a finger round board 1, then board 2 (the path follows the finger; the outline appears on lift); redraw, or Adjust boards, before locking. The choice remembered for the session. Quick draw screens only (live and the recording), not two-target Play (it needs scores). Instructions: a short section with the safety line (only touch the phone when no one is throwing).
- **Task 3:** docs, device checks, Traceability, an Android build.

---

## Task 1: Area boards (logic)
- **Status:** COMPLETE (2026-10-21)
- **What changed:**
  - `lib/game/area_board.dart` (new): `areaBoard(loop, imageWidth:, imageHeight:)` → `TargetCalibration?`: the ellipse fitted to the loop (`fitEllipse`), rings the same ellipse scaled 0.2 … 0.8. Null if under `minLoopPoints` (8), the smaller radius under `minAreaRadius` (3% of the picture's shorter side), the larger over the shorter side, or flatter than `minRoundness` (0.35).
  - `QuickDrawTargets.areas` (players whose board was drawn); `QuickDrawTargetsNotifier.add(board, {area})`, kept by `replace`, `unlock`, `lock`; `clear` forgets them.
  - `QuickDrawWatcher(areas:)` → `QuickDrawThrow.scored` false and no score for those players; both Quick draw screens pass `targets.areas`.
  - `JudgedThrow.scored`; `judgedText` shows only the time ("0.82 s"); `verdictText` "Player 2 wins: stuck, 0.82 s after go." and "A draw: both stuck on the same frame." A same-frame finish on drawn boards is a draw (no score to break it).
  - `uprightSizeOf(frame, maxSide:, rotation:)` in `lib/vision/frame_to_rgb.dart`, for Task 2.
- **Test Report:**
  - New `test/game/area_board_test.dart`: 9 (circle, oval, picture size and rings, wobbly loop; too few points, too small, too big, too flat, a straight line → null).
  - `quick_draw_targets_test.dart`: +4 (area by player; kept through replace/lock/unlock; a third board ignored; clear forgets).
  - `quick_draw_judge_test.dart`: +5 (faster wins, same frame a draw, the throw's text, the result line, the draw line).
  - `quick_draw_replay_test.dart`: +1, Mark's recording with both boards drawn (a loop just outside each outer ring): the same throws on the same frames, no scores, Player 2 still wins.
  - `flutter analyze`: no issues. `flutter test`: 894 passed.
- **Verified by:** tests (the screen comes in Task 2).

## Task 2: The screen
- **Status:** NOT STARTED
- **Notes for it:** `BoardChoosing` (`lib/ui/quick_draw_boards.dart`) and `BoardsOverlay` (taps as fractions of the picture); add a draw gesture (pan → points as fractions → × `uprightSizeOf` of the camera's next frame, `maxSide: 1920`, rotation `camera.uprightRotation` → `areaBoard` → `add(board, area: true)`). Live screen `lib/ui/live_quick_draw_screen.dart` (`findBoardAt` at ~line 209), recording screen `lib/ui/quick_draw_screen.dart` (~line 114). Not two-target Play (`two_target_play_screen.dart`).

## Task 3: Docs, device checks, traceability, a build
- **Status:** NOT STARTED

---

## Plan Changes Log
- (none yet)
