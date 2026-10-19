---
tags: [requirement, basic-setup]
status: built
---

# Game Type

Part of [[Requirements Index]] → Basic setup. **Status:** ✅ Built (device checks to come where noted)

## What's Wanted
The players choose the kind of game: **scoring** (rounds of throws, the highest total wins) or **Quick draw** (two throwers on a start signal, the fastest to stick wins).

## What Exists Today
- **Home → Play:** scoring games. The setup screen chooses **1 or 2 players**, and for 2, **1 target** (turns) or **2 targets** (at once), and the game length ([[story-checkpoint-players-and-targets]]; device checks M0–M9 to come).
- **Home → Quick draw:** the live duel: tap both boards (drag an outline into place if needed; **Adjust boards** later: [[story-checkpoint-adjust-boards]]) and lock them, a starter taps Start, five beeps, a random pause, the long beep is go; a match of 3 rounds ([[story-checkpoint-live-quick-draw]], [[story-checkpoint-quick-draw-match]]; device checks Q0–Q8, QM0–QM6 to come).
- Both use the same player names, if given ([[Player Names]]): on Play's setup screen, or **Names** on Quick draw.
- **Live test** (Home) plays both on recordings, for testing without throwing.

## Open Questions
- More game types later (e.g. walk-back, from the KATTA / European events: 3 throws from each of several distances)?

## Related
- [[Round Play]]
- [[Number of Rounds]]
- [[Design Decisions]] → Quick Draw sections; Adjust Each Board
