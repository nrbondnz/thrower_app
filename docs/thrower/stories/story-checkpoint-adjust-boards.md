# Story Checkpoint: Adjust Each Board (Two Targets)

## Story Goal
When two boards are chosen (Quick draw and two-target Play), each board's outline can be **dragged into place**, as the single target's can: move it, turn and stretch it, before locking. Today a wrong outline can only be fixed with **Choose boards again**, which forgets both boards. Backlog #10 ("Still to do: drag-to-adjust each board"). Requirements: [[Two Targets]], [[Game Type]] (Quick draw).

## Complexity Score
3 (Medium: 2 tasks): the targets model and the UI (2 layers); three screens share the change (`BoardsOverlay`).

## Status
PLANNED (2026-10-19, while Nigel was away): waiting for Nigel's approval and the question below. No code yet.

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

## Question for Nigel
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
