---
tags: [design]
---

# Components

Part of [[App Design Index]]. Code: `lib/ui/theme/` (`app_theme.dart`, `widgets.dart`).

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

## Stat Tile

- `StatTile`: a big number with a small label under it ([[Typography and Numbers]]).
- Used on Home's last-session card and History's stats.

## Target Mark

- `TargetMark`: the board drawn small (the painted red and wood rings), as the app's mark.
- Used in Home's hero. Later, on session summaries and the score panel ([[Throwing Screens]] → Later).

## Main Button

- One per screen at most: Home's **Start throwing**.
- Full width, tall (56), amber, bold capitals.

## Section Heading

- `SectionHeading`: small, bold, spaced capitals ("QUICK ACTIONS", "TOOLS") above a group.
