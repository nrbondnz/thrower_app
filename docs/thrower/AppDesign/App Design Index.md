---
tags: [design, index]
---

# App Design Index

How the Thrower App should look and feel. Nigel's starting point (2026-10-23) was a single page, `AppDesign.md`, a template "for getting to a better looking app". It's now this index plus a child page for each part of the design. The content of the template is kept, spread over the pages below, and expanded.

The work to build it: [[story-checkpoint-app-design]].

## The Aim in One Line

> AI automatically detects knife and axe impacts on a real target and scores them instantly.

The app should make that obvious from the moment it opens. It should feel like **a professional throwing sports scoring system**, not a camera calibration utility.

## Pages

- [[Goals and Problems]]: what's wrong with the look today, and what the redesign is for.
- [[Brand and Voice]]: the name (THROWER), how the app talks ("throwing", not "playing a game"), and the inspiration (archery and shooting apps, Strava).
- [[Colour and Themes]]: the charcoal and amber palette, light and dark modes, and why the camera screens stay dark.
- [[Typography and Numbers]]: fonts, bold headings, and big numbers as the visual focus.
- [[Navigation and Structure]]: the bottom bar (Home, Leaderboards, History, Setup) and what lives under each.
- [[Home Screen]]: the hero, the last-session card, Start throwing, and the Throwing types cards.
- [[Throwing Screens]]: Play and Quick draw, built round the camera picture and what the AI saw.
- [[History and Stats]]: the stats over kept games, how each is worked out, and the list of sessions.
- [[Components]]: cards, stat tiles, the target mark and buttons, shared by every screen.
- [[Competition Feel]]: personal bests, badges and streaks (later).

## Status

- **Built 2026-10-23** ([[story-checkpoint-app-design]], Tasks 1–6; device checks AD0–AD11 to come):
  - light and dark themes, with Setup → Appearance; the camera screens always dark;
  - the bottom bar (Home, Throw, History, Setup), the new Home, Throw and Setup;
  - each knife kept with a session, and the stats on History and Home;
  - one thrower's total shown large on Play.
- **Changed 2026-10-23** ([[story-checkpoint-posting-from-history]], Tasks 1–4; device checks PH0–PH13):
  - Throw became **Leaderboards**; Home's Quick actions became **Throwing types**;
  - each History card says Can be posted, Posted or Cannot be posted;
  - Setup → Test sessions in test builds.
- **Requirements:** [[Look and Feel]], [[Throwing Stats]], [[Rankings]].
- **Later:** the throwing screens' new look beyond colours and numbers, badges, charts, a custom font.

## Decisions (Nigel, 2026-10-23)

- **Light and dark:** follow the phone, with an Appearance setting (Phone, Light, Dark). The camera screens stay dark in both.
- **Navigation:** a bottom bar, as the template suggests.
- **Words:** throwers don't think of themselves as playing a game. "Start throwing", not "Start match" or "Play".
- **Stats:** the total, best, 5s, hit rate and **average per knife**.
- **Name in the hero:** THROWER.

Related: [[Requirements Index]], [[Design Decisions]], [[Architecture Index]].
