# Story Checkpoint: Entry Point

## Story Goal
Score each stuck knife by where its **blade enters the board**, not by its shadow or by whichever end of it lies nearest the bull. Nigel, 2026-10-13: *"we need the app to focus on finding the entry point. If it's obscured, it's likely the score that you can see, as the knife has gone in directly in line with the camera."* Option B of the 2:20 scoring report; overlaps [[backlog]] #3 (Refine scoring by hit point).

## Complexity Score
3 (Medium): crosses vision → scoring (2), more than 3 acceptance criteria (1). 4 tasks.

## Status
IN PROGRESS: Task 1 of 4 complete; Task 2 paused (colour shadow tests no better on this footage), waiting for new, closer footage.

## Baseline (2026-10-13, answer key re-scored and reviewed by Nigel from the original)
Nigel re-scored every knife from the original video, then reviewed the six the app disagreed with. Three were his (b1-t01 is a 4, b1-t02 a 5, b1-t10 a 4: hidden in the footage, but he watched it pulled out of the 4). The app now scores **16 of 19** exactly (Target 1: 9 of 10; Target 2: 7 of 9). The three real misses (Nigel → app):

- **b1-t11**
  - **Video time:** 2:17
  - **Nigel:** 3
  - **App:** 4
  - **Why (Nigel, on review):** "You can see the solid knife shape in the 3." The shape the app found was mostly the **shadow** beside the blade.
- **b2-t02**
  - **Video time:** 1:10
  - **Nigel:** 4
  - **App:** 5
  - **Why (Nigel, on review):** "Always look for the solid shape of the knife. The shadow is there, but it's coming from the knife; the light is to the right on this target."
- **b2-t05**
  - **Video time:** 1:46
  - **Nigel:** 4
  - **App:** 5
  - **Why (Nigel, on review):** "Difficult to pick out, but below the blade tip there is white, not red, so it's 4."

- All three score **too high**: `faceOnEntry` takes the knife pixels nearest the bull, and a shadow reaches nearer the bull than the blade.
- Nigel's rule: **find the solid shape of the knife** and score where the blade goes into the wood. Notes: b1-t12 (2:20) "4, handle end leans into 5"; b2-t09 (2:20) "point gets to 4"; b2-t10 (2:43) "think 5, as though the point is 4, the part sticking in is 5".
- Earlier the same day Nigel had called b1-t12 and b2-t02 3s; his full re-score has them as 4s. The key follows the re-score.

## Acceptance Criteria
1. Shadows aren't counted as part of the knife.
2. A knife seen side-on is scored at its blade's end, wherever the bull is.
3. A knife seen end-on (in line with the camera, entry hidden) is scored by the ring the visible knife covers.
4. Neither board's exact-score count goes down; the replay test's floors rise to the new figures.
5. No change to throw/bounce-out/collection detection (the other replay tests still pass).

---

## Task 1: A knife review sheet, and the re-check
- **Status:** COMPLETE (2026-10-13), without the sheet: Nigel re-scored every knife from the original, then reviewed the six misses himself and explained the three real ones (Baseline above).
- **What changed:** `truth.json` (his scores and notes); `live_replay_test.dart` floors 9 and 7.
- **Verified by:** `live_replay_test.dart` passes (16 of 19).

## Task 2: Leave shadows out of the knife shape
- **Status:** NOT STARTED
- **Depends on:** Task 1
- **Work:** a shadow darkens the board but keeps its colour (the same hue and roughly the same red:green:blue ratios, just dimmer). A blade or handle changes the colour. `findNewObject` / the classifier drops changed pixels that look like the same paint in shadow. A shadow also lies on the side of the knife away from the light (to the left on board 2), joined to the solid knife. Fixture tests from the real frames (136.5 s on board 1, 69.6 s on board 2).
- **Verify:** before/after close-ups of the two shadow knives with the old and new shapes drawn on; Nigel checks them. Both should score as he did.
- **Save:** detection replay tests unchanged (criterion 5).
- **Status (2026-10-13): PAUSED, no code kept.** Two colour approaches were tried in a scratch probe (replaying both recordings, then re-scoring each stuck knife from its trimmed shape with `faceOnEntry`), against today's 16 of 19:
  1. **Drop "shadow" pixels from the brightness shape:** darker after the throw (by a factor of 0.3–0.92) with the same tint (red:green:blue shares within 0.02–0.035). Best: 16 of 19. It fixes b1-t11 but breaks another knife. It labels 30–99% of every knife as shadow: at 322 px, a grey blade on pale wood and a black handle are also "darker, same tint".
  2. **Rebuild the shape from strong colour change** near the knife (tint shift ≥ 0.06–0.10, or darker than ×0.5–0.65, or brighter than ×1.15–1.25), keeping the largest piece touching the brightness shape. Best: 16 of 19. It fixes b1-t11 (the silver blade on red changes tint, not brightness, so the brightness shape had missed it), but breaks b1-t08 (5 → 4 or 3), and on many knives finds nothing.
  - Neither ever fixes b2-t02 (the black handle and its shadow look the same) or b2-t05 (the white just below the blade tip).
  - Why: the boards are ~245 px across at dusk and JPEG-compressed, so a blade is 2–4 px wide and rings are ~18 px. Any rule that wins here would be tuned to three knives.

## Task 3: Find the blade's end
- **Status:** NOT STARTED
- **Depends on:** Task 2
- **Work:** replace "nearest the bull" in `faceOnEntry` with the blade's end of the knife:
  - **Side-on** (long shape): the end where the blade meets the board. Candidates, measured on both boards against the key: the narrower end (a blade is thinner than a handle), the end where the shape stops in board colour rather than in the handle's colour, and today's nearest-the-bull as a tie-break.
  - **End-on** (short, compact shape: the knife points at the camera, entry hidden): the ring under the visible knife (the shape's centre), per Nigel.
  - Keep only a rule that improves or holds **both** boards; with 19 knives, one that helps only one board is tuned to these clips.
- **Verify:** Nigel plays both targets in the Live test on his phone and compares the scores with the board.
- **Save:** the new exact-score floors in `live_replay_test.dart`; unit tests for each case (side-on, end-on, shadow).

## Task 4: Docs and traceability
- **Status:** NOT STARTED
- **Depends on:** Task 3
- **Work:** Design Decisions → Throw Detection (entry point), Glossary (entry point, shadow), Known Issues; Traceability Agent over criteria 1–5.
- **Verify:** Nigel reads the summary.
- **Save:** story archived.

---

## Plan Changes Log

- **2026-10-13:** Task 2 paused after two colour approaches broke even (16 of 19); see Task 2. Nigel is asking his brother for new footage: boards closer together, filling more of the picture, in daylight or stronger light. Brief for him: https://claude.ai/artifact/DVB6Lo9EuPMe1ui5sHcAVk. Tasks 2 and 3 resume on that footage (a new Live test recording first).
- **2026-10-13:** Nigel approved option B ("do the rewind fix and option B"). Task 1's re-check was done by Nigel directly; the review sheet was dropped as no longer needed.

---

## Notes
- The recordings are face on (`isFaceOn`); the side-mount path (`GeometricEntryEstimator`) isn't changed by this story.
- Rings are ~18 px wide on board 1 at 322 px, so a few pixels of error moves a score.
