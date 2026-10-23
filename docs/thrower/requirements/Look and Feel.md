---
tags: [requirement, across-the-app, design]
status: built
---

# Look and Feel

Part of [[Requirements Index]] → Across the app. **Status:** ✅ Built 2026-10-23 (device checks AD0–AD7 and AD10 to come)

## What's Wanted
Nigel, 2026-10-23: a better-looking app, "functional first, but nicer looking", with a light and dark mode.

- It should feel like a professional throwing sports scoring system, not a camera calibration utility ([[Goals and Problems]]).
- The main thing to do (throwing) is obvious; the technical tools are out of the way.
- Light and dark: follow the phone, with a setting to override it.
- The camera screens read well from the throwing line.
- New words talk about throwing and sessions, not games ([[Brand and Voice]]).

## What Exists Today
- **The design:** [[App Design Index]] and its child pages.
- **Themes** ([[Colour and Themes]]): charcoal and amber, light and dark (`AppTheme`, `AppPalette`). **Setup → Appearance:** Phone, Light or Dark, kept on the phone (`FileAppearanceStore`). The camera screens are always dark (`CameraTheme`).
- **A bottom bar** ([[Navigation and Structure]]): Home, Leaderboards, History, Setup (`AppShell`; Leaderboards replaced Throw on 2026-10-23, [[story-checkpoint-posting-from-history]]).
- **Home** ([[Home Screen]]): the target, THROWER, the tagline, the last session, START THROWING, and Rounds and Quick draw cards.
- **Leaderboards:** "3 m knives · 3 × 5" (Game Center, iPhone). Rounds and Quick draw are Home's **Throwing types**.
- **Leaderboard table** (2026-10-23, [[story-checkpoint-monthly-tables]]): `LeaderboardTableScreen`, with **This week** and **Last week** tabs, your row marked, and **Open in Game Center**. From the Leaderboards card and View leaderboard ([[Rankings]]).
- **Setup:** Help and support (Instructions, Support, Help online, Privacy Policy, Terms of Service, Delete account; [[story-checkpoint-compliance]], 2026-10-23), Appearance, the tools (Calibrate target; Live test and Scoring test target in test builds only, 2026-10-23, [[story-checkpoint-store-release-hygiene]]), Account.
- **Play:** one thrower's total shown large, above the round ([[Throwing Screens]]).
- **Play's panel** (2026-10-23): on Play and two-target Play, the panel under the camera is at most 65% of the screen. The scores scroll; Round done, Post score, New game and the board buttons stay in sight. Device checks SF0–SF1.
- **History:** Clear history is a bin icon (tooltip "Clear history"), so it fits with large text (2026-10-23).
- Built in [[story-checkpoint-app-design]]. Why: [[Design Decisions]] → App Design: Themes, Tabs and Stats.

## Open Questions
- The words "Which game?" and "Game over": change them to throwing words, with the Instructions and device checks?
- A bundled font (Inter), or keep the phone's own?
- Badges, personal bests and streaks ([[Competition Feel]]).

## Related
- [[Throwing Stats]]
- [[Instructions and Safety]]
