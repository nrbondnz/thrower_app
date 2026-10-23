---
tags: [requirement, game-centre]
status: partly-built
---

# Rankings

Part of [[Requirements Index]] → Game Centre. **Status:** 🟡 Partly built: the first step, a weekly Game Center leaderboard for one ranked game (monthly until Nigel set it up weekly, 2026-10-23), built on the PC 2026-10-22; waiting for the Mac and App Store Connect, then device checks ([[story-checkpoint-game-center-scores]])

## What's Wanted
Players are ranked against throwers across the UK and further: **daily**, **weekly** and **monthly**.

## Decided (Nigel, 2026-10-22)
- **First step:** post scores for one ranked game, **5 rounds of 3 knives from 3 m**, to an Apple Game Center leaderboard that restarts each week (Nigel, 2026-10-23; first planned monthly): [[story-checkpoint-game-center-scores]].
- **Strict mode:** a game that can be posted can't have a score raised by hand: a throw can only be marked a bounce-out (0), and a throw the camera missed only added as 0.
- **Full games only:** a game finished early can't be posted.
- **Android:** not postable for now (Game Center is iPhone only): backlog #21, perhaps the app's own leaderboard on the website.
- **Tables** (this week's best, last week's results, now the leaderboard is weekly): backlog #22.

## Decided (Nigel, 2026-10-23): Posting From History
- **Each History result** says **Can be posted**, **Posted** or **Cannot be posted**.
- **Post later from History,** but only a session thrown in **this leaderboard week**.
- **A normal 5 × 3 session** (Scoring, 5 rounds, one thrower) can be posted too, if **no score was set or added by hand**. Posting asks "I threw from 3 m".
- **Leaderboards** is a tab, in place of Throw. One board for now, **3 m knives · 3 × 5**; more later (friends, area, club).
- **Test sessions** for checking posting, in test builds only.
- Story: [[story-checkpoint-posting-from-history]].

## What Exists Today
- **Ranked: 5 × 3 at 3 m** (`GameType.ranked`; [[Game Type]]): under Which game? on Play's setup; one player, 5 rounds of 3, scored by the camera; **I'm throwing from 3 m** must be ticked before Start; Play's title "Ranked · 3 m".
- **Strict mode** (`GameType.strict`; [[Scoring Rules]]): a score can only be changed to 0, and a missed throw only added as 0; the rules refuse anything else (`Match.setScore`, `byHand`, `addToRound`).
- **Full games only** (`Match.postable`): Finish game early, and it can't be posted.
- **A normal 5 × 3 session** (2026-10-23): `Match.postable` also takes Scoring with 5 rounds and no `Match.changedByHand`. Post score then waits for **I threw from 3 m** (`ThreeMetreTick`).
- **Posting status in History** (2026-10-23, `postStatusOf` in `lib/history/post_status.dart`): each card shows `PostStatusLabel`; a session's page (`HistoryPostPanel`) shows why it can't be posted, or **Post score** (iPhone). Only this leaderboard week's sessions (`sameWeek`, `lib/leaderboard/leaderboard_week.dart`; the start, 2026-10-23 00:00 UTC, to confirm on the Mac).
- **Posted is kept** with the session (`GameRecord.posted`), after a post at the end (`GameNotifier.keepPosted`) or from History (`markedPosted`).
- **Leaderboards tab** (`LeaderboardsScreen`): **3 m knives · 3 × 5** (`Leaderboard.title`); opens Game Center's board; on Android, "on the iPhone for now".
- **Test sessions** (`makeTestSessions`): Setup → Test sessions → Add 10 or Remove, in debug and `THROWER_TEST_TOOLS` builds only. They post only to a separate test leaderboard, `test.ranked.3m.5x3` (`leaderboardFor`), never live, and are never backed up (Review Agent, 2026-10-23: TestFlight has no Game Center sandbox).
- **Rounds move on by themselves** (2026-10-23, `GameType.movesOnByItself`): after a round's 3rd knife the next round starts, with no collecting, so three bounce-outs don't stall the game. Why: [[Design Decisions]] → Rounds Move On: Round Done.
- **Post score** and **View leaderboard** at the end of a full ranked game (`PostScorePanel`, `ScorePostNotifier`), iPhone only: posts the total (0–75) once to Game Center's `ranked.3m.5x3` leaderboard (`GameCenterLeaderboardService`, behind `LeaderboardService`); says whether it went (posted, sign in to Game Center, couldn't post: Try again). Once posted, the game's scores are locked.
- **The leaderboard** restarts each week (recurring, set up by Nigel in App Store Connect on 2026-10-23, 1-week duration: [[Mac Handoff]] → Game Center setup). View leaderboard opens Apple's own screen.
- **Android:** no Post score (backlog #21). **Instructions:** a *Ranked games* section ([[Instructions and Safety]]).
- **Not yet:** the Game Center setup on the Mac and in App Store Connect, the TestFlight check (device checks RK0–RK10, RD0 and PH0–PH13 in [[Device Test Plan]]), tables in the app (backlog #22), daily and weekly rankings, ranking iPhone and Android together (needs the app's own backend: [[Accounts Roadmap]] stage 6).
- **Why each choice:** [[Design Decisions]] → Ranked Games and Game Center (2026-10-22), and Posting From History (2026-10-23).

### Daily Ranking
- To be defined.

### Weekly Ranking
- To be defined. The weekly top rank wins a prize: [[Competitions and Prizes]].

### Monthly Ranking
- **First step built** (2026-10-22): the Game Center leaderboard for Ranked: 5 × 3 at 3 m restarts each week (set up weekly on 2026-10-23; first planned monthly); Apple keeps each week's results. Showing this week's and last week's tables in the app: backlog #22. A monthly ranking would need a second leaderboard.

## Open Questions
- **What is ranked:** a game's total (per game length: 3, 5 or 9 rounds), an average per throw, Quick draw times and wins, or several tables?
- **Fairness:** throwers' boards, distances and lighting differ, and the phone scores the throw. Should ranked games need a standard setup (KATTA distance, board size, a calibrated target)?
- **Trust:** answered for the first step (strict mode, full games only, 3 m on the thrower's word). Still open: is video evidence needed for top places?
- **Periods:** whose day/week/month (UK time, or each player's own)? Best game in the period, or a total?
- **Groups:** everyone, or by country, region, club, age or level?
- Apple Game Center and Google Play Games each cover one platform only: own leaderboards (the app's backend) to rank iPhone and Android together.

## Related
- [[Competitions and Prizes]]
- [[story-checkpoint-game-center-scores]]
- [[story-checkpoint-posting-from-history]]
- [[Design Decisions]] → Ranked Games and Game Center; Posting From History
- [[Accounts Roadmap]] → Stage 6
- [[Remote Play]]
