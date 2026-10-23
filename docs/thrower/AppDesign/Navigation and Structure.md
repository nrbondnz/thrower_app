---
tags: [design]
---

# Navigation and Structure

Part of [[App Design Index]]. Code: `lib/ui/app_shell.dart` (`AppShell`, `openScreen`), `throw_screen.dart`, `setup_screen.dart`. **Status:** built 2026-10-23 (Task 4).

## The Bottom Bar

Nigel, 2026-10-23: a bottom bar, as the template suggests, in place of Home's column of buttons.

- **Home**
- **Throw**
- **History**
- **Setup**

## What's Under Each Tab

### Home
- The hero: THROWER, the target, the tagline.
- The last session.
- **Start throwing** (the one main action).
- Quick actions: cards for the ways to throw.
- See [[Home Screen]].

### Throw
A card for each way to throw:
- **Rounds:** Play's setup (1 or 2 throwers, 1 or 2 targets, and Which game?, including Ranked).
- **Quick draw:** two throwers on a start signal.
- **Leaderboard** (iPhone only): Game Center's ranked table.

### History
- The stats over the kept sessions.
- The sessions, newest first, as before (tap one for every round).
- See [[History and Stats]].

### Setup
In this order, as built:
- **Instructions** (under Help).
- **Appearance:** Phone, Light or Dark ([[Colour and Themes]]).
- **Tools:** Calibrate target, Live test, Scoring test target: the technical tools, together and out of the way.
- **Account**, in a build with accounts (it was on Home's app bar).

## Throwing Screens Cover the Bar

Play, Quick draw and the tools open over the whole screen, as now, with Back to return. The bar isn't shown while throwing: the picture and scores get all the room.
