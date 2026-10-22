---
tags: [requirement, game-centre]
status: planned
---

# Rankings

Part of [[Requirements Index]] → Game Centre. **Status:** 🗺️ Planned: first step [[story-checkpoint-game-center-scores]] (2026-10-22)

## What's Wanted
Players are ranked against throwers across the UK and further: **daily**, **weekly** and **monthly**.

## Decided (Nigel, 2026-10-22)
- **First step:** post scores for one ranked game, **5 rounds of 3 knives from 3 m**, to an Apple Game Center leaderboard that restarts each month: [[story-checkpoint-game-center-scores]].
- **Strict mode:** a game that can be posted can't have a score raised by hand: a throw can only be marked a bounce-out (0), and a throw the camera missed only added as 0.
- **Full games only:** a game finished early can't be posted.
- **Android:** not postable for now (Game Center is iPhone only): backlog #21, perhaps the app's own leaderboard on the website.
- **Tables** (this month's best, last month's results): backlog #22.

## What Exists Today
- Nothing yet. Needs accounts, a backend and shared results ([[Accounts Roadmap]] stages 2–3, then stage 6).

### Daily Ranking
- To be defined.

### Weekly Ranking
- To be defined. The weekly top rank wins a prize: [[Competitions and Prizes]].

### Monthly Ranking
- To be defined.

## Open Questions
- **What is ranked:** a game's total (per game length: 3, 5 or 9 rounds), an average per throw, Quick draw times and wins, or several tables?
- **Fairness:** throwers' boards, distances and lighting differ, and the phone scores the throw. Should ranked games need a standard setup (KATTA distance, board size, a calibrated target)?
- **Trust:** scores can be **corrected by hand** today ([[Scoring Rules]]). Are corrected or finished-early games allowed in rankings? Is video evidence needed for top places?
- **Periods:** whose day/week/month (UK time, or each player's own)? Best game in the period, or a total?
- **Groups:** everyone, or by country, region, club, age or level?
- Apple Game Center and Google Play Games each cover one platform only: own leaderboards (the app's backend) to rank iPhone and Android together.

## Related
- [[Competitions and Prizes]]
- [[story-checkpoint-game-center-scores]]
- [[Accounts Roadmap]] → Stage 6
- [[Remote Play]]
