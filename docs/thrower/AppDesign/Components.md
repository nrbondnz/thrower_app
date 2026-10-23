---
tags: [design]
---

# Components

Part of [[App Design Index]]. Code: `lib/ui/theme/` (`app_theme.dart`, `widgets.dart`). **Status:** built 2026-10-23 (Task 4).

## Card

The template's card, in place of a plain button:

```text
┌─────────────────────┐
│ QUICK DRAW          │
│ Head to head        │
└─────────────────────┘
```

- `ActionCard`: an icon, a title in capitals, and a short line under it. The whole card can be tapped.
- Surface colour, rounded corners (16), no shadow in the dark theme.
- Also used for each board on the Leaderboards tab (`LeaderboardsScreen`).

## Stat Tile

- `StatTile`: a big number with a small label under it ([[Typography and Numbers]]).
- `StatRow`: a row of stat tiles, evenly spread.
- Used on Home's last-session card and History's stats.

## Target Mark

- `TargetMark`: the board drawn small (the painted red and wood rings), as the app's mark.
- Used in Home's hero. Later, on session summaries and the score panel ([[Throwing Screens]] → Later).

## Post Status Label

- `PostStatusLabel`: a small icon and bold label, **Can be posted** (amber), **Posted** (green) or **Cannot be posted** (grey); "Test ·" in front for a test session.
- Used on each History card and in `HistoryPostPanel` ([[History and Stats]]).

## Three Metre Tick

- `ThreeMetreTick`: "I threw from 3 m (board to throwing line)", a tick box shown before Post score for a normal 5 × 3 session.
- Used at the end of a session (`PostScorePanel`, dark) and on a session's page (`HistoryPostPanel`).

## Main Button

- One per screen at most: Home's **Start throwing**.
- Full width, tall (56), amber, bold capitals.

## Section Heading

- `SectionHeading`: small, bold, spaced capitals ("THROWING TYPES", "TOOLS", "TEST SESSIONS") above a group.
