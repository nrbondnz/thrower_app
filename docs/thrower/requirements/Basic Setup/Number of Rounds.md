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
- **Quick draw:** a match of **3 rounds**, with extra rounds if level ([[story-checkpoint-quick-draw-match]]; device checks QM0–QM6 to come).
- A game can be ended early: [[Ending Early]].

## Open Questions
- Other lengths, or throws per round other than 3?
- For rankings, which lengths count (see [[Rankings]])?

## Related
- [[Design Decisions]] → Rounds and Scoring; Quick Draw: Go, False Starts and the Winner (the match)
- [[Game Type]]
- [[Ending Early]]
