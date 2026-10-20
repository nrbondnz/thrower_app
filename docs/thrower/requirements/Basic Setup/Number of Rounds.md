---
tags: [requirement, basic-setup]
status: built
---

# Number of Rounds

Part of [[Requirements Index]] → Basic setup. **Status:** ✅ Built (device checks to come where noted)

## What's Wanted
The players choose how long a game is.

## What Exists Today
- **Play:** **3, 5 or 9 rounds** on the setup screen (9 unless chosen), **3 throws a round** (`gameLengthProvider`; [[story-checkpoint-instructions-and-game-length]] and backlog #5, 2026-10-16).
- **Precision:** **7 rounds** of 3, fixed (one round per distance); **Three targets:** **3, 5 or 7 rounds** (7 unless chosen). Each game type offers its own lengths (`GameType.roundChoices`); switching type moves an unoffered length to the type's default ([[story-checkpoint-more-game-types]], 2026-10-20; device checks to come).
- **Quick draw:** a match of **3 rounds**, with extra rounds if level ([[story-checkpoint-quick-draw-match]]; device checks QM0–QM6 to come).
- A game can be ended early: [[Ending Early]].

## Open Questions
- Other lengths, or throws per round other than 3?
- For rankings, which lengths count (see [[Rankings]])?
- Precision's marathon: the 7-round set thrown 4 times (backlog #16).

## Related
- [[Design Decisions]] → Rounds and Scoring; Quick Draw: Go, False Starts and the Winner (the match); More Game Types: Precision and Three Targets
- [[Game Type]]
- [[Ending Early]]
