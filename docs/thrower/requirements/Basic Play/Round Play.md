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
- Play shows each round's throws as big slots that can be tapped to correct a score ([[story-checkpoint-score-corrections]]), the totals, and at the end the winner (players by name if named: [[Player Names]]); finished games go to **History** ([[story-checkpoint-game-history]]).
- Safety: the app can't tell whether the lane is clear; nothing it shows means it's safe to go forward.

## Open Questions
- None yet.

## Related
- [[One Target]]
- [[Two Targets]]
- [[Design Decisions]] → Throw Detection: Before/After Comparison, Rounds and Scoring, Score Corrections, Named Players
- [[Data Flow]]
