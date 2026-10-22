---
tags: [design]
---

# Home Screen

Part of [[App Design Index]]. Code: `lib/ui/home_screen.dart`.

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
Last session · Ranked · 2 days ago
  52          3.5         4
Points     Per knife     5s
                See history →
```

- One thrower: their total. Two: each thrower's total, the winner first.
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
  Rounds          Quick draw
  1 or 2          Head to head
  throwers        on a signal
```

- **Rounds** opens Play's setup, as Start throwing does.
- **Quick draw** opens the live Quick draw.
- The tools aren't on Home. They're under Setup ([[Navigation and Structure]]).
