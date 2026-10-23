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
- **Done:** Docs Agent (below); Traceability Agent (report below, fixes in `db1788e`); Device Test Plan → App Design Checks (AD0–AD11); Mac Handoff → Build 14.
- **To do:** fix the in-app Instructions' references to the old Home; the device checks.

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


---

## Traceability Report — 2026-10-23

### Coverage Summary
- Requirements and decisions checked: 12.
- Fully covered (requirement, design, code, test): 11, after the fixes below.
- Covered, but with an open layout gap on small phones: 1 (Play's large total).
- Orphan code (no requirement): none found.

### Matrix
- **Themes follow the phone; Setup → Appearance (Phone, Light, Dark)**
  - Design: [[Colour and Themes]]; [[Design Decisions]] → App Design.
  - Code: `AppTheme`, `themeModeOf`, `AppearanceNotifier`, `FileAppearanceStore`, `lib/main.dart`.
  - Test: `appearance_test.dart`; `app_shell_test.dart` 'Appearance: choosing Dark makes the app dark, and keeps it'.
  - Status: ✅ Covered. The setting persists: it's saved on each change and loaded at start.
- **The camera screens stay dark**
  - Code: `CameraTheme` round Play, two-target Play, Quick draw (recording and live), Calibrate and the score pad.
  - Test: `appearance_test.dart` 'a camera screen is dark inside a light app'; `play_screen_test.dart` 'dialogs over Play are dark in a light app' (new).
  - Status: ✅ Covered, after fix 2.
- **Bottom bar: Home, Throw, History, Setup**
  - Design: [[Navigation and Structure]]. Code: `AppShell`. Test: `app_shell_test.dart`.
  - Status: ✅ Covered.
- **Home: hero, last session, Start throwing, quick actions**
  - Design: [[Home Screen]]. Code: `HomeScreen`, `LastSessionCard`, `lastSessionTiles`.
  - Test: `app_shell_test.dart`: one thrower, totals only, the kind, a tap opens History. New: two throwers; a Live test session passed over.
  - Status: ✅ Covered. Two throwers show `countedTotals` under `nameOf`, as History's result does.
- **Throw: Leaderboard on the iPhone only**
  - Code: `ThrowScreen`; `leaderboardServiceProvider` is null unless `main` overrides it on iOS.
  - Test: `app_shell_test.dart`: no card without a service; the card opens Game Center's.
  - Status: ✅ Covered.
- **Setup → Account only with accounts**
  - Code: `SetupScreen` (`authServiceProvider != null`). Test: `account_screen_test.dart`.
  - Status: ✅ Covered.
- **Each knife kept with a session (`GameRecord.knives`)**
  - Design: [[Design Decisions]] → App Design (an extra field; the version stays 3).
  - Code: `GameRecord.fromMatch`, `toJson`, `fromJson`. The backup stores `jsonEncode(record.toJson())` and reads it with `GameRecord.fromJson` (`AmplifyBackup.put`, `list`).
  - Test: `throw_stats_test.dart` 'kept through JSON' (the same encode and decode as the backup), 'a session kept before then reads with none', 'knives that can't be read are dropped'. Also `keeping_games_test.dart` (new, fix 1).
  - Status: ✅ Covered. `AmplifyBackup` itself is still checked on the device.
- **Stats: sessions, knives, per knife, 5s, hit rate, best ranked or best round**
  - Design: [[History and Stats]]. Code: `ThrowStats`, `perKnifeText`, `hitRateText`, `StatsCard`.
  - Test: `throw_stats_test.dart` (14), `history_screen_test.dart` (4).
  - Status: ✅ Covered. Each stat matches its definition:
    - Live test sessions are left out.
    - Per knife is to one decimal place.
    - A 0 counts as thrown, not hit.
    - Best ranked comes only from a ranked session not finished early.
    - Older sessions count only towards Sessions and Best, with the note.
- **`keptGamesProvider` read again (session kept, delete, clear, tab change, back from a pushed screen)**
  - Code: `GameNotifier._keep`, `HistoryScreen._reload`, `AppShell._go`, `openScreen`.
  - Test: `keeping_games_test.dart` 'a finished session is read again into the kept sessions' (new); `app_shell_test.dart` 'a session kept since: Home and History show it after a tab change' (new); `history_screen_test.dart` (delete, clear).
  - Status: ✅ Covered.
    - A session kept from Play (pushed by `PlaySetupScreen`) refreshes through `_keep` itself, and `openScreen` reads the sessions again on the way back.
    - History refreshes while it's on screen, because it watches the provider.
- **Play: the total large**
  - Design: [[Throwing Screens]]. Code: `PlayScreen` (`playTotal`). Test: `play_screen_test.dart`.
  - Status: 🟡 Covered, but see recommended fix 1 (small phones).
- **"Throwing" and "session", not "game", in new words**
  - All new words on Home, Throw, Setup and History's stats follow it. Older words on History stay as they are (see question 2).
  - Status: ✅ for new words.
- **In-app Instructions point to the tabs**
  - Done in Task 7 (commit `db741f8`); tested by `instructions_test.dart`.
  - Status: ✅ Covered.

### Gaps Found and Fixed (commit `db1788e`)
1. **A missed knife added after the end wasn't kept.**
   - Cause: `GameNotifier._keep` skipped a save when the round totals hadn't changed.
   - Effect: adding a 0 to a round collected early (the Ranked rules allow it) changes the knives, and so Knives and Hit rate, but no total. The kept session kept the old knives.
   - Fix: `_keep` now compares each knife.
   - Files: `lib/providers.dart`.
   - Test: `keeping_games_test.dart` 'a 0 added after the end to a round collected early re-saves the game with that knife'.
2. **Some dialogs over camera screens were light in Light mode.**
   - Cause: `showDialog` takes its theme from the context it's given, and each screen's own State context is above its `CameraTheme`.
   - Effect: Reset this game? (Play and two-target Play), Finish the game now? and Finish the match now? came up light over a dark screen.
   - Fix: the three dialogs are wrapped in `CameraTheme`. Score corrections and the names dialog already used a context inside the screen, so they were already dark.
   - Files: `lib/ui/play_screen.dart`, `lib/ui/two_target_play_screen.dart`, `lib/ui/live_quick_draw_screen.dart`.
   - Test: `play_screen_test.dart` 'dialogs over Play are dark in a light app' (2 tests; both fail without the fix).
3. **Missing tests, now added:**
   - Home's last session for two throwers.
   - Home's last session skips a newer Live test session.
   - Home and History read the sessions again on a tab change.
   - The kept sessions are read again when a session finishes.
   - Files: `test/ui/app_shell_test.dart`, `test/history/keeping_games_test.dart`.

### Test Results
- `flutter analyze`: no issues.
- The affected tests all passed: 438 passed, 0 failed. They are `play_screen`, `two_target_play_screen`, `live_quick_draw_screen`, `quick_draw_screen`, `score_pad_screen`, `score_corrections`, `app_shell`, `history_screen`, `account_screen`, `widget_test`, `test/history`, `test/settings` and `test/game`.

### Recommended Fixes (not made: no more lib/test changes while the Mac build runs)
1. **Play on small phones (Task 6).** From a one-off widget check with a 24 pt status bar and a 48 pt navigation bar:
   - On 360 × 640, one thrower at game over: the camera area drops from 150 to 40 pt.
   - On 320 × 568, one thrower at game over: the bottom panel overflows by 51 pt. It fitted before Task 6.
   - On an iPhone SE (375 × 667) at game over: the camera area drops from 197 to 118 pt.
   - Mid-game it fits everywhere, but the camera has about 80 pt less.
   - Options: let the bottom panel scroll, with a cap on its height; or show a smaller total at game over (the game text already gives the final total).
2. **Play overflows by 24 pt to the right on a 320 pt wide phone.** The cause is likely the AppBar's Finish game and Reset game, or the slot row. It was there before this story.
3. **History overflows by 61 pt to the right at twice the text size.** The cause is likely the AppBar's Clear history. Home, Throw and Setup fit at 1.0, 1.3 and 2.0 times the text size on a 320 pt screen.
4. **Home's quick-action cards** can be different heights when "QUICK DRAW" wraps on a narrow phone. Cosmetic.
5. **Best ranked** counts any ranked session not finished early. That includes one with a round collected after fewer than 3 knives, which can't be posted. It could use the same test as `Match.postable`.

### Open Questions
1. History lists Live test sessions, but the stats and the Sessions count leave them out, so the count can differ from the list. Should the list mark Live test sessions, leave them out, or stay as it is?
2. History still says "No games yet", "Each game of Play is kept here", "Every kept game is removed" and "Delete this game", under a SESSIONS heading. Change them in the planned wording pass, with "Which game?" and "Game over"?
3. Play on small phones (recommended fix 1): scroll the panel, or show a smaller total at game over?
4. Best ranked: count only sessions that could be posted (recommended fix 5)?
