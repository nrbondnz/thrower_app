---
tags: [design]
---

# Navigation and Structure

Part of [[App Design Index]]. Code: `lib/ui/app_shell.dart` (`AppShell`, `openScreen`), `leaderboards_screen.dart`, `setup_screen.dart`. **Status:** built 2026-10-23 (Task 4); Throw became Leaderboards later that day ([[story-checkpoint-posting-from-history]]).

## The Bottom Bar

Nigel, 2026-10-23: a bottom bar, as the template suggests, in place of Home's column of buttons.

- **Home**
- **Leaderboards** (was **Throw** until 2026-10-23)
- **History**
- **Setup**

Nigel, 2026-10-23: "rather than 'Throw' at the menu put online leaderboards." The ways to throw were already on Home.

## What's Under Each Tab

### Home
- The hero: THROWER, the target, the tagline.
- The last session.
- **Start throwing** (the one main action).
- **Throwing types** (was Quick actions): cards for the ways to throw, Rounds and Quick draw.
- See [[Home Screen]].

### Leaderboards
`LeaderboardsScreen`: a card for each leaderboard (`Leaderboard`, by its `title` and `about`).
- For now one: **3 m knives · 3 × 5** (Game Center's `ranked.3m.5x3`, weekly). Tapping it opens Game Center's board (iPhone).
- On Android: "Leaderboards are on the iPhone (Game Center) for now."
- A line under them: more to come (your friends, your area, your club).
- The old Throw tab's Rounds and Quick draw cards are on Home (Throwing types).

### History
- The stats over the kept sessions.
- The sessions, newest first, as before (tap one for every round).
- See [[History and Stats]].

### Setup
In this order, as built:
- **Instructions** (under Help).
- **Appearance:** Phone, Light or Dark ([[Colour and Themes]]).
- **Tools:** Calibrate target; in test builds, Live test (only where the recordings are: the beta flavor) and Scoring test target. The technical tools, together and out of the way.
- **Test sessions** (test builds only: the beta flavor, debug, or `THROWER_TEST_TOOLS`; never the store flavor): Add 10 test sessions, Remove test sessions.
- **Account**, in a build with accounts (it was on Home's app bar).

## Throwing Screens Cover the Bar

Play, Quick draw and the tools open over the whole screen, as now, with Back to return. The bar isn't shown while throwing: the picture and scores get all the room.
