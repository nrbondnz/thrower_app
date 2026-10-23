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
IN PROGRESS: Tasks 1–6 built (2026-10-23); Task 7 (docs, traceability, device checks, handoff) in progress. Run whole, committing per task. No new plugins, permissions or assets.

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
- **2026-10-23, Task 2:** the Appearance setting has its own store, `lib/settings/appearance_store.dart` (`FileAppearanceStore`, `appearance.json`), not a shared `app_settings_store.dart`. The provider is `appearanceProvider` (`AppearanceNotifier`), and `themeModeOf` turns it into a `ThemeMode`; there's no `themeModeProvider`.
- **2026-10-23, Task 3:** `GameRecord.knives` is an extra JSON field, and the history format's version stays at 3 (not 4). An older build sets aside a file with a newer version, so a bump would have hidden every kept session from it. See [[Design Decisions]] → App Design: Themes, Tabs and Stats.

---

## Task Log

### Task 1: The design pages
- **Status:** COMPLETE (commit `4e90da1`)
- **What changed:** `AppDesign.md` became [[App Design Index]] with ten child pages (goals, brand and voice, colour and themes, typography, navigation, Home, throwing screens, history and stats, components, competition). The vault's `Index.md` links it.
- **Files:** `docs/thrower/AppDesign/*.md`, `docs/thrower/Index.md`, this checkpoint.
- **Tests:** none (docs only).

### Task 2: Light and dark themes
- **Status:** COMPLETE (commit `d4dc878`)
- **What changed:**
  - `lib/ui/theme/app_theme.dart`: `AppPalette` (`dark`, `light`), `AppTheme.light()`, `AppTheme.dark()`, `AppTheme.cameraDark`, `themeModeOf`, `CameraTheme`.
  - `lib/settings/appearance_store.dart`: `Appearance` (phone, light, dark); `AppearanceStore`; `FileAppearanceStore` writes `appearance.json` in the app support folder.
  - `lib/providers.dart`: `appearanceStoreProvider`, `appearanceProvider` (`AppearanceNotifier`).
  - `lib/main.dart`: `theme`, `darkTheme` and `themeMode`.
  - Wrapped in `CameraTheme` (always dark): Play, two-target Play, Quick draw on a recording, live Quick draw, Calibrate, the score pad.
- **Tests:** `test/settings/appearance_test.dart` (10).

### Task 3: Each knife kept, and the stats
- **Status:** COMPLETE (commit `a08fd21`)
- **What changed:**
  - `GameRecord.knives`: each knife's score, by player then round, filled by `GameRecord.fromMatch`. An extra JSON field; `GameRecord.version` stays 3. Older records read as null.
  - `lib/history/throw_stats.dart`: `ThrowStats.of` (sessions, withKnives, knives, points, fives, hits, bestRanked, bestRound; `perKnife`, `hitRate`, `partial`), `perKnifeText`, `hitRateText`. Live test sessions left out.
- **Files:** `lib/history/game_record.dart`, `lib/history/game_history.dart`, `lib/history/throw_stats.dart`.
- **Tests:** `test/history/throw_stats_test.dart` (14).

### Task 4: The bottom bar, Home and Setup
- **Status:** COMPLETE (commit `4f220ac`)
- **What changed:**
  - `lib/ui/app_shell.dart`: `AppShell` (a `NavigationBar`: Home, Throw, History, Setup); `openScreen` reads the kept sessions again on the way back.
  - `lib/ui/home_screen.dart`: the new `HomeScreen` (`TargetMark`, THROWER, the tagline, `LastSessionCard`, START THROWING, Rounds and Quick draw cards); `lastSessionTiles`.
  - `lib/ui/throw_screen.dart`: `ThrowScreen` (Rounds, Quick draw, Leaderboard on the iPhone only).
  - `lib/ui/setup_screen.dart`: `SetupScreen` (Instructions, Appearance, Tools, Account).
  - `lib/ui/theme/widgets.dart`: `ActionCard`, `StatTile`, `StatRow`, `TargetMark`, `SectionHeading`.
  - `lib/ui/post_score_panel.dart`: `viewLeaderboard` is now top-level, for Throw.
  - `lib/providers.dart`: `keptGamesProvider`, read again when a session is kept.
- **Tests:** `test/ui/app_shell_test.dart` (13, new); `widget_test.dart`, `account_screen_test.dart`, `instructions_test.dart`, `live_quick_draw_screen_test.dart`, `live_test_screen_test.dart` updated for the tabs.

### Task 5: History's stats
- **Status:** COMPLETE (commit `7761168`)
- **What changed:** `HistoryScreen` watches `keptGamesProvider`. A `StatsCard` (key `historyStats`) shows Sessions, Knives, Per knife; 5s, Hit rate, Best ranked (or Best round before a ranked session). A note (key `historyStatsPartial`) when some sessions have no knives kept. The sessions are cards under a "Sessions" heading.
- **Files:** `lib/ui/history_screen.dart`.
- **Tests:** `test/ui/history_screen_test.dart` (4 new).

### Task 6: Throwing screens: bigger numbers
- **Status:** COMPLETE (commit `c848d9f`)
- **What changed:** one-thrower Play shows the session total large (48, amber, key `playTotal`) with "points" under it, above a bolder round line (22, extra bold, tabular digits). Two throwers unchanged.
- **Files:** `lib/ui/play_screen.dart`.
- **Tests:** `test/ui/play_screen_test.dart` ('one thrower: the total in large type').

### Task 7: Docs, traceability, device checks, handoff
- **Status:** IN PROGRESS
- **Done:** Docs Agent (below); Device Test Plan → App Design Checks (AD0–AD11); Mac Handoff → Build 14.
- **To do:** Traceability Agent; fix the in-app Instructions' references to the old Home; the device checks.

---

## Doc Update — 2026-10-23

### Files Updated
- `stories/story-checkpoint-app-design.md`: Task Log for Tasks 1–6, status, plan changes.
- `AppDesign/*.md`: Status and "Code:" lines match what was built.
- `Architecture/Design Decisions.md`: new section "App Design: Themes, Tabs and Stats (2026-10-23)".
- `Architecture/System Diagram.md`: the UI tree is now AppShell and its tabs; the camera screens open over them.
- `Architecture/Data Flow.md`: the History tab, keptGamesProvider and the stats; Setup → Account.
- `Architecture/Glossary.md`: Appearance, Camera theme, Hit rate, Per knife, Last session; AppShell, HomeScreen, ThrowScreen, SetupScreen, ThrowStats.
- `requirements/`: Game Recording's and Instructions and Safety's "What Exists Today"; Requirements Index.
- `Operations/Device Test Plan.md`: App Design Checks (AD0–AD11).
- `Operations/Mac Handoff.md`: Build 14 section.
- `tool/web_docs/content.py` and `docs/web/`: the new screens and components.
- `CLAUDE.md`, `docs/working-with-nigel.md`: App design in progress.
- `docs/dont-ask-again.md`: "throwing" and "session", not "game".

### Files Created
- `requirements/Look and Feel.md` (Across the app, beside the other Across the app pages).
- `requirements/Throwing Stats.md` (Across the app).

### Drift Items
- The overview diagram on the web pages (`tool/web_docs/build.py`) still ends with "Backend + accounts: not chosen" and "deferred: no network calls today": stale since the Amplify backend (2026-10-19). Not part of this story.
- Older device checks (H, C, PT, RK…) say "Home → Play", "Home → History" and so on. App Design Checks starts with a note mapping them to the tabs, rather than rewriting each.
- The in-app Instructions (`lib/ui/instructions.dart`) still describe the old Home (Play, History, Calibrate target and Live test on Home). To fix in Task 7.

