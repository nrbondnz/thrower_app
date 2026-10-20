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

## Task 2: Allow the gaps (became: a tapped-board fallback)
- **Status:** COMPLETE (2026-10-21)
- **What was found** (traced on the middle board): from its true centre the usual edge reading already fits the rings right (0.42), so the gaps alone weren't the problem. What fails is **where it starts and how big it thinks the board is**: no single-colour region is centred on a board whose rings are arcs on speckled wood, and from a start a few px off, the size comes from the first colour change, a speck. And each ray measures the rings from its own bull edge, which on a sprayed, speckled bull is noise.
- **Tried and rejected** (each broke boards that work today, or didn't help): gaps counted as neutral in the confidence (the gap rays find grain, not nothing); dropping weak edges; centre votes along edge gradients (a broad hill, not a peak); a size from the averaged edge profile as a third reading, even as a fallback (Live test board 2: 2 → 5 wrong frames); the fallback below with no tap, from the picture's middle (Live test board 2: near misses, a ring 10–20% off, confidence overlapping Mark's).
- **What changed** (`ColourRingLocator`, step 6 in its doc):
  - **A tapped board the usual search can't read:** `_alignedStarts` scores centres round the tap by how sharply the rings line up (the colour change averaged over every direction, by distance: `_radialProfile`), keeps the 3 best, each with the bull size whose 1×–4× multiples land on the strongest rings; then the edge reading **with that size fixed** for every ray (`_edgePoints(fixedScale:)`, which also keeps rays whose bull edge is unseen). The fit must be at least 10% of the searched window (`_alignMinShare`: grass under a tap made a 6% one).
  - **Any fit:** a bull under 6 working px is "Target too small" (`_minBullRadius`): speckle that looks like rings.
  - Only after a tap: Find target with no tap behaves as before on every board.
- **Results:** middle board, tapped on its bull or 7–10 px off (4 taps): found, rings on the paint (28 / 55 / 86 / 112 / 140 px vs measured 27 / 56 / 84.5 / 113 / 141; overlay checked). Right board (in shade, against the sky): found tapped on its bull or 10 px above; taps 10 px right or (−7, 7) give a wrong fit (a known limit: drag the outline, or tap again). Left board: cut off by the picture's edge, not a usable view. Every earlier fixture unchanged (Live test recordings, Quick draw taps incl. "a tap on the grass finds nothing", the ring locator's tests).
- **Answer key corrected** after the overlay: the middle board's 0.4 edge is 56 px (not 61), the right board's centre (204, 169). The middle's soft 0.4 edge (speckle to black) is allowed 10%.
- **Tests:** `marks_boards_test.dart` (rewritten: 6 taps on the whole picture, the middle board's edges, a tap on the fence finds nothing; no longer skipped).
- **Verified by:** `flutter test`: 869 passed; `flutter analyze`: no issues.

## Task 3: Allow other ring sizes
- **Status:** NOT NEEDED (2026-10-21): measured properly, Mark's rings are at 0.19 / 0.40 / 0.60 / 0.80 of the outer edge, IKTHOF's spacing; the failures were the start and the size, not the proportions.

## Task 4: Play's calibration: tap the board when Find target fails
- **Status:** COMPLETE (2026-10-21); device check to come (Task 5)
- **What changed:**
  - `lib/ui/calibration_screen.dart`: a **Tap the board** button (until the target is locked; "Cancel tap" while waiting). In tap mode the outline is hidden and the next tap on the picture runs `locateTappedInFrame` (as Quick draw) at that point, at the camera's current zoom (zooming would move the board from under the tap); the result starts the calibration as Find target's does (adjust, then lock). Status: "Tap the middle of the board in the picture."; the safety note shows in tap mode too. Find target's not-found texts now suggest tapping the board.
  - `lib/ui/instructions.dart` (Calibrating the target): when Find target can't find the rings (e.g. rings painted with gaps) or finds the wrong board, Tap the board, then tap the board's middle, only when no one is throwing.
- **Tests:** `calibration_screen_test.dart` (+3: the not-found texts, the button until locked, tap mode's status, Cancel tap and safety note); `instructions_test.dart` (+1).
- **Verified by:** `flutter test`: 873 passed; `flutter analyze`: no issues.
- **Plan (changed):** on Calibrate, when Find target can't find the rings, say so and let the user **tap the middle of the board**; the tap uses `locateTargetAt` (as Quick draw), which now has the fallback. Works for a picture with several boards too (the tap picks the board).

## Task 5: Instructions, docs, traceability, a build
- **Status:** IN PROGRESS

---

## Plan Changes Log
- **2026-10-21:** Task 2 became a tapped-board fallback (automatic search unchanged: every attempt to widen it broke boards that work); Task 3 dropped (Mark's rings are in IKTHOF proportion); Task 4 became "tap the board when Find target fails" in Play's calibration (covers several boards in the picture too).
