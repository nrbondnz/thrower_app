# Story Checkpoint: Adjust Each Board (Two Targets)

## Story Goal
When two boards are chosen (Quick draw and two-target Play), each board's outline can be **dragged into place**, as the single target's can: move it, turn and stretch it, before locking. Today a wrong outline can only be fixed with **Choose boards again**, which forgets both boards. Backlog #10 ("Still to do: drag-to-adjust each board"). Requirements: [[Two Targets]], [[Game Type]] (Quick draw).

## Complexity Score
3 (Medium: 2 tasks): the targets model and the UI (2 layers); three screens share the change (`BoardsOverlay`).

## Status
IN PROGRESS: Task 1 of 2 complete (2026-10-19), awaiting Nigel's checkpoint. Plan approved with the Adjust boards button ("yes, start #10 with the Adjust boards button").

## What Exists
- **The single target:** `CalibrationEditor` (`lib/ui/calibration_editor.dart`). Drag inside the outer ring to move; drag the long-axis handle to turn and stretch; drag the short-axis handle to stretch. It's built on `TargetCalibration.moved`, `withMajorHandleAt` and `withMinorHandleAt` (pure, already tested). The screen says "Only adjust when no one is throwing." ([[Design Decisions]] → Adjust and Lock the Calibration).
- **Two boards:** `QuickDrawTargets` / `QuickDrawTargetsNotifier` (`add`, `clear`, `lock`), shared by Quick draw (`quickDrawTargetsProvider`) and two-target Play (`playTargetsProvider`). Drawn and tapped through `BoardsOverlay` / `BoardsPainter` (`lib/ui/quick_draw_boards.dart`).

## Design (proposed: architectural purity over the quick option)
- **Quick option (not chosen):** show a `CalibrationEditor` for one "selected" board, with buttons to switch between boards. It adds a mode to learn, and the other board can't be touched.
- **Chosen:**
  - **Take the editor's grab rule out into a pure function** (which handle or body a touch picks up: `grabAt(calibration, point, reach)`), used by `CalibrationEditor` and by a new **`BoardsEditor`** that hit-tests **both** boards. The touch picks the board under the finger, nearest handle first. No selection mode.
  - `QuickDrawTargetsNotifier.replace(index, board)`.
  - `BoardsOverlay` becomes the editor once both boards are found and not locked (taps no longer find boards then), on all three screens.
  - The same safety line as the single target.

## Question for Nigel (answered 2026-10-19: **yes, the Adjust boards button**)
1. **After locking:** adjust only **before Lock**, plus an **Adjust boards** button that unlocks while keeping both boards *(recommended: a knocked board is fixed without choosing both again)*; or before Lock only (Choose boards again after)?

## Acceptance Criteria
1. With both boards found and not locked, dragging inside a board moves it; dragging its handles turns and stretches it. The other board is untouched.
2. Lock locks the adjusted boards; throws are scored against them (Play) and timed on them (Quick draw).
3. Per the question: **Adjust boards** after locking unlocks them, keeping both.
4. While the outlines can be adjusted, the screen says "Only adjust when no one is throwing."
5. The single target's adjusting works exactly as before (the shared grab rule).

## Story Plan

### Task 1: Drag each board into place
- **Work:**
  - `grabAt` (pure, beside `TargetCalibration` or in `calibration_editor.dart`), used by `CalibrationEditor` (no behaviour change);
  - `BoardsEditor` (both boards; blue with handles while adjustable, as the single target);
  - `QuickDrawTargetsNotifier.replace`;
  - `BoardsOverlay` editable once both are found;
  - **Adjust boards** (per the question);
  - the safety line on the Quick draw and two-target Play screens.
- **Verify:**
  - tests: `grabAt` cases; dragging board 2 moves only board 2; the handles turn and stretch; the single target is unchanged; Lock keeps the adjusted boards; Adjust boards unlocks.
  - **Nigel:** Live test → Quick draw (or two-target Play): tap both boards, drag one a little off, drag it back, Lock.
- **Status:** COMPLETE (2026-10-19), awaiting Nigel's checkpoint
- **What changed:**
  - `lib/ui/calibration_editor.dart`:
    - **`CalibrationGrab`**, **`grabAt`** and **`dragged`**: the single target's drag rules, taken out to be shared. `CalibrationEditor` uses them.
    - **Fixed on the way:** on a small target (the handles' 32 px touch zone reaching its middle), touching the middle grabbed a handle. A handle now wins only when the finger is nearer it than the board's centre. Found by the two-board test: two boards in one view are often small on screen.
  - `lib/providers.dart`: `QuickDrawTargetsNotifier.replace(index, board)` (ignored once locked) and `unlock()` (keeps both boards). Shared by Quick draw and two-target Play.
  - `lib/ui/quick_draw_boards.dart`:
    - **`BoardsEditor`**: both boards draggable. A touch picks up the handle, or the board whose centre is nearest. Each board's two handles are drawn (`BoardsPainter(handles:)`).
    - `BoardsOverlay(onAdjust:)` switches to the editor while both boards are found and not locked.
    - The instruction: "Both boards found. Drag an outline to fit its rings if needed (only when no one is throwing), then lock them."
  - **Adjust boards** (unlocks, keeping both):
    - live Quick draw (`quickDrawAdjust`; not while a round is on; the match is kept);
    - the recorded Quick draw (not while playing; rewinds to the still board);
    - two-target Play (`playAdjustBoards`; stops watching and clears the marks; the scores stay; locking again watches afresh).
- **Verified by:** `flutter test`: 765 passed (16 new), `flutter analyze`: no issues.
- **Checkpoint saved:** 2026-10-19

#### Test Report — 2026-10-19 (Task 1)
- **New:** `test/ui/board_adjust_test.dart` (14):
  - `grabAt`: inside, the long handle, the short handle, just outside, far away, and on a small board the middle still moves it;
  - `dragged`: move and stretch;
  - the notifier: one board replaced, the other untouched; not once locked; Adjust boards unlocks, keeping both;
  - `BoardsEditor`: dragging inside board 2 moves only board 2; board 1's handle stretches board 1; dragging away changes nothing; the handles are drawn.
- **New (screens):** `two_target_play_screen_test.dart` (Adjust boards unlocks, keeping both, and locking again watches again); `live_quick_draw_screen_test.dart` (Adjust boards unlocks, keeping both; not while a round is on).
- **Updated:** the "Both boards found" instruction in three tests.
- **Results:** 765 passed, 0 failed.

#### Doc Update — 2026-10-19 (Task 1, Docs Agent)
- **Files updated:**
  - `Architecture/Design Decisions.md`:
    - new **"Adjust Each Board (2026-10-19)"**: its requirement line ([[Two Targets]], [[Game Type]]); the Adjust boards decision; the quick option not chosen vs shared `grabAt` / `dragged` / `BoardsEditor`; the small-target grab fix; Adjust boards on three screens; safety;
    - "Adjust and Lock the Calibration" notes the shared grab rule and the fix;
    - "Quick Draw: Choosing the Boards by Tapping" no longer says "No drag-to-adjust yet".
  - `requirements/Basic Play/Two Targets.md`: What Exists Today (drag into place, Adjust boards); its open question removed; links to the story and the decision. Status ✅.
  - `requirements/Basic Setup/Game Type.md` (Quick draw's board choosing); `requirements/Instructions and Safety.md` (the new on-screen line).
  - `Architecture/Glossary.md`: `CalibrationEditor` (`grabAt`, `CalibrationGrab`, `dragged`), `BoardsEditor`, `BoardsOverlay.onAdjust`, `BoardsPainter.handles`, `QuickDrawTargetsNotifier.replace` / `unlock`, Adjust boards on the three screens; concept "Grab (drag-to-adjust)".
  - `Architecture/System Diagram.md` (`BoardsEditor`; the notifier's functions; two-target Play named); `Architecture/Data Flow.md` (choosing boards: found → adjust → lock; Adjust boards → unlock).
  - `tool/web_docs/content.py`, rebuilt (index + 10 flows + 26 components); `stories/backlog.md` #10.
- **Files created:** none.
- **Drift fixed by the orchestrator** (from the agent's notes): the [[Data Flow]] box and the web flow were titled for Quick draw only; both now name two-target Play too.

### Task 2: Instructions, docs, device checks, traceability
- **Work:**
  - the Instructions (Quick draw and two targets: drag an outline to fix it; only when no one is throwing);
  - docs through the Docs Agent (requirements → architecture → design decisions: [[Two Targets]], [[Design Decisions]], [[Glossary]], [[System Diagram]], the web pages);
  - [[Device Test Plan]] checks;
  - the Review Agent (§7: adjusting means someone at the phone, which sits behind the throwers);
  - the Traceability Agent.
- **Verify:** `flutter test`; Nigel reads the Instructions.

---

## Plan Changes Log
- **2026-10-19:** Planned while Nigel was away. Stuck at: one question and plan approval.
