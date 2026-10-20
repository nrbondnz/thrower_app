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
- **Status:** COMPLETE (2026-10-21); device checks BF0–BF8 to come ([[Device Test Plan]])

#### Traceability Report — 2026-10-21 (Traceability Agent)
- **Coverage:** R1 (Mark's boards calibrate in Play), R2 (boards that work keep working), R5 (Instructions and safety) covered by code and tests; R3 (several boards: pick one) partly; R4 (scoring follows the painted rings) had no test. No orphan code.
- **Also:** two-target Play and Quick draw use `locateTappedInFrame` too, so they gain the fallback.
- **Findings and what was done:**
  1. Tap the board ran at the zoom Find target left, which may have zoomed past the right board. **Fixed:** entering tap mode zooms back to 1× first (`_toggleTapMode`).
  2. A search that throws (camera released, app in the background) left the buttons disabled. **Fixed:** `_find` and `_findAt` reset `_searching` in `finally`.
  3. A failed tapped search leaves an earlier outline (and Lock target) in place. **Accepted:** the status says it wasn't found; Find again or adjust.
  4. No scoring test. **Added:** "middle board, tapped: points in each painted ring score 5, 4, 3, 2, 1, then 0 beyond".
  5. Time: `locateTargetAt` on the 1080 × 1920 frame 1.4 s found, 3.1 s not found (PC, in a background isolate). **To check** on the Samsung (BF checks).
  6. `_minBullRadius` applied to every fit could hide a small, distant board (a "too small" rejection stops the coarse pass's retry). **Fixed:** only the tap fallback applies it.
  7. Nothing pinned Find target on the whole picture. **Added:** "Find target on the whole picture: if it finds a target, it is one of the boards".
- **Verified by:** `flutter test`: 875 passed; `flutter analyze`: no issues; the regression set (Mark's, the Live test recordings, Quick draw taps, the ring locator) passes.

### Doc Update — 2026-10-21

#### Files Created
- `requirements/Basic Setup/Board Finding.md`: the requirement (stencilled boards, several boards in view), what exists (Find target, Tap the board), open questions (off-centre taps on dark boards, gapped rings without a tap, a board cut off by the picture's edge); linked from `Requirements Index.md` (🟡).

#### Files Updated
- `Architecture/Design Decisions.md`: new section **Boards With Broken Rings: Tap the Board (2026-10-21)** (problem, measured truth, the tapped fallback by ring alignment, the 6 px bull minimum, Tap the board on Calibrate, why no automatic fallback, rejected attempts, results); a pointer from Ring Finding on Real Boards.
- `Architecture/Glossary.md`: `ColourRingLocator` step 6 (`_alignedStarts`, `_radialProfile`, `_refinedStart`, `fixedScale`, `_minBullRadius`); a `CalibrationScreen` entry (`_findAt`, Tap the board); concepts **Tap the board**, **Stencilled (broken) rings**, **Ring alignment (radial profile)**; Seed (tap) centre's "used by".
- `Architecture/Data Flow.md`: Tap the board under A Frame → a Calibration.
- `Architecture/System Diagram.md`: the calibration flow's tap path.
- `tool/web_docs/content.py` + `docs/web/` rebuilt: Ring finder (step 6), Tapped board finder (used by Calibrate), Finding and locking the target (the tap).
- `Operations/Device Test Plan.md`: **Board Finding Checks** BF0–BF8 (Nigel with `frame-1s.jpg` on the monitor; BF8 for Mark on his boards).
- `Troubleshooting/Known Issues.md`: Stencilled Boards: Find Target Can't Find Rings Painted With Gaps.
- `Operations/Common Tasks.md`: Add a Real Board From a Video as a Test Fixture (ffmpeg from `imageio_ffmpeg`, crop, measure, check the key, test).
- `requirements/Instructions and Safety.md`: the safety note in tap mode.
- `CLAUDE.md`, `docs/working-with-nigel.md`: this story built 2026-10-21 (device checks to come); Virtual thrower paused at Task 2.

#### Drift Items (not fixed)
- `CalibrationScreen` had no entry in the Glossary's component tree before this (added now with only `_find` / `_findAt`); its other functions (tap-to-score, knife entry, `lockedStatus`, `calibrationStatus`) are still undocumented there.
- `requirements/Basic Setup/Game Type.md` and others weren't checked for the virtual thrower story (no requirement page names it; backlog #19 only).
- The Device Test Plan's intro still describes only the iPhone/TestFlight field test, while most sections since are Nigel's Samsung checks.

---

## Plan Changes Log
- **2026-10-21:** Task 2 became a tapped-board fallback (automatic search unchanged: every attempt to widen it broke boards that work); Task 3 dropped (Mark's rings are in IKTHOF proportion); Task 4 became "tap the board when Find target fails" in Play's calibration (covers several boards in the picture too).
