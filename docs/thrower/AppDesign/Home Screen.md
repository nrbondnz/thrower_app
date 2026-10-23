---
tags: [design]
---

# Home Screen

Part of [[App Design Index]]. Code: `lib/ui/home_screen.dart` (`HomeScreen`, `LastSessionCard`, `lastSessionTiles`). **Status:** built 2026-10-23 (Task 4).

## Hero

In place of the title "Thrower App":

```text
   (target)
  THROWER
Every throw seen. Every score counted.
```

- The target is drawn by the app (the board's own red and wood rings), not an emoji.
- It says what the app does: the camera sees and scores each throw.

## Last Session

A card with the last session kept on the phone:

```text
LAST SESSION
Ranked · 21 Oct, 14:32
  52          3.5         4
Points     Per knife     5s
                See history →
```

- **As built:** the kind is `GameType.label` (Scoring, Precision, Three targets, Ranked) and the time is History's `whenText`, not "2 days ago".
- One thrower: Points, Per knife and 5s (Per knife and 5s only for a session kept with each knife). Two: each thrower's total, in player order.
- Live test sessions aren't shown.
- Before the first session: "Your sessions will show here."
- Tapping it opens History.
- Each number is worked out as in [[History and Stats]].

## The Main Action

```text
[ START THROWING ]
```

Large, bold, full width. It opens Play's setup. Nothing else on Home looks like it.

## Quick Actions

Cards, not a stack of buttons:

```text
Quick actions
  ROUNDS            QUICK DRAW
  1 or 2 throwers   Head to head
```

- **Rounds** opens Play's setup, as Start throwing does.
- **Quick draw** opens the live Quick draw.
- The tools aren't on Home. They're under Setup ([[Navigation and Structure]]).
