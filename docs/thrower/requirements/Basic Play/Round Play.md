---
tags: [requirement, basic-play]
status: built
---

# Round Play

Part of [[Requirements Index]] → Basic play. **Status:** ✅ Built (device checks to come where noted)

## What's Wanted
A scoring game is played in rounds of throws, on one target or two. Child pages: [[One Target]], [[Two Targets]].

## What Exists Today
- A round is **3 throws**. The camera watches the board: each knife that sticks is scored where the blade went in; a bounce-out scores 0. **Collecting the knives** (someone at the board) closes the round, and the next one shows straight away.
- **Round done** (2026-10-23): when nothing is collected (three bounce-outs), Play shows **Round done** once the round has all its throws. On one target with two players it passes the turn; on two targets it shows once both have finished. A **Ranked** round moves on by itself after its 3rd throw. Why: [[Design Decisions]] → Rounds Move On: Round Done.
- Play shows each round's throws as big slots that can be tapped to correct a score ([[story-checkpoint-score-corrections]]), the totals, and at the end the winner (players by name if named: [[Player Names]]); finished games go to **History** ([[story-checkpoint-game-history]]).
- **Precision and Three targets** are played in rounds of 3 too, but scored by hand on a score pad (no camera yet): [[Game Type]], [[story-checkpoint-more-game-types]].
- Safety: the app can't tell whether the lane is clear; nothing it shows means it's safe to go forward.

## Open Questions
- None yet.

## Related
- [[One Target]]
- [[Two Targets]]
- [[Design Decisions]] → Throw Detection: Before/After Comparison, Rounds and Scoring, Score Corrections, Named Players, Rounds Move On: Round Done
- [[Data Flow]]
