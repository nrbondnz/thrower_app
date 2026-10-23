# Story Checkpoint: Leaderboard Tables (This Week, Last Week)

## Story Goal
Backlog #22. Nigel, 2026-10-22: "a best 3 meter score table refreshed each month, previous month results table etc."; then "add backlog #22 monthly tables next". Show the Ranked leaderboard (`ranked.3m.5x3`, recurring monthly in Game Center: [[story-checkpoint-game-center-scores]]) in the app: **this month's** best scores and **last month's** results, each a table of rank, Game Center nickname and score, with the player's own place. Requirement: [[Rankings]].

> **Update 2026-10-23:** Nigel set the Game Center leaderboard up **weekly** (recurring, from 2026-10-23, 1-week duration), not monthly. "This month / last month" here becomes **this week / last week** unless Nigel wants a second, monthly leaderboard. Re-confirm before Task 1.

## Decided (Nigel, 2026-10-22)
- **Last month: the full table**, with our own small piece of iOS code (the `games_services` plugin's `loadPreviousOccurrence` returns only the player's own entry). Behind the same `LeaderboardService` interface.
- **No all-time table** for now.
- iPhone only, as posting (Android: backlog #21).

## Complexity Score
4 (Large): UI → leaderboard service → native iOS code (3 layers); native code on one platform (1).

## Status
IN PROGRESS 2026-10-23: Nigel approved the plan on 2026-10-22 ("Full table, own iOS code"), and on 2026-10-23 said to carry on with the backlog. **Weekly:** the tables follow the leaderboard as it was set up (recurring, 1 week); a monthly table would need a second leaderboard. Tasks 1 and 2 built on the PC; **the Swift is compiled and checked on the Mac**.

## Plan

### Task 1: The tables, behind the interface (Dart, tested with a fake)
- **Work:** `LeaderboardEntry` (rank, name, score, date, is it me) and `LeaderboardTable` (the top entries, and the player's own entry if they're further down); `LeaderboardService.loadTable(board, {lastMonth})`; a **Leaderboard** screen with **This month** / **Last month** tabs: the top 25, the player's row highlighted (or shown under the table if outside it), and states for loading, no scores yet, not signed in to Game Center, and no signal (Try again); **Open in Game Center** (Apple's screen, as now). Reached from **Home → Leaderboard** (iPhone only) and from the end-of-game **View leaderboard** (now our screen).
- **Verify:** widget tests with the fake service; nothing to see on Android.

### Task 2: Game Center (iOS)
- **Work:** this month from the plugin (`Leaderboards.loadLeaderboardScores`, top 25, and the player's own entry); last month from our own method channel `thrower/game_center` → `loadPreviousTable` in `ios/Runner/AppDelegate.swift` (GameKit: the leaderboard's `loadPreviousOccurrence()`, then `loadEntries` for everyone, places 1–25, and the local player's entry). Dart side tested against a mocked channel. "Be Careful" Review Agent on the native code.
- **Verify:** on the Mac, it builds; on the iPhone (after the Game Center setup and a posted score), This month shows it. Last month shows only once a month has ended (until then, "No results for last month yet").

### Task 3: Docs, device checks, handoff
- **Work:** Docs Agent (Rankings, Design Decisions, glossary, web pages, Device Test Plan: Leaderboard Checks), Traceability Agent; the Mac Handoff (the Swift to build and check; with build 11 if it's not out yet).

## Notes
- Game Center returns players' photos too: not shown (slow, one load per player); names and scores only.
- A brand-new recurring leaderboard has no previous month until its first month ends.

---

## Plan Changes Log
- **2026-10-23: weekly, not monthly.** Nigel set the leaderboard up weekly on the Mac. "This month / last month" became **This week / Last week** (`LeaderboardWeek`).
- **2026-10-23: one iPhone method for both weeks.** The plan had this month from the plugin's `loadLeaderboardScores`. That call also downloads every player's photo, which the app doesn't show. So `GameCenterTables.loadTable` in `ios/Runner/AppDelegate.swift` loads both weeks, names and scores only, on the channel `thrower/game_center`. It also returns the week's start (`startDate`), which can confirm `rankedLeaderboardStart`.
- **2026-10-23: where it opens.** It's reached from the **Leaderboards** tab (which replaced Home → Leaderboard on 2026-10-23) and from the end-of-session **View leaderboard**. Game Center's own screen is a button on it (**Open in Game Center**).
- **2026-10-23: the Swift is in `AppDelegate.swift`.** A new Swift file would need adding to the Xcode project by hand; better done in Xcode later if it grows.

## Task Log

### Task 1: The tables, behind the interface
- **Status:** COMPLETE (2026-10-23).
- **What changed:**
  - `lib/leaderboard/leaderboard_table.dart`: `LeaderboardWeek`, `LeaderboardEntry`, `LeaderboardTable` (with `meBelow`, `weekStart`) and `LeaderboardSignedOut`.
  - `LeaderboardService.loadTable(board, week, {count})`.
  - `lib/ui/leaderboard_table_screen.dart`: `LeaderboardTableScreen` (tabs; Open in Game Center), `WeekTable` (loading, table, empty, signed out, no signal, Try again; pull to refresh) and `EntryRow` ("(you)" highlighted).
  - The Leaderboards tab card and View leaderboard open it.
- **Tests:** `test/ui/leaderboard_table_screen_test.dart`; `FakeLeaderboard.loadTable`.

### Task 2: Game Center (iOS)
- **Status:** BUILT on the PC, to compile on the Mac.
- **What changed:**
  - `GameCenterLeaderboardService.loadTable`: the channel `thrower/game_center`.
  - `ios/Runner/AppDelegate.swift`: `GameCenterTables` (registered in `didInitializeImplicitFlutterEngine`).
- **Tests:** the channel replies are mocked in `test/ui/leaderboard_table_screen_test.dart`.
