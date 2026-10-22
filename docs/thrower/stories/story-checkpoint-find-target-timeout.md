# Story Checkpoint: Find Target Time Limit

## Story Goal
Backlog #23. Nigel, 2026-10-23: "When the app says looking for target, how long does it look? Thinking it should timeout after 5 or so seconds as it generally finds them quickly. This will allow the user to tap on the target rather than waiting a long time." Then: "backlog it, I am not sure it's really an issue … 'only if testing shows it's needed'."

If a search takes longer than **5 seconds**, stop waiting, say so, and offer **Tap the board** straight away, so the thrower isn't left watching "Looking for the target…". Requirement: [[Board Finding]].

## Status
**BACKLOG: only if testing shows it's needed.** Not started; no code. Build it only if a tester reports Find target (or a board tap) taking a long time. Before building, ask for the time shown after the result (e.g. "(1393 ms)"), which is how long the search took.

## How Find Target Works Today (2026-10-23)
- There's **no time limit**, but it isn't a repeating search either. `findTarget` (`lib/game/find_target.dart`) looks at **one or two still pictures**:
  1. Zoom to 1×; run the ring finder (`locateInFrame`, in an isolate via `compute`) on one picture.
  2. If found, zoom in on the board (`zoomToFit`), wait 0.5 s (`settle`), and search one closer picture.
  3. If the closer search fails, zoom back to 1× (another 0.5 s) and keep the first result.
- Calibrate shows "Looking for the target…" (`statusText` in `lib/ui/calibration_screen.dart`) until that ends, then the result with the time taken (`_millis`).
- A long wait therefore means **one slow ring-finder run** on a hard picture (busy or gapped boards make it work harder), not retrying. Mark's build 8 screenshot: **1393 ms**, ending "Rings too unclear".
- Quick draw (`lib/ui/quick_draw_boards.dart`: "Looking for Player 1's board…") and two-target Play search at a tapped point in the same way.

## Complexity Score
2 (Medium): game logic → UI (2 layers); one branch (timed out). No platform, plugin or data changes.

## Proposed Plan

### Task 1: A time limit on Find target
- **Work:** `findTarget` takes a `limit` (default 5 s). It races the wide search against the limit:
  - Wide search not back in time → a new result, **timed out**. The isolate can't be stopped part-way; its result is ignored when it arrives. That costs only some battery.
  - Wide search found, then the zoomed search runs past the limit → keep the wide result (zoom back to 1×), never throwing away a board already found.
- Calibrate: on timed out, the message "Couldn't find the target quickly. Tap the middle of the board." and **Tap the board** mode switched on.
- **Tests:** a fake `FrameLocator` that never answers (timed out, after the limit with a fake clock or a short limit); one that answers late on the zoomed search (the wide result kept); the usual fast path unchanged. Widget test: Calibrate shows the message and tap mode.
- **Verify (Nigel):** on a board it can't read quickly (or a debug-only short limit), the message appears after 5 s and tapping the board works.

### Task 2: The same for board taps (Quick draw, two-target Play)
- **Work:** the same limit on the search at a tapped point; on timed out, "Couldn't find a board there quickly. Tap again, or draw round it." (Quick draw has Draw round the boards.)
- **Tests:** as Task 1, for the tapped search.

### Task 3: Instructions, docs, traceability
- `lib/ui/instructions.dart` (Calibrate: what happens after 5 s); [[Design Decisions]] → Target Calibration (the limit and why 5 s); [[Board Finding]]; [[Device Test Plan]] checks; the Traceability Agent.

## Open Questions (for when it's picked up)
- Is 5 s right, or should it depend on the phone (slower phones take longer for the same picture)?
- Should a timed-out search still show its answer if it arrives a moment later (e.g. "Found it after all")? The plan above ignores it, for simplicity.

## Plan Changes Log
- **2026-10-23:** Written up and backlogged (#23), **only if testing shows it's needed** (Nigel, from the Mac session).
