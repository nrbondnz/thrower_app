# Story Checkpoint: Calibrating Boards With Broken Rings and Other Ring Sizes

## Story Goal
Mark (Nigel's brother) couldn't get Play's **Calibrate → Find target** to fix on his boards (Nigel, 2026-10-20). His boards are stencilled: a red bull, then bare wood, a **black ring painted in four arcs (gaps between them)**, wood, a second broken black ring, then wood to the bark; red dots and cracks; three boards side by side on a fence. Make calibration find such boards, and score them as painted.

Video: Mark's `EF3EBFE0-7BA9-4318-B978-361527C66356.MOV` (1080 × 1920 portrait, 30 fps, 3:48), from Nigel's Downloads; frames from its first seconds are the fixtures.

## Answers (Nigel, 2026-10-21)
- Mark's scoring: **red 5, wood 4, inner black 3, wood 2, outer black 1**; beyond the outer black ring scores 0.
- Mark tried **Play: Calibrate → Find target** (three boards in view).

## Findings (2026-10-20, before any change)
`buildTargetLocator` on a frame at 1 s:
- middle board crop: "Ring sizes out of proportion"; right board crop: the same; left board crop: "Rings too unclear";
- the whole frame: "found" a target in the net above the boards (wrong).

Causes: (1) rays through the gaps find no edge, lowering the fit's confidence; (2) the rings aren't at IKTHOF's even spacing (measured roughly 0.16 / 0.33 / 0.58 / 0.74 of the outer edge, not 0.2 / 0.4 / 0.6 / 0.8), so good fits are rejected; (3) three boards, red dots, cracks and the net in one picture. Scoring already uses each board's measured painted edges (`TargetMapping`), so only finding the rings needs to change.

## Complexity Score
4 (Large): vision (ring finding) → calibration → scoring; fixtures; several acceptance criteria; must not break any existing board.

## Status
IN PROGRESS: plan approved 2026-10-21 ("yes, start on Mark's boards"); run whole, committing per task.

---

## Task 1: Mark's boards as test cases
- **Status:** COMPLETE (2026-10-21)
- **What changed:** `test/fixtures/marks_boards/` (the frame at 1 s, the three boards cropped, `truth.json`, a README); `test/vision/marks_boards_test.dart` (5 tests: each board found, on its bull, the right size; the middle board's edges within 7%; the whole picture finds the middle board), **skipped** (`notYet`) until the fixes land.
- **Measured** (middle board, 120 rays from the bull, an ellipse per edge): black edges at 61 / 84.5 / 113 / 141.5 px, i.e. **0.43 / 0.60 / 0.80** of the outer edge; the red bull's sprayed edge by eye ~24–28 px (~0.18–0.20). So the board is close to IKTHOF after all (the earlier rough 0.16 / 0.33 / 0.58 / 0.74 was off-centre): the failures are the gaps and the clutter, not the proportions. Task 3 may not be needed.
- **Today** (all 5 fail): middle, right and the whole picture "Rings too unclear"; left a wrong, tiny fit at (309, 86).

## Task 2: Allow the gaps
- **Status:** NOT STARTED

## Task 3: Allow other ring sizes
- **Status:** NOT STARTED

## Task 4: A picture with several boards
- **Status:** NOT STARTED

## Task 5: Instructions, docs, traceability, a build
- **Status:** NOT STARTED

---

## Plan Changes Log
- (none yet)
