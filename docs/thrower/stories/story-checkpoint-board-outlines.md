# Story Checkpoint: Quick Draw: Round or Four-Cornered Boards

## Story Goal
Nigel, 2026-10-21, after [[story-checkpoint-quick-draw-areas]]: a drawn Quick draw board "might be a circle as you have assumed but sometimes it could be a square or rectangular board … if it looks vaguely circular, fine, but if it looks rectangular make it rectangular. I guess the actual view the camera can see should also factor in." So a loop drawn round a board becomes an oval or a four-cornered outline, whichever fits; the corners stay where they were drawn in the picture (a rectangle seen from the side isn't a rectangle), and the outline is cut at the picture's edge.

## Complexity Score
3 (Medium): vision (the board's shape in throw detection) → game (the fit) → UI (painting, corner handles) → docs.

## Status
IN PROGRESS: plan approved 2026-10-21 ("yes", the architectural-purity option); run whole, committing per task ([[dont-ask-again]]).

## Plan
- **Task 1: boards answer for their own shape.** `BoardShape` (an oval, or a four-cornered outline) with `reach` (1 on the edge, scaling about the centre, as an ellipse's normalised radius), `centre`, `halfExtent`, `area`. `TargetCalibration.outline` (optional corners) and `shape`. Motion watching (`WatchRegion`), the crop (`cropToBoard`), the new-knife search and touch test (`findNewObject`, `minKnifeArea`) ask the shape. Ring boards unchanged (full suite and the duel replays). Not zoom (Play only).
- **Task 2: the fit.** `areaBoard` fits both an oval and the four loop points enclosing the most area; keeps the outline when it hugs the loop clearly better (bias to the oval); corners cut at the picture's edge. Tests: circle, side-on oval, square, rectangle in perspective, sloppy square; the duel replay with a board drawn as a square.
- **Task 3: the screen, docs, checks.** Paint the outline; corner handles in Adjust boards (inside drags it); Instructions; Docs and Traceability agents; device checks; Android build.
- Automatic choice (no button). Two-target Play unchanged.

---

## Task 1: Boards answer for their own shape
- **Status:** COMPLETE (2026-10-21)
- **What changed:**
  - `lib/vision/board_shape.dart` (new): `BoardShape` (`reach`, `centre`, `halfExtent`, `area`, `meanRadius`, `rescaled`, `translated`); `EllipseShape` (a ring board's outer ring, the same sums as before) and `OutlineShape` (convex corners, either way round; `reach` is the largest edge-wise share of each edge's distance from the corners' average, so the outline scaled by k is where it is k).
  - `TargetCalibration.outline` (optional corners) and `shape`; `moved`, `within` and the handle drags take the corners along.
  - Asking the shape: `WatchRegion.fromCalibration` (box; `target` is now a `BoardShape`), the motion detector's on-target test, `cropToBoard` (centre, `meanRadius`), `findNewObject` (search and touch; ring boards keep their old search square), `minKnifeArea` (area). Not `zoomToFit` (Play only) or the entry point (drawn boards aren't scored).
- **Test Report:**
  - New `test/vision/board_shape_test.dart`: 18 (the ellipse's reach, box, area as before; the outline's reach at centre, edge, corner, halfway, outside, either way round, a rectangle in perspective; box, area, rescale, move; a board with an outline: its shape, moved/cropped/stretched corners, the watched region, the crop, the smallest knife, and a knife in a square board's corner found, which the circle alone misses).
  - `motion_detector_test.dart`: the region's target wrapped in `EllipseShape`.
  - `flutter analyze`: no issues. `flutter test`: 927 passed (ring boards and the duel replays unchanged).

## Task 2: The fit
- **Status:** COMPLETE (2026-10-21)
- **What changed:** `lib/game/area_board.dart`:
  - `areaBoard` cuts the loop at the picture's edge, fits the oval (as before; still the board's `outer`), then `boardOutline`.
  - `boardOutline(loop, oval)`: the loop's `convexHull` → the four hull points enclosing the most area (`_largestQuad`, for each diagonal the best point on each side) → kept when the loop's mean miss from it (`|reach − 1|`) is under the oval's by `cornerMargin` (0.01, a lean to the oval).
  - **Why a margin, not a ratio:** first tried "corners under 0.5 × the oval's miss"; a square drawn with 12 px of jitter came out round (0.064 vs 0.105), because shaking adds to both misses. Measured (mean miss, oval vs corners): circle 0 vs 0.27, shaky circle (20 px) 0.07 vs 0.15; square 0.10 vs 0, shaky square 0.12 vs 0.10, shaky rectangle in perspective 0.11 vs 0.05. Every round loop misses its corners by more; every cornered loop misses its oval by more.
- **Test Report:**
  - `area_board_test.dart`: +11 (circle, side-on oval, wobbly circle stay round; square, rectangle, rectangle in perspective, square on its corner → corners where drawn; a jittery square; shaky drawing, 20 px: circle and side-on oval round, square and perspective rectangle cornered; the oval kept; a board off the picture's edge cut at it).
  - `quick_draw_replay_test.dart`: +1, Mark's duel with each board drawn as a square round it: the same throws, Player 1 on the same frame, Player 2 one frame sooner (the corners reach further), Player 2 still wins.
  - `flutter analyze`: no issues. `flutter test`: 939 passed.

## Task 3: The screen, docs, checks
- **Status:** IN PROGRESS (screen done; docs, traceability, build to come)
- **What changed:**
  - `BoardsPainter`: a four-cornered board is painted as its outline, with a handle on each corner while adjusting; the player's number and result line sit on its box (`_span`; round boards as before).
  - `CalibrationGrab.corner0`…`corner3` (`corners`, `corner`); `grabAt` on an outline: the nearest corner within reach (unless the touch is nearer the centre), else inside the outline (`reach` ≤ 1.1) moves it; `dragged` → `TargetCalibration.withCornerAt`, which refuses a corner that would fold the outline (`isConvex`). `BoardsEditor` ranks boards by `shape.reach`.
  - Instruction line: "Draw a finger round the edge of Player 1's board (round, square or rectangular)."; in-app Instructions: a round board stays round; a square or rectangular one gets four corners to drag into place.
- **Test Report:**
  - `board_adjust_test.dart`: +9 (grab a corner, inside a corner beyond the circle, outside; drag a corner; folding refused; move; painted as one outline with 4 corner handles; `isConvex`).
  - `live_quick_draw_screen_test.dart`: +1 (a square drawn on the screen → four corners); instruction texts updated.
  - `instructions_test.dart`: the four-corner sentence.
  - `flutter analyze`: no issues. `flutter test`: 948 passed.

---

## Plan Changes Log
- (none yet)
