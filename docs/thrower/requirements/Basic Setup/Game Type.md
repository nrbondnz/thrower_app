---
tags: [requirement, basic-setup]
status: built
---

# Game Type

Part of [[Requirements Index]] → Basic setup. **Status:** ✅ Built (device checks to come where noted)

## What's Wanted
The players choose the kind of game: **scoring** (rounds of throws, the highest total wins) or **Quick draw** (two throwers on a start signal, the fastest to stick wins).

**More game types (Nigel, 2026-10-20):**
- **Precision:** 7 rounds of 3 knives (21), each round thrown from its own distance. In competition the whole set is thrown **4 times** ("a marathon", 84 knives).
- **Three targets** (Nigel's name for now, in place of "Multi"): three 5-ring boards side by side; each round a thrower throws one knife at each target, in order.
- Both: 1 or 2 players taking turns, KATTA scoring, the highest total wins.

## What Exists Today
- **Home → Play:** scoring games. The setup screen chooses **1 or 2 players**, and for 2, **1 target** (turns) or **2 targets** (at once), and the game length ([[story-checkpoint-players-and-targets]]; device checks M0–M9 to come).
- **Home → Quick draw:** the live duel: tap both boards (drag an outline into place if needed; **Adjust boards** later: [[story-checkpoint-adjust-boards]]) and lock them, a starter taps Start, five beeps, a random pause, the long beep is go; a match of 3 rounds ([[story-checkpoint-live-quick-draw]], [[story-checkpoint-quick-draw-match]]; device checks Q0–Q8, QM0–QM6 to come).
	- **Draw round the boards** (Mark, 2026-10-21, [[story-checkpoint-quick-draw-areas]]; built, device checks QA0–QA7 to come): instead of tapping, draw a finger round each board on the screen. Any knife that sticks inside counts; only the time decides (no score), so the same frame is a drawn round. For boards whose rings the app can't find. Kept for the session; on both Quick draw screens, not two-target Play (it needs scores).
- **Precision and Three targets** (built 2026-10-20, [[story-checkpoint-more-game-types]]; device checks GT0–GT9 to come): chosen under **Which game?** first on Play's setup screen. Scored **by hand on a score pad** (5 to 1, or Miss), no camera yet. 1 or 2 players taking turns.
	- **Precision:** 7 rounds of 3, from **3, 5, 7, 3, 4, 5, 7 m** (Nigel's guess; to confirm); the screen says where the next knife is thrown from ("Round 2 of 7: from 5 m").
	- **Three targets:** 3, 5 or 7 rounds; the screen says which target the next knife goes at ("Round 1 of 3: at target 2").
	- Kept in History with the game's name, and Precision's rounds with their distances; backed up when signed in.
- All of them use the same player names, if given ([[Player Names]]): on Play's setup screen, or **Names** on Quick draw.
- **Live test** (Home) plays both on recordings, for testing without throwing.

## Open Questions
- **Precision's distances:** Nigel listed eight (3, 5, 7, 3, 4, 5, 6, 7 m) for seven rounds; the app uses his guess at seven (3, 5, 7, 3, 4, 5, 7). To confirm (backlog #18).
- **The Precision marathon:** the set thrown 4 times (84 knives) in competition. Backlog #16.
- **The camera** for Precision and Three targets: today they're scored by hand. Precision moves the thrower (one target, several distances); Three targets needs three boards in view. Backlog #17.
- **Three targets' real name** (Nigel's name for now). Backlog #18.
- Other game types later (e.g. walk-back, from the KATTA / European events)?

## Related
- [[Round Play]]
- [[Number of Rounds]]
- [[Design Decisions]] → Quick Draw sections (including Quick Draw: Draw Round the Boards); Adjust Each Board; More Game Types: Precision and Three Targets
