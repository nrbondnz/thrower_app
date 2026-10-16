# Story Checkpoint: Score Corrections

## Story Goal
Any throw's score in the game being played can be **changed by hand**, and a throw the camera **didn't see** (a knife that missed the board altogether, or a stuck knife it didn't register) can be **added**, from a 0–5 popup, without jogging the camera. Nigel, 2026-10-17: "there could be times when a thrower misses the target alltogether, and possibly where they dispute the scoring so each score should be able to be pressed on giving a popup of 0-5 possible (hopefully without jogging the camera)". Follows [[story-checkpoint-game-history]] (a corrected game is kept with its corrected scores).

## Complexity Score
6 (Large): scoring → game wiring → UI → vision (the moved-camera check) (4 layers), a data change (`ThrowRecord`, `Match`) (1), physical safety: someone at the phone mid-game (Review Agent §7) (1).

## Status
PLANNED (2026-10-17): waiting for Nigel's approval of the plan. Answered 2026-10-17, all as recommended (below).

## Answered (2026-10-17)
1. **Which scores:** any round of the game being played. The round in progress shows each throw as a big tappable score below the picture; tapping an earlier round's total opens its throws. (Not History: it keeps only round totals.)
2. **Misses:** each round shows its 3 slots (4 · – · –); tapping an **empty slot** opens the same popup: **0** records a miss, **1–5** adds a stuck knife the camera didn't register.
3. **Camera jog:** big targets **below** the picture, never on it; **watching pauses** while the popup is open (a hand isn't a throw); afterwards the app **checks the picture still lines up** with the locked rings and says "The phone may have moved: re-calibrate" if not.

## Acceptance Criteria
1. Tapping a throw's score (this round or an earlier one) opens a popup of 0, 1, 2, 3, 4, 5 and Cancel; the choice replaces the score, and the round, game and player totals follow.
2. Tapping an empty slot of the round in progress (or of an earlier round collected early) adds a throw with the chosen score; 0 is a miss. On one target it counts for the player whose turn it is, and the turn passes after the 3rd throw as usual.
3. A corrected game that is over is kept in History with the corrected scores (once; replacing the kept record). Adding the last throw of the last round ends the game as a detected throw would.
4. While the popup is open, nothing the camera sees is scored; watching resumes when it closes.
5. After a correction, if the picture no longer lines up with the locked rings, Play says so and suggests re-calibrating; a light tap that doesn't move the phone says nothing.
6. The Instructions say: change a score only when no one is throwing; tap lightly; the phone stays out of the line of throw; re-calibrate if told the phone moved.
7. Corrected throws are marked on Play (so a dispute's result can be seen), and a knife that later falls out still scores 0.

## Story Plan

### Task 1: The rule: set or add a throw's score
- **Work:** `GameSession.setScore(round, throw, score)` and adding a throw to a round (a manual throw, `ThrowRecord.corrected`); `Match.setScore(player, round, throw, score)` and a manual throw at the round in progress (one target: the player whose turn it is, counting toward the turn); `GameNotifier.correct(…)`, re-saving a finished game through `_keep`. Scores 0–5 from the `TargetModel`'s rings.
- **Verify:** tests (change a stuck score; a bounce-out to 3; add a miss to a round in progress; add the last throw of the game and it ends; a correction after the end re-saves the same record; a later fall-out zeroes a corrected throw).
- **Next:** Task 2.

### Task 2: Tappable scores and the 0–5 popup on Play
- **Work:** both Play screens: the round in progress as 3 big score slots below the picture (both players' on two targets); earlier rounds' totals tappable → that round's throws; the popup (0–5 as large buttons, Cancel); watching paused while it's open (`ThrowWatcher` stopped and restarted, so the reference picture is taken afresh); corrected scores marked (e.g. a ✎ or a different colour) on the slots and on the picture's score circles.
- **Verify:** widget tests. Nigel: Live test → Target 1 → Play: change a score, add a miss, and watch the totals.
- **Next:** Task 3.

### Task 3: Did the phone move? The check after a correction
- **Work:** after the popup closes, compare the next settled frame with the picture from before it opened, over the board and its surroundings: a whole-picture shift means the phone moved ("The phone may have moved: re-calibrate"); a knife-sized change does not. Measured on renders with the camera nudged by small amounts (`SyntheticScene`) and on the Live test footage, so the threshold has a reason.
- **Verify:** fixture tests (nudged vs not); Nigel taps the phone lightly on its stand, then knocks it.
- **Next:** Task 4.

### Task 4: Instructions, docs, device checks, traceability
- **Work:** the in-app Instructions (when to touch the phone; misses; disputes); **Review Agent §7** (someone at the phone mid-game, beside the lanes); Design Decisions, Glossary, Data Flow, System Diagram, web pages; Device Test Plan checks; Traceability Agent; backlog.
- **Verify:** Nigel reads the instructions; the checks are ready.

---

## Plan Changes Log
- **2026-10-17:** Planned from Nigel's request; three questions answered as recommended.

## Notes
- **Safety:** this is the first feature that invites someone to the phone during a game. The phone is beside the lane (Play: 2 m from the board, 45° to one side; two targets: behind the throwers), so the Instructions must say only when no one is throwing, and the Review Agent checks the wording (§7).
- Not in this story: correcting kept games in History (round totals only), a note of who disputed what, Quick draw (a duel has one throw each and its own result).
