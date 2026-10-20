# Story Checkpoint: Quick Draw: Draw Round the Boards

## Story Goal
Mark (Nigel's brother), 2026-10-21: in Quick draw, "draw his finger round the board as a single hit point, not worrying about rings for scoring, just relying on hit time in the area he draws". Quick draw only. For build 9, before it goes to Mark.

## Complexity Score
3 (Medium): game logic (boards, throws, judge) → UI (drawing) → docs.

## Status
IN PROGRESS: plan approved 2026-10-21 ("yes, go ahead"); run whole, committing per task ([[dont-ask-again]]).
**Paused 2026-10-21 ~10:05:** the Flutter SDK on the PC needs to re-download its Dart SDK (`C:\dev\flutter\bin\cache\engine-dart-sdk.stamp` missing; "Unable to update Dart SDK … The process cannot access the file because it is being used by another process"). Android Studio and IntelliJ's Dart analysis servers hold the files. Nigel is closing the IDEs and restarting, then will ask to continue.

## Plan
- **Task 1: area boards (logic, tested).** A finger-drawn loop → a board: the ellipse fitted to the loop (`areaBoard`), its rings the same ellipse scaled (0.2 … 0.8, needed by the entry-point code; never scored). Drawn boards are timed only: the result shows "1.52 s", no score; a same-frame finish is a drawn round (the judge already treats an unknown score as a draw), then an extra round if level. Any knife stuck in the board's watched region counts (as today).
- **Task 2: the screen.** Choose boards: **Tap the boards** (rings, as now) or **Draw round the boards**; drag a finger round board 1, then board 2 (the path follows the finger; the outline appears on lift); redraw, or Adjust boards, before locking. The choice remembered for the session. Quick draw screens only (live and the recording), not two-target Play (it needs scores). Instructions: a short section with the safety line (only touch the phone when no one is throwing).
- **Task 3:** docs, device checks, Traceability, an Android build.

---

## Task 1: Area boards (logic)
- **Status:** IN PROGRESS: code written, **not yet analyzed or tested** (the SDK problem above), not committed.
- **Written (uncommitted):**
  - `lib/game/area_board.dart` (new): `areaBoard(loop, imageWidth:, imageHeight:)` → `TargetCalibration?` (`fitEllipse`; null if under `minLoopPoints` 8, radius under `minAreaRadius` 3% of the shorter side or over the shorter side, or flatter than `minRoundness` 0.35).
  - `lib/game/quick_draw_targets.dart`: `QuickDrawTargets.areas` (`Set<int>` of players whose board was drawn).
  - `lib/providers.dart`: `QuickDrawTargetsNotifier.add(board, {area})`; `replace`, `unlock`, `lock` keep `areas`.
  - `lib/game/quick_draw_watcher.dart`: `QuickDrawThrow.scored` (default true); `QuickDrawWatcher(areas:)`: no score for those players.
  - `lib/game/quick_draw_judge.dart`: `JudgedThrow.scored`; `judgedText` shows only the time for unscored; `verdictText` "stuck, 1.52 s after go" and "A draw: both stuck on the same frame." for unscored.
  - `lib/vision/frame_to_rgb.dart`: `uprightSizeOf(frame, maxSide:, rotation:)` (the picture size a drawn board's pixels are in; use `maxSide: 1920` as `locateTappedInFrame`).
  - The edit script: `C:\Users\nigel\AppData\Local\Temp\claude\…\scratchpad\area_edits.py` (already applied; don't rerun).
- **Next, when the SDK works:**
  1. `flutter --version` (re-downloads the Dart SDK), then `flutter analyze`.
  2. Pass `areas: targets.areas` where `QuickDrawWatcher` is created: `lib/ui/live_quick_draw_screen.dart` (~line 96) and `lib/ui/quick_draw_screen.dart` (~line 53).
  3. Tests: `areaBoard` (a circle of points → the right ellipse; too few / tiny / flat → null); the notifier keeps `areas` through replace/unlock/lock, clear resets; the watcher gives no score for an area player; the judge's texts and the same-frame draw for unscored throws.
  4. Full suite, commit Task 1, then Task 2.

## Task 2: The screen
- **Status:** NOT STARTED
- **Notes for it:** `BoardChoosing` (`lib/ui/quick_draw_boards.dart`) and `BoardsOverlay` (taps as fractions of the picture); add a draw gesture (pan → points as fractions → × `uprightSizeOf` of the camera's next frame, `maxSide: 1920`, rotation `camera.uprightRotation` → `areaBoard` → `add(board, area: true)`). Live screen `lib/ui/live_quick_draw_screen.dart` (`findBoardAt` at ~line 209), recording screen `lib/ui/quick_draw_screen.dart` (~line 114). Not two-target Play (`two_target_play_screen.dart`).

## Task 3: Docs, device checks, traceability, a build
- **Status:** NOT STARTED

---

## Plan Changes Log
- (none yet)
