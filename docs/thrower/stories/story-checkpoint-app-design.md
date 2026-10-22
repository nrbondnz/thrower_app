# Story Checkpoint: App Design (a Better-Looking App)

## Story Goal
Nigel, 2026-10-23: "AppDesign.md … is a template for getting to a better looking app … Come up with a story and start executing the story … functional first, but nicer looking. Might need a light and dark mode too."

Give the app a look that says what it is, a throwing sports scoring system. The design is in [[App Design Index]] and its child pages.

## Decided (Nigel, 2026-10-23)
- **Themes:** follow the phone, with an Appearance setting (Phone, Light, Dark). The camera screens stay dark.
- **Navigation:** a bottom bar (Home, Throw, History, Setup).
- **Words:** "Start throwing", not "Start match" or "game": throwers don't think of themselves as playing a game.
- **Stats:** the total, best, 5s, hit rate and average per knife.
- **Name in the hero:** THROWER.

## Complexity Score
6 (Large): UI, history, settings (3 layers); the game record's format (1); themes as a branch (1); more than 3 acceptance criteria (1).

## Status
IN PROGRESS: started 2026-10-23, Nigel away about 90 minutes. Run whole, committing per task. No new plugins, permissions or assets.

## Plan

### Task 1: The design pages
- **Work:** `AppDesign.md` becomes [[App Design Index]]: the template's content is spread over child pages and expanded.
- **Verify:** open `docs/thrower/AppDesign/` in Obsidian.

### Task 2: Light and dark themes
- **Work:**
  - `lib/ui/theme/app_theme.dart`: the palette and both themes.
  - An Appearance setting kept on the phone (`lib/settings/app_settings_store.dart`, like the player names).
  - `themeModeProvider`.
  - The camera screens always dark (`AppTheme.cameraDark`).
- **Verify:** switch the phone between light and dark; Home and History follow; Play stays dark.

### Task 3: Each knife kept, and the stats
- **Work:**
  - `GameRecord` version 4 keeps each knife's score (`knives`), so older apps still read it. Older records have totals only.
  - `ThrowStats` (pure Dart) works out sessions, knives, per knife, 5s, hit rate, best ranked and best round ([[History and Stats]]).
- **Verify:** unit tests.

### Task 4: The bottom bar, Home and Setup
- **Work:**
  - `AppShell` with Home, Throw, History and Setup.
  - The new Home: hero, last session, Start throwing, quick-action cards.
  - Throw: cards.
  - Setup: the tools, Instructions, Appearance, Account.
  - Shared components (`ActionCard`, `StatTile`, `TargetMark`, `SectionHeading`).
- **Verify:** widget tests, then on the phone.

### Task 5: History's stats
- **Work:** stat tiles above the list, the sessions as cards.
- **Verify:** play two sessions; the numbers match by hand.

### Task 6: Throwing screens: bigger numbers
- **Work:** the round and total larger and bolder on Play (dark, read from the line).
- **Verify:** on the phone, from the throwing line.

### Task 7: Docs, traceability, device checks, handoff
- **Work:**
  - Docs Agent and Traceability Agent.
  - Device Test Plan: App Design Checks.
  - Mac Handoff: build 14.

---

## Plan Changes Log
- (none yet)

---

## Task Log
