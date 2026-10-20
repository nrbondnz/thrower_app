# Story Checkpoint: Quick Draw: Draw Round the Boards

## Story Goal
Mark (Nigel's brother), 2026-10-21: in Quick draw, "draw his finger round the board as a single hit point, not worrying about rings for scoring, just relying on hit time in the area he draws". Quick draw only. For build 9, before it goes to Mark.

## Complexity Score
3 (Medium): game logic (boards, throws, judge) → UI (drawing) → docs.

## Status
BUILT 2026-10-21, device checks to come (Drawn Board Checks QA0–QA7, [[Device Test Plan]]; Mark on build 9 from the Mac). Plan approved 2026-10-21 ("yes, go ahead"); run whole, committing per task ([[dont-ask-again]]).
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
- **Status:** COMPLETE (2026-10-21)
- **What changed:**
  - Both Quick draw screens (live and the recording): **Draw round the boards** / **Tap the boards** (`boardsModeButton`, key `quickDrawBoardsMode`), shown until the first board is chosen. The choice is kept for the session (`boardsDrawnProvider`); Choose boards again keeps it.
  - Drawing: `LoopDrawer` (in `BoardsOverlay` as `onDraw`, key `quickDrawBoardDraw`): the path follows the finger; on lift the loop (fractions of the picture) → `addDrawnBoard` → `pictureSizerProvider` (`uprightPictureSize`: the next frame upright, `maxSide` 1920, as tapped boards) → `areaBoard` → `add(board, area: true)`. Too small or flat: "That loop is too small or too flat for a board."
  - Instruction line: "Draw a finger round the edge of Player 1's board. Any knife that sticks inside counts: the time wins, not the score."; once both: "Drag an outline to fit its board…"; while working: "Marking Player 1's board…".
  - `BoardsPainter`: a drawn board shows only its outline (no rings). Adjust boards and dragging work as for tapped boards.
  - Not two-target Play (it needs scores): it never shows the button.
  - In-app Instructions, Quick draw: a point on drawing (on the screen, never at the boards; only when no one is throwing; only the time decides).
- **Test Report:**
  - `live_quick_draw_screen_test.dart`: +4 (switching and back; a loop round each → areas {0, 1}, picture size, centres, no ring search, lock; a tiny loop says so; the choice kept through Choose boards again).
  - `quick_draw_screen_test.dart`: +1 (drawing on the recording, then locked).
  - `instructions_test.dart`: the drawing point and its safety wording.
  - `flutter analyze`: no issues. `flutter test`: 899 passed.
- **Safety self-check (Review checklist §7):** drawing happens on the screen before anyone throws, like tapping; the Instructions say never at the boards and only when no one is throwing. No platform, permission or dependency change.

## Task 3: Docs, device checks, traceability, a build
- **Status:** COMPLETE (2026-10-21); device checks to come.

### Traceability Report — 2026-10-21
- 10 acceptance points; 7 fully covered at first, 3 partly; no orphan code; no bugs found.
- Gaps, all fixed:
  1. `uprightSizeOf` untested and a copy of `frameToRgb`'s sizing: `frameToRgb` now sizes its picture with `uprightSizeOf` (shared `_step`, `_scaledSize`), and `frame_to_rgb_test.dart` checks the two agree (under and over `maxSide`, all four rotations).
  2. Outline-only painting untested: `live_quick_draw_screen_test.dart` checks one path for a drawn board, five for a tapped one.
  3. Result panel with drawn boards untested: a same-frame finish shows "A draw" and times only ("1:  0.82 s"), and decides nothing in the match.
  4. Thresholds with no design record: in Design Decisions (Docs Agent).
  5. `QuickDrawThrow.toString` printed "stuck null" for a drawn board: now "stuck".
- Noted, not new: `addDrawnBoard` (like `findBoardAt`) waits for a frame with no timeout.
- `flutter analyze`: no issues. `flutter test`: 909 passed.

### Android build — 2026-10-21
- `flutter build apk --release` (155.6 MB), installed on the test phone with `adb install -r` (history kept).


### Doc Update — 2026-10-21

**Files updated:**
- `requirements/Basic Setup/Game Type.md`: What Exists Today, Quick draw: Draw round the boards (timed only, the same frame a draw, kept for the session, not two-target Play; QA0–QA7); Related.
- `requirements/Basic Setup/Board Finding.md`: drawn boards as Quick draw's way round rings the app can't find (backlog #20); Related.
- `requirements/Instructions and Safety.md`: the story's Instructions point and the on-screen drawing line; Related.
- `requirements/Requirements Index.md`: Game Type and Board Finding notes.
- `Architecture/Design Decisions.md`: new **Quick Draw: Draw Round the Boards (2026-10-21)**. Timed only; the ellipse fitted to the loop and why; the thresholds (`minLoopPoints` 8, `minAreaRadius` 0.03, larger radius ≤ shorter side, `minRoundness` 0.35) and their reasons; the same frame is a draw; not two-target Play; the options; safety; tests. Links [[Game Type]], [[Board Finding]] and [[Instructions and Safety]].
- `Architecture/Glossary.md`:
  - component tree: `addDrawnBoard`, `boardsModeButton`, the drawn instruction lines, `BoardsOverlay.onDraw`, `LoopDrawer`, `BoardsPainter` (outline only), `QuickDrawTargets.areas` / `add(board, {area})`, `areaBoard`, `PictureSizer` / `uprightPictureSize` / `pictureSizerProvider`, `boardsDrawnProvider`, `QuickDrawThrow.scored`, `JudgedThrow.scored`;
  - new concept **Drawn board (area board)**; the Quick draw concept updated.
- `Architecture/Data Flow.md`: a "Quick Draw: Draw Round the Boards" diagram under Choosing the Boards; the "Drawn loop (Quick draw)" coordinate entry.
- `Architecture/System Diagram.md`: drawing in `quick_draw_boards`; `boardsDrawnProvider`, `pictureSizerProvider` and `areas` in the wiring; the live Quick draw note.
- `tool/web_docs/content.py`, then `python tool/web_docs/build.py`: Screens, Providers, Tapped board finder (now cites `lib/game/area_board.dart`), QuickDrawWatcher and judgeQuickDraw components; the Choosing two boards flow.
- `Operations/Device Test Plan.md`: new **Drawn Board Checks** (QA0–QA7, plus a line for Mark on his real boards).
- `Operations/Mac Handoff.md`: a build 9 bullet (no new plugins or permissions; `flutter test` 899 on the PC); QA added to the checks to send Mark.
- `stories/backlog.md`: #20 notes drawn boards as the workaround for Quick draw.
- `Troubleshooting/Known Issues.md` → Quick Draw: a Board Isn't Found: removed the stale "no drag-to-adjust per board yet"; it now points to Adjust boards and Draw round the boards.
- `CLAUDE.md`, `docs/working-with-nigel.md`: the story in the overview (built 2026-10-21, device checks to come).

**Drift items (not fixed here):**
- The interactive Thrower Field Test artifact (Device Test Plan header) wasn't checked for the QA checks (or BF). If they're missing, add them before sending build 9's checks to Mark.

---

## Plan Changes Log
- (none yet)
