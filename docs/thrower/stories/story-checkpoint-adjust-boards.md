# Story Checkpoint: Adjust Each Board (Two Targets)

## Story Goal
When two boards are chosen (Quick draw and two-target Play), each board's outline can be **dragged into place**, as the single target's can: move it, turn and stretch it, before locking. Today a wrong outline can only be fixed with **Choose boards again**, which forgets both boards. Backlog #10 ("Still to do: drag-to-adjust each board"). Requirements: [[Two Targets]], [[Game Type]] (Quick draw).

## Complexity Score
3 (Medium: 2 tasks): the targets model and the UI (2 layers); three screens share the change (`BoardsOverlay`).

## Status
BUILT: both tasks complete (2026-10-19); Task 1 committed (`d96be0d`). **Waiting for the device checks** ([[Device Test Plan]] → Adjust Boards Checks, A0–A5: Nigel on the Samsung for A0–A4; A5 needs the live camera; in TestFlight 1.0.0 (9)). Archive the story once they pass.

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
- **Status:** COMPLETE (2026-10-19); Nigel: "commit this and continue to task 2" (`d96be0d`)
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
- **Status:** COMPLETE (2026-10-19), awaiting Nigel's checkpoint
- **What changed:**
  - `lib/ui/instructions.dart`:
    - **Two players on two targets** and **Quick draw:** "If an outline doesn't fit its rings, drag it into place (inside to move it, a white handle to turn or stretch it), or tap Choose boards again."
    - **Two targets:** "If a board or the phone is knocked during a game, tap Adjust boards when no one is throwing, drag the outline back, then Lock boards. Watching stops until you lock again; the scores stay."
    - **Quick draw:** "Between rounds, Adjust boards unlocks them to fix an outline (only when no one is throwing); the match carries on."
  - [[Device Test Plan]] → **Adjust Boards Checks** (A0–A5). [[Mac Handoff]] section 0000: build 9 carries this too; 766 tests.
  - **Docs Agent:**
    - Design Decisions: the In-app Instructions decision updated, and Adjust Each Board notes the Instructions.
    - Requirements: [[Two Targets]] and [[Instructions and Safety]].
    - Backlog #10 done.
    - `CLAUDE.md` and `working-with-nigel.md` overviews.
- **Verified by:** `flutter test`: 766 passed (1 new), `flutter analyze`: no issues.
- **Checkpoint saved:** 2026-10-19

#### Test Report — 2026-10-19 (Task 2)
- **New:** `instructions_test.dart` (1): dragging an outline into place; Adjust boards in two targets (when no one is throwing, the scores stay) and Quick draw (between rounds).
- **Results:** 766 passed, 0 failed.

#### Doc Update — 2026-10-19 (Task 2, Docs Agent)
- **Files updated:**
  - `Architecture/Design Decisions.md`: the In-app Instructions update for Task 2 (Requirement: [[Instructions and Safety]], [[Two Targets]]); Adjust Each Board notes the Instructions.
  - `requirements/Basic Play/Two Targets.md`, `requirements/Instructions and Safety.md`.
  - `stories/backlog.md` (#10 done; device checks to come).
  - `CLAUDE.md` and `docs/working-with-nigel.md`.
- **Notes:** the web pages are unchanged (the Instructions screen is described in general terms); Game Type was already current.

#### Safety Report — 2026-10-19 (whole story, Review Agent)
- **Files reviewed:** `lib/ui/calibration_editor.dart`, `lib/ui/quick_draw_boards.dart`, `lib/providers.dart`, the three screens, `lib/ui/instructions.dart`. `pubspec.yaml`, `AndroidManifest.xml` and `Info.plist` are unchanged.
- ✅ §1–§6: no platform, permission, data or performance change. The editor is gestures and painting only.
- ⚠️→✅ **§7 Physical safety:**
  - Adjusting means a hand at the phone. In two-target Play and Quick draw the phone stands **behind the throwers**, out of both lines of throw, so this is less exposed than the single target's phone beside the board. It can still be near a backswing.
  - **Mitigations:**
    - The on-screen line while adjusting: "…(only when no one is throwing)…".
    - The Instructions say "when no one is throwing" for Adjust boards, in both modes.
    - In Quick draw, **Adjust boards is hidden once Start is tapped** (tested), so nothing invites anyone to the phone during a round.
    - In two-target Play, **Adjust boards stops watching** until Lock, so throws made while someone adjusts aren't scored by surprise.
  - **Residual:** the app can't see whether anyone is throwing; the players are relied on, as for collecting knives.
- ✅ §8: no stored data; rolls back cleanly.
- **Verdict:** OK to commit.

#### Traceability Report — 2026-10-19 (story complete, device checks to come)

- **AC1: drag inside a board to move it, a handle to turn and stretch it; the other untouched**
  - **Design Reference:** Design Decisions → Adjust Each Board
  - **Implementation:** `BoardsEditor`, `grabAt`, `dragged`, `QuickDrawTargetsNotifier.replace`, `BoardsOverlay(onAdjust:)`
  - **Test:** `board_adjust_test.dart` (`grabAt` ×6, `dragged`, replace, editor ×4)
  - **Status:** ✅ Covered (device: A1, A2)
- **AC2: Lock locks the adjusted boards; they're scored and timed against**
  - **Design Reference:** Adjust Each Board
  - **Implementation:** `lock` (unchanged), the watchers built from the locked boards
  - **Test:** `two_target_play_screen_test.dart` (lock again → watching); `live_quick_draw_screen_test.dart` (lock again → Start)
  - **Status:** ✅ Covered (device: A3, A4)
- **AC3: Adjust boards unlocks, keeping both**
  - **Design Reference:** Adjust Each Board (Nigel: yes)
  - **Implementation:** `unlock`; `quickDrawAdjust`, `playAdjustBoards` / `_adjustBoards`, the recording's button
  - **Test:** `board_adjust_test.dart` (unlock keeps both); both screen tests
  - **Status:** ✅ Covered (device: A3–A5)
- **AC4: "only when no one is throwing" while adjustable**
  - **Design Reference:** Adjust Each Board → Safety; [[Instructions and Safety]]
  - **Implementation:** `choosingInstruction`; the Instructions
  - **Test:** three screen tests (the instruction); `instructions_test.dart`
  - **Status:** ✅ Covered (and the Safety Report)
- **AC5: the single target unchanged (the shared rule)**
  - **Design Reference:** Adjust and Lock the Calibration (update)
  - **Implementation:** `CalibrationEditor` → `grabAt` / `dragged`
  - **Test:** `calibration_screen_test.dart` (6, unchanged, passing)
  - **Status:** ✅ Covered. One deliberate change: on a small target, the middle now moves it (`board_adjust_test.dart`)

- **Coverage:** 5 of 5 have design, code and tests; device checks A0–A5 are to come.
- **Backward:** every new symbol traces to an AC. `BoardsPainter(handles:)` serves AC1.
- **Chain** (Docs Agent): [[Two Targets]] and [[Game Type]] → Design Decisions → Adjust Each Board, linked both ways; the Instructions decision sits under [[Instructions and Safety]].

---

## Plan Changes Log
- **2026-10-19:** Planned while Nigel was away. Stuck at: one question and plan approval.
- **2026-10-19:** Nigel: yes to Adjust boards. Both tasks done; story BUILT, waiting for A0–A5. Task 1 found and fixed the small-target grab (a handle's touch zone covered the middle).
