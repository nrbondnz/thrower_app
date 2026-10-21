---
tags: [requirement, basic-setup]
status: partly-built
---

# Board Finding

Part of [[Requirements Index]] → Basic setup. **Status:** 🟡 Partly built (most boards found automatically; stencilled boards with a tap; device checks to come)

## What's Wanted
- **Calibration finds the throwers' own boards**, whatever the paint, so each throw can be scored against the painted rings. Not only Nigel's boards: other people's boards too.
- **Stencilled boards with broken rings** (Mark, Nigel's brother, 2026-10-20): a sprayed red bull, then bare wood, a black ring painted in four arcs with gaps between them, wood, a second broken black ring, then wood to the bark; speckled wood, red dots and cracks.
- **Several boards in view:** Mark's three boards stand side by side on a fence, so the picture holds more than one board, and the app must calibrate the one being thrown at.
- Scored as painted: on Mark's boards red 5, wood 4, inner black 3, wood 2, outer black 1, and 0 beyond the outer black ring (KATTA; see [[Scoring Rules]]).

## What Exists Today
- **Find target** (Play → Calibrate): finds the rings automatically on Nigel's boards, the reference photo, the A4 printout and the Live test recordings ([[Design Decisions]] → Ring Finding on Real Boards; Find Roughly, Then Look Closely). Then drag to adjust and Lock target.
- **Tap the board** (2026-10-21, [[story-checkpoint-gapped-rings]]): when Find target can't find the rings, or finds the wrong board, the user taps **Tap the board**, then the middle of their board in the picture. The rings are looked for round the tap, at the camera's current zoom; the outline can then be adjusted and locked as usual. This also picks one board out of several.
- **Stencilled rings:** found after a tap by how sharply the rings line up round it ([[Design Decisions]] → Boards With Broken Rings: Tap the Board). On Mark's middle board the outline lands on the paint (within a few px of the measured edges).
- **Quick draw: Draw round the boards** (2026-10-21, [[story-checkpoint-quick-draw-areas]]): Quick draw doesn't need the rings (the time decides), so its boards can be drawn round by finger instead of found: the ellipse fitted to the loop is the board, timed only, never scored ([[Design Decisions]] → Quick Draw: Draw Round the Boards). A workaround for boards whose outlines come out at the wrong scale (backlog #20). Device checks QA0–QA7.
- **Square and rectangular boards** (Quick draw, drawn, 2026-10-21, [[story-checkpoint-board-outlines]]): a drawn loop with corners becomes a four-cornered outline (`BoardShape`, `OutlineShape`), corners kept where drawn in the picture (perspective), cut at the picture's edge; a round loop stays an oval. Throw detection watches the board's own shape, so a knife in a corner counts ([[Design Decisions]] → Quick Draw: Round or Four-Cornered Boards). Device checks QA8–QA14.
- **Instructions:** Calibrating the target says to use Tap the board when Find target can't find the rings (for example, rings painted with gaps) or finds the wrong board, only when no one is throwing ([[Instructions and Safety]]).
- **Tests:** `test/vision/marks_boards_test.dart` (Mark's boards from his video, `test/fixtures/marks_boards/`), `test/ui/calibration_screen_test.dart`.
- **Device checks to come:** [[Device Test Plan]] → Board Finding Checks (BF0–BF8).

## Open Questions
- **Off-centre taps on a dark board:** Mark's right board (in shade, against the sky) is found when tapped on its bull or just above, but a tap 10 px to the right gives a wrong fit. Can the tapped search be made steadier on low-contrast boards, or is "drag the outline, or tap again" enough? ([[Known Issues]] → Stencilled Boards)
- **Gapped rings without a tap:** Find target on its own still can't find stencilled boards. Every attempt to widen the automatic search broke boards that work today (see the decision's rejected attempts). Worth another try later, perhaps with more real boards as fixtures?
- **The whole board must be in view:** Mark's left board is cut off by the picture's edge, so it isn't a usable view. Should the app say so (e.g. "Move the phone so the whole board is in the picture")?
- Other ring patterns still untested: axes boards, boards with numbers painted in the rings, very worn paint.

## Related
- [[Design Decisions]] → Boards With Broken Rings: Tap the Board; Ring Finding on Real Boards; Adjust and Lock the Calibration; Quick Draw: Choosing the Boards by Tapping; Quick Draw: Draw Round the Boards; Quick Draw: Round or Four-Cornered Boards
- [[Glossary]] → Ring alignment (radial profile), Tap the board, Stencilled rings, Seed (tap) centre, Drawn board, Board shape, Reach, Board outline (four-cornered board)
- [[Scoring Rules]], [[Instructions and Safety]]
