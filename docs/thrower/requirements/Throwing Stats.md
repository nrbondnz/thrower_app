---
tags: [requirement, across-the-app, stats]
status: built
---

# Throwing Stats

Part of [[Requirements Index]] → Across the app. **Status:** ✅ Built 2026-10-23 (device checks AD1, AD8 and AD9 to come)

## What's Wanted
Nigel, 2026-10-23: "the total, best, 5s, hit rate and average per knife", so a thrower can see how they're doing.

## What Exists Today
- **History's stats** (`StatsCard`), over the sessions kept on the phone:
  - Sessions, Knives, Per knife;
  - 5s, Hit rate, Best ranked (or Best round before a ranked session).
- **Home's last session** (`LastSessionCard`): one thrower's points, per knife and 5s; two throwers' points each.
- Worked out by `ThrowStats` (`lib/history/throw_stats.dart`). How each is worked out: [[History and Stats]].
- Every thrower's knives count together. Live test sessions don't count.
- Each knife's score is kept with a session from 2026-10-23 (`GameRecord.knives`, [[Game Recording]]). Older sessions count only towards Sessions and Best; a note says so.
- Built in [[story-checkpoint-app-design]] (Tasks 3 and 5). Why: [[Design Decisions]] → App Design: Themes, Tabs and Stats.

## Open Questions
- Stats for one thrower, by name?
- A trend (the last 10 sessions' per knife)?
- Weekly stats, with the weekly leaderboard ([[Rankings]])?
- Personal bests, like for like ([[Competition Feel]]).

## Related
- [[Game Recording]]
- [[Look and Feel]]
