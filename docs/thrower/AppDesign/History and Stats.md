---
tags: [design]
---

# History and Stats

Part of [[App Design Index]]. Code: `lib/history/throw_stats.dart` (`ThrowStats`), `lib/ui/history_screen.dart` (`StatsCard`). **Status:** built 2026-10-23 (Tasks 3 and 5).

## The Stats

Nigel, 2026-10-23: the total, best, 5s, hit rate, and **average per knife**. History shows them above the list of sessions:

```text
 12           178         3.4
Sessions    Knives     Per knife

 41          88%          52
 5s        Hit rate    Best ranked
```

## How Each Is Worked Out

- They're over the sessions kept on this phone, every thrower's knives together.
- Sessions played on a Live test recording aren't counted.
- Test sessions (Setup → Test sessions, in test builds) aren't counted either ([[story-checkpoint-posting-from-history]]).
- **Sessions:** how many are kept.
- **Knives:** how many were thrown.
- **Per knife:** points ÷ knives, to one decimal place (0.0 to 5.0). It compares sessions of any length.
- **5s:** knives in the bull (the inner ring).
- **Hit rate:** knives that scored (1 or more) ÷ knives thrown, as a percentage. A bounce-out, a knife that fell out and a miss count as thrown but not hit.
- **Best ranked:** the best Ranked total (out of 75). Shown once there's a ranked session.
- **Best round:** the best round total (out of 15). Shown when there's no ranked session yet.

## Sessions Kept Before the Knives Were

Until this story (2026-10-23), a kept session had only its round totals, not each knife. Those sessions count towards Sessions and Best, but not towards Knives, Per knife, 5s or Hit rate. When some are left out, a note under the stats says: "Knives, per knife, 5s and hit rate: from the N of M sessions kept with each knife."

## The List

- Newest first, as before, under a SESSIONS heading. Each session is a card: when (bold), then how it was played and the result (`summaryText`).
- Tap one for every round, as now.
- **Posting status** (2026-10-23, [[story-checkpoint-posting-from-history]]): each card ends with **Can be posted**, **Posted** or **Cannot be posted** (`PostStatusLabel`), with "Test ·" in front for a test session.
- A session's page has the status, "Why: …" when it can't be posted, and **Post score** on the iPhone (`HistoryPostPanel`). The rules: [[Design Decisions]] → Posting From History.

## Later

- A trend: the last 10 sessions' per-knife average as a small chart.
- Stats for one thrower (by name).
- Weekly stats, to go with the weekly leaderboard.
