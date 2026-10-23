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

---

## Doc Update — 2026-10-23

### Files Updated
- `Architecture/Design Decisions.md`: new section **Leaderboard Tables: This Week and Last Week** (weekly tables; the screen behind `LeaderboardService`; our own iPhone code `GameCenterTables` rather than the plugin, and why; the week's start from Game Center; privacy). Links [[Rankings]], [[Look and Feel]]. The Ranked section's "View leaderboard opens Apple's screen" and the `games_services` decision now point to it.
- `requirements/Game Centre/Rankings.md`: status, Decided and What Exists Today (the tables, posted sync); Not yet; Monthly Ranking; Related.
- `requirements/Look and Feel.md`: the leaderboard table screen.
- `Architecture/Glossary.md`: `LeaderboardService.loadTable`; `LeaderboardWeek`, `LeaderboardEntry`, `LeaderboardTable`, `LeaderboardSignedOut`; `GameCenterLeaderboardService.channel`; `GameCenterTables`; `LeaderboardTableScreen`, `WeekTable`, `EntryRow`; `LeaderboardsScreen` and View leaderboard now open the table. Concepts: recurring leaderboard (occurrence, previous occurrence), **Leaderboard week**, **Method channel (`thrower/game_center`)**.
- `tool/web_docs/content.py`: Screens and LeaderboardService components; GameKit as an external box; new flow **leaderboard-tables**; `docs/web/` rebuilt (index + 15 flows + 30 components).
- `Operations/Device Test Plan.md`: **Leaderboard Table Checks** LT0–LT8.
- `Operations/Mac Handoff.md`: Build 15 → Also in it: leaderboard tables; **First: the Swift must compile** (build, fix and tell the PC if not, a debug run, the week's start against `rankedLeaderboardStart`); LT checks under Checks to send.
- `stories/backlog.md`: #22 renamed to weekly; built on the PC, to compile on the Mac.

### Notes
- Task 3's Traceability Agent run is still to do.
- The filename still says "monthly"; kept so links don't break.

---

## Traceability Report — 2026-10-23

Story: Leaderboard Tables (backlog #22). Code: commit a5afd1f, plus the fixes below (not committed). Also looked at 7939fa2 (small fixes) and ae22576 (#6).

### Coverage Summary
- Requirements: 13.
- Fully covered (design, code, test): 12 (R11 still needs its device check).
- Partly covered: 1 (the week's start from Game Center: read, never used).
- Orphan code: none.
- The Swift (`GameCenterTables`) is covered only through a mocked channel. It's checked on the Mac (LT0–LT8).

### Matrix

- **R1: This week's best scores (3 m), a table**
  - Design: Design Decisions → Leaderboard Tables: This Week and Last Week.
  - Code: `WeekTable` (`LeaderboardWeek.thisWeek`), `GameCenterLeaderboardService.loadTable`, `GameCenterTables.loadTable`.
  - Test: "this week's table: place, nickname and score"; "reads the rows, the player and the week's start".
  - Device: LT0. Status: ✅
- **R2: Last week's results, the full table, our own iOS code**
  - Design: Design Decisions → Leaderboard Tables (why not the plugin).
  - Code: `previous: true` on `thrower/game_center`; `loadPreviousOccurrence` then `loadEntries` in `AppDelegate.swift`.
  - Test: "Last week's tab loads last week"; "asks for the leaderboard, the week and 25 places".
  - Device: LT1. Status: ✅
- **R3: No all-time table**
  - Design: Decided list above; Rankings → Not yet.
  - Code: `LeaderboardWeek` has two values only. Status: ✅ (nothing to test)
- **R4: Weekly, not monthly (Plan Changes Log)**
  - Design: Design Decisions; Rankings.
  - Code: `LeaderboardWeek` labels; the tabs.
  - Test: the tab keys `week-thisWeek`, `week-lastWeek` in the widget tests. Status: ✅
- **R5: Top 25, the player's own row marked**
  - Code: `count = 25` (Dart), clamped to 1–100 in the Swift; `EntryRow` "(you)".
  - Test: "the player's own row is marked (you)". Status: ✅
- **R6: The player under the table if further down**
  - Code: `LeaderboardTable.meBelow`.
  - Test: "further down than the top 25"; new `LeaderboardTable.meBelow` unit tests (no score, in the top 25, further down). Status: ✅
- **R7: Loading**
  - Code: spinner while `_table` and `_failure` are null.
  - Test: indirectly (the pull-to-refresh test pumps a load in flight). Status: ✅
- **R8: Empty (no scores this week; no results last week)**
  - Code: `tableEmpty`, two messages; new **Refresh** button.
  - Test: "no scores yet this week"; "no results for last week yet"; new "Refresh shows a score just posted". Status: ✅
- **R9: Signed out of Game Center, with Try again**
  - Code: `signIn()` false or `signedOut` from the Swift → `LeaderboardSignedOut`.
  - Test: "not signed in to Game Center: says so, Try again"; "signed out of Game Center: LeaderboardSignedOut"; "View leaderboard, not signed in". Status: ✅
- **R10: No signal, with Try again**
  - Code: any other error; in the Swift, `NSURLErrorDomain` or `GKError.communicationsFailure` → `failed`.
  - Test: "no signal: says so, Try again"; "any other failure is passed on". Status: ✅
- **R11: The first week (no previous occurrence)**
  - Code: `loadPreviousOccurrence` gives no board and no network error → `["entries": []]` → "No results for last week yet."
  - Test: Dart side only ("no results for last week yet"). The Swift branch needs LT1. Status: ✅ (device check to come)
- **R12: Reached from the Leaderboards tab and View leaderboard; Open in Game Center**
  - Code: `LeaderboardsScreen` → `openScreen`; `PostScorePanel` → `Navigator.push`; `openInGameCenter` → `viewLeaderboard`.
  - Test: app_shell_test; "View leaderboard opens the 3 m leaderboard's tables"; "Open in Game Center shows Apple's screen". Status: ✅
- **R13: The week's start from Game Center (to confirm `rankedLeaderboardStart`)**
  - Code: `LeaderboardTable.weekStart` is read from `start`.
  - Test: "reads the rows, the player and the week's start".
  - Gap: nothing uses or shows it. The Mac Handoff asks to check it in a debug run, but there's nothing to see. Status: ⚠️

### Checked and Fine
- **`setState` from `initState`:** `_load` calls `setState` before its first `await`, so during `initState`. Flutter allows this (it only asserts in a constructor, or after dispose); the element is already dirty for its first build. The widget tests run this path with a fake service and pass.
- **After dispose:** the only `setState` after an `await` checks `mounted`. Switching tabs fast is safe.
- **`meBelow` with no `me`:** false, so nothing goes under the table.
- **The `count` on the iPhone:** clamped to 1–100 (`max(1, min(count, 100))`).
- **View leaderboard from a camera screen:** the pushed route takes the app's theme from `MaterialApp` (not the camera's dark `CameraTheme`), and Back returns to Play. It posts and views `ranked3m`, the same board `ScorePostNotifier` posts to.
- **Loads firing twice:** each tab loads once when built. `TabBarView` doesn't keep the other tab alive, so going back to a tab loads it again (fresh, and `signIn` is quick when already signed in). No double load on opening.
- **The Swift (reading only; it compiles on the Mac):**
  - The closure parameter `board` in `loadPreviousOccurrence { board, error in … }` shadows the outer `var board`. That's legal in Swift and only the parameter is used inside.
  - The nested `func row(_:)` shadows nothing; `entries.map(row)` is fine.
  - The API shapes match iOS 14+ GameKit: `loadLeaderboards(IDs:)`, `loadPreviousOccurrence(completionHandler:)`, `loadEntries(for:timeScope:range:)` returning `(Entry?, [Entry], Int)`, `startDate`, `gamePlayerID`. The target is iOS 15.0 and Swift 5.0, so the `Task`/`@MainActor` code and the non-`Sendable` captures are warnings at most.
  - `registrar(forPlugin:)` is optional and `messenger()` is a method: both used correctly.
  - No definite compile error found. `ios/` not touched.
- **7939fa2:** the posted-sync loop and Play's scrolling panel look right; tests cover them.
- **ae22576:** Live test and the Scoring test target hidden behind `testToolsProvider`; tests cover it.

### Fixes (2026-10-23, not committed)
1. **Pull to refresh dropped the table.** `_load` cleared the table first, so a pull swapped the list for a full-screen spinner and took the `RefreshIndicator` away mid-refresh. Now `_load(keep: true)` (pull to refresh) leaves the table until the new one arrives. Try again still shows the spinner.
2. **No way to reload an empty table.** Straight after Post score, View leaderboard can show "No scores yet this week" before Game Center has the score, with no way to reload but going back. The empty state now has a **Refresh** button (`tableRefresh`).
- Files: `lib/ui/leaderboard_table_screen.dart`, `test/ui/leaderboard_table_screen_test.dart`.
- New tests: "no scores yet: Refresh shows a score just posted"; "pull to refresh keeps the table while it loads, then shows the new one"; three `LeaderboardTable.meBelow` tests.
- Results: `flutter analyze` clean on both files; leaderboard_table_screen_test, score_post_test and app_shell_test: 65 passed, 0 failed.

### Gaps
1. **R13, the week's start:** read but never shown or used. Either show it (for example "Week from Fri 23 Oct" under the tabs) or log it in a debug run, so the Mac check in the Handoff can be done. Question for Nigel below.
2. **The Swift is untested on the PC:** it is checked by LT0–LT8 on the Mac and iPhone.

### Open Questions for Nigel
1. Show the week's dates on each tab (from Game Center's `start`)? It would also do the Mac check of `rankedLeaderboardStart` with no debug run.
2. Should a tab keep its table when you switch away and back (no reload), or reload each time as now?
