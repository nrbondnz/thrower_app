# Story Checkpoint: Leaderboard Tables (This Month, Last Month)

## Story Goal
Backlog #22. Nigel, 2026-10-22: "a best 3 meter score table refreshed each month, previous month results table etc."; then "add backlog #22 monthly tables next". Show the Ranked leaderboard (`ranked.3m.5x3`, recurring monthly in Game Center: [[story-checkpoint-game-center-scores]]) in the app: **this month's** best scores and **last month's** results, each a table of rank, Game Center nickname and score, with the player's own place. Requirement: [[Rankings]].

## Decided (Nigel, 2026-10-22)
- **Last month: the full table**, with our own small piece of iOS code (the `games_services` plugin's `loadPreviousOccurrence` returns only the player's own entry). Behind the same `LeaderboardService` interface.
- **No all-time table** for now.
- iPhone only, as posting (Android: backlog #21).

## Complexity Score
4 (Large): UI → leaderboard service → native iOS code (3 layers); native code on one platform (1).

## Status
PLANNED 2026-10-22: waiting for Nigel's approval. Then run whole, committing per task; the Swift is compiled and checked on the Mac (with build 11's Game Center setup, or after it).

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
- (none yet)
