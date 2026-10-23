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
- **A bottom bar** ([[Navigation and Structure]]): Home, Throw, History, Setup (`AppShell`).
- **Home** ([[Home Screen]]): the target, THROWER, the tagline, the last session, START THROWING, and Rounds and Quick draw cards.
- **Throw:** Rounds, Quick draw, and Leaderboard on the iPhone.
- **Setup:** Instructions, Appearance, the tools (Calibrate target, Live test, Scoring test target), Account.
- **Play:** one thrower's total shown large, above the round ([[Throwing Screens]]).
- Built in [[story-checkpoint-app-design]]. Why: [[Design Decisions]] → App Design: Themes, Tabs and Stats.

## Open Questions
- The words "Which game?" and "Game over": change them to throwing words, with the Instructions and device checks?
- A bundled font (Inter), or keep the phone's own?
- Badges, personal bests and streaks ([[Competition Feel]]).

## Related
- [[Throwing Stats]]
- [[Instructions and Safety]]
