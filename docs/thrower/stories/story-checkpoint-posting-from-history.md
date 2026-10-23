# Story Checkpoint: Posting From History, and a Leaderboards Tab

## Story Goal
Nigel, 2026-10-23:
- "I would like each result in history to note, can be posted, posted, and cannot be posted."
- "Normal games from 3m 3x5 can be posted even if not in strict mode if there are no manual score changes."
- "Some test history throw sets that are available to be posted, maybe 10, that I can ask you to regenerate from time to time."
- "The online leaderboard to be available from home page, rather than 'Throw' at the menu put online leaderboards."
- "Change 'Quick actions' to 'throwing types'."
- "Within 'leaderboards' it will eventually have more options e.g. 'Marks friends leaderboard' or 'MK leaderboard' or 'knife club leaderboard'. But for now we can start with just one '3 meter knifes 3x5'."

Follows [[story-checkpoint-game-center-scores]] and [[story-checkpoint-app-design]]. Requirement: [[Rankings]].

## Decided (Nigel, 2026-10-23)
- **Which sessions can be posted later:** only those thrown in **this leaderboard week**. Game Center files a score in the current week, whenever it was thrown. Older ones say "Cannot be posted: an earlier week".
- **3 m for a normal session:** posting asks for a tick, "I threw this from 3 m", as Ranked's Start does.
- **Hand changes:** in a normal session, **any** knife added or changed by hand means it can't be posted. Ranked still allows 0s, as now.
- **Test sessions:** Setup → Tools → **Add 10 test sessions** makes 10 new, random, postable sessions on the phone, dated now, each time it's tapped. They're marked **Test** in History and left out of the stats. The button shows only in test builds (debug, and TestFlight by a build flag), never in an App Store build.

## Complexity Score
6 (Large): history, scoring rules, leaderboard, UI (4 layers); the game record's format (1); more than 3 acceptance criteria (1).

## Status
IN PROGRESS: Tasks 1–4 COMPLETE 2026-10-23 (commit 7030b33; Review Agent fixes 46ed757). Task 5 (docs, traceability, device checks, handoff) in progress.

## Plan

### Task 1: The rules (pure Dart)
- **Work:**
  - `GameRecord` keeps whether any knife was changed by hand (`changedByHand`), whether it was posted (`posted`), and whether it's a test session (`test`). These are extra JSON fields, so the format's version is unchanged.
  - `postStatusOf(record, now)` gives **Can be posted**, **Posted** or **Cannot be posted**, with a short reason. A session can be posted when:
    - it has one thrower, used the camera (not Live test or the score pad), was played to the end, and every round has 3 knives;
    - it's either **Ranked**, or **Scoring, 5 rounds, with no hand changes**;
    - and it was thrown this leaderboard week.
  - `LeaderboardWeek`: the weekly periods from the leaderboard's start (2026-10-23; the exact time is to confirm in App Store Connect on the Mac).
  - `Match.postable` widens the same way, so a normal 5 × 3 session also offers Post score at the end.
- **Verify:** table-driven unit tests, one for each reason.

### Task 2: Post from History; the status on every result
- **Work:**
  - Each History card shows its status: Can be posted, Posted or Cannot be posted (with why, on the session's page).
  - A session's page has **Post score** (iPhone), with the 3 m tick for a normal session.
  - A post at the end of a session, or from History, marks the kept session **Posted**, and that's backed up with it.
- **Verify:** widget tests with the fake leaderboard; on the iPhone, post one from History (test sessions post to the test leaderboard).

### Task 3: A Leaderboards tab; "Throwing types"
- **Work:**
  - The bottom bar becomes **Home, Leaderboards, History, Setup**. Rounds and Quick draw are on Home.
  - **Leaderboards** lists the boards. For now there's one, **3 m knives · 3 × 5** (the weekly `ranked.3m.5x3`), which opens Game Center's. On Android it says leaderboards are on the iPhone for now.
  - The page is built so more boards can follow (Mark's friends, MK, a knife club).
  - Home's "Quick actions" becomes **Throwing types**.
- **Verify:** widget tests; on the phone.

### Task 4: Test sessions
- **Work:**
  - Setup → Tools → **Add 10 test sessions** and **Remove test sessions**.
  - The 10 are new and random each time: a mix of Ranked and normal 5 × 3, one thrower, 3 knives a round, dated within this week, so they can be posted.
  - They're marked Test in History, and left out of the stats.
  - Shown only when `kDebugMode`, or when the build sets `--dart-define=THROWER_TEST_TOOLS=true`. TestFlight builds set it; App Store builds don't. The Mac Handoff says how.
- **Verify:** tap Add; History shows 10 Test sessions marked Can be posted; post one.

### Task 5: Docs, traceability, device checks, handoff
- **Work:**
  - Docs Agent; Traceability Agent; Review Agent (the build flag).
  - Device Test Plan: Posting From History Checks.
  - Mac Handoff: build 15, with the flag in the `flutter build ios --config-only` step.

## Notes
- ~~A Test session posted from a TestFlight build goes to Game Center's sandbox.~~ Wrong: Game Center has **no sandbox for TestFlight** (Apple TN2417). Test sessions post only to a separate test leaderboard, `test.ranked.3m.5x3`, never added to an App Store version (Review Agent, 2026-10-23).
- Sessions kept before this story don't record hand changes, so they show **Cannot be posted: kept before posting from History**.

---

## Task Log

### Task 1: The rules (pure Dart)
- **Status:** COMPLETE (2026-10-23, commit 7030b33)
- **What changed:**
  - `GameRecord`: `changedByHand` (bool?, null for older), `posted`, `test`; extra JSON fields, version still 3; `markedPosted()`.
  - `postStatusOf(game, now)` → `PostStatus` (`PostState` canPost / posted / cannotPost, `label`, `reason` from `NotPostable`).
  - `leaderboard_week.dart`: `rankedLeaderboardStart` (2026-10-23 00:00 UTC, to confirm), 7-day `rankedLeaderboardPeriod`, `weekStartOf`, `sameWeek`.
  - `Match.postable` takes Scoring with 5 rounds and no `Match.changedByHand` (new).
- **Files:** `lib/history/game_record.dart`, `lib/history/post_status.dart`, `lib/leaderboard/leaderboard_week.dart`, `lib/scoring/match.dart`
- **Tests:** `test/history/post_status_test.dart` (table-driven, one case per reason; JSON round trip; weeks), `test/scoring/game_type_test.dart`

### Task 2: Post from History; the status on every result
- **Status:** COMPLETE (2026-10-23, commit 7030b33)
- **What changed:**
  - History cards show `PostStatusLabel` ("Test ·" for a test session).
  - A session's page has `HistoryPostPanel`: the status, "Why: …", Post score (iPhone; `ThreeMetreTick` for a normal session) → marked Posted. Android: "Posting is on the iPhone for now."
  - `PostScorePanel` asks the 3 m tick for a non-ranked session; after a post, `GameNotifier.keepPosted()` keeps the session as Posted.
  - `viewLeaderboard` takes a `board`.
- **Files:** `lib/ui/history_post_panel.dart`, `lib/ui/history_screen.dart`, `lib/ui/post_score_panel.dart`, `lib/providers.dart`
- **Tests:** `test/ui/history_post_test.dart`, `test/leaderboard/score_post_test.dart`

### Task 3: A Leaderboards tab; "Throwing types"
- **Status:** COMPLETE (2026-10-23, commit 7030b33)
- **What changed:**
  - The bar is Home, Leaderboards, History, Setup (`AppShell.leaderboards`); `throw_screen.dart` deleted.
  - `LeaderboardsScreen`: a card per `Leaderboard` (`title` "3 m knives · 3 × 5", `about`); Android: on the iPhone for now; a "More to come" line.
  - Home's "Quick actions" is "Throwing types".
- **Files:** `lib/ui/leaderboards_screen.dart`, `lib/ui/app_shell.dart`, `lib/ui/home_screen.dart`, `lib/leaderboard/leaderboard_service.dart`
- **Tests:** `test/ui/app_shell_test.dart`

### Task 4: Test sessions
- **Status:** COMPLETE (2026-10-23, commit 7030b33; Review Agent fixes 46ed757)
- **What changed:**
  - `test_sessions.dart`: `testToolsFlag` (`THROWER_TEST_TOOLS`), `testToolsEnabled` (debug or the flag), `makeTestSessions(now)`; `testToolsProvider`.
  - Setup → Test sessions (test build only) → Add 10 test sessions, Remove test sessions (`TestSessionsCard`).
  - Left out of `ThrowStats` and Home's last session.
  - 46ed757: test sessions post only to `Leaderboard.test3m` (`leaderboardFor`), only with the test tools (`NotPostable.testSession`), and are never backed up or synced.
  - Instructions: the Ranked games section covers posting from History, normal 5 × 3 sessions and the Leaderboards tab.
- **Files:** `lib/history/test_sessions.dart`, `lib/history/throw_stats.dart`, `lib/history/synced_game_history.dart`, `lib/ui/setup_screen.dart`, `lib/ui/instructions.dart`
- **Tests:** `test/history/test_sessions_test.dart`, `test/ui/instructions_test.dart`
- **Results (7030b33):** the story's test files, 174 passed.

### Task 5: Docs, traceability, device checks, handoff
- **Status:** IN PROGRESS (Docs Agent done; see the Doc Update Log)

---

## Doc Update Log: 2026-10-23

### Files Updated
- `Architecture/Design Decisions.md`: new section Posting From History (Nigel's four answers, the rules, the week to confirm, posted as a flag, test sessions behind a build flag and the test leaderboard, Leaderboards in place of Throw); update notes on Full games only and the bottom bar.
- `Architecture/Glossary.md`: components (`postStatusOf`, `PostStatus`, `NotPostable`, `leaderboardFor`, leaderboard week, `PostStatusLabel`, `HistoryPostPanel`, `ThreeMetreTick`, test sessions, `LeaderboardsScreen` in place of `ThrowScreen`, `Leaderboard.title` / `test3m`); concepts Post status, Leaderboard week, Test session, Changed by hand.
- `requirements/Game Centre/Rankings.md`, `requirements/Throwing Stats.md`, `requirements/Requirements Index.md`.
- `AppDesign/`: Navigation and Structure, Home Screen, Components, History and Stats, App Design Index.
- `Operations/Device Test Plan.md`: Posting From History Checks, PH0–PH13.
- `Operations/Mac Handoff.md`: Build 15 section (test leaderboard, start time to confirm, the test-tools build and `DART_DEFINES` checks, App Store builds).
- `Troubleshooting/Known Issues.md`: no Game Center sandbox for TestFlight; `--dart-define` carries over; the posting week uses the phone's clock.
- `tool/web_docs/content.py`, then `python tool/web_docs/build.py` (`docs/web/`).
- `CLAUDE.md`, `docs/working-with-nigel.md`: the story as in progress.

### Notes
- To confirm on the Mac: the recurring leaderboard's exact start time and timezone (`rankedLeaderboardStart`).
- AD0 and AD3 (App Design Checks) describe the old Throw tab; the PH section says how to read them.

---

## Plan Changes Log
- **2026-10-23 (Review Agent, commit 46ed757):** test sessions post to a separate test leaderboard (`Leaderboard.test3m`, `test.ranked.3m.5x3`), can't be posted in a build without the test tools (`NotPostable.testSession`), and are never backed up or synced. Setup's heading reads "Test sessions (test build only)". Mac Handoff Build 15 gains the test leaderboard setup and the `DART_DEFINES` checks.

---

## Traceability Report: 2026-10-23

Story: Posting From History. Code: commits 7030b33 and 46ed757, plus the fixes below (not committed). Design: [[Design Decisions]] → Posting From History.

### Coverage Summary
- Requirements traced: 14 (Nigel's six asks, his four answers, the Review Agent's four fixes).
- Fully covered (design, code, test): 14, after the fixes below.
- Bugs found and fixed: 2. Missing tests added: 10.
- Orphan code: none.
- Full suite after the fixes: 1120 passed, 0 failed. `app_shell_test.dart` after its last new test: 21 passed. `flutter analyze`: no issues.

### Forward: requirement → design → code → test

**A1. Each History result says Can be posted, Posted or Cannot be posted**
- Design: "the rules, in one pure function"; "Post score from a session's page".
- Code: `postStatusOf`, `PostStatus`, `NotPostable`; `PostStatusLabel` on each History card.
- Test: `post_status_test.dart` (one case per reason); `history_post_test.dart`.
- Status: ✅ Covered.

**A2. Normal 3 m 5 × 3 sessions can be posted with no hand changes**
- Code: `Match.postable`, `Match.changedByHand`; `GameRecord.changedByHand`.
- Test: `post_status_test.dart` (and the new group "changed by hand, or not"); `score_post_test.dart`.
- Status: ✅ Covered.

**A3. Test sessions to post, made again on request**
- Code: `makeTestSessions`, `TestSessionsCard`.
- Test: `test_sessions_test.dart`; new Home test in `app_shell_test.dart`.
- Status: ✅ Covered.

**A4. Leaderboards in place of "Throw" on the bar**
- Code: `AppShell.leaderboards`, `LeaderboardsScreen`.
- Test: `app_shell_test.dart`.
- Status: ✅ Covered.

**A5. "Quick actions" becomes "Throwing types"**
- Code: `home_screen.dart`.
- Test: `app_shell_test.dart`.
- Status: ✅ Covered.

**A6. One board for now, "3 m knives · 3 × 5", built for more**
- Code: `Leaderboard.ranked3m` (`title`, `about`); the screen lists `Leaderboard.values`.
- Test: `app_shell_test.dart`.
- Status: ✅ Covered.

**D1. Only sessions from this leaderboard week**
- Code: `leaderboard_week.dart`; `NotPostable.earlierWeek`.
- Test: `post_status_test.dart`.
- Status: ✅ Covered. The start time is still to confirm on the Mac.

**D2. A 3 m tick for a normal session**
- Code: `ThreeMetreTick` in `PostScorePanel` and `HistoryPostPanel`.
- Test: `score_post_test.dart`, `history_post_test.dart`.
- Status: ✅ Covered.

**D3. Any hand change blocks a normal session; Ranked still allows 0s**
- Code: `Match.changedByHand` (from `ThrowRecord.corrected`); Ranked's exception in `postStatusOf`.
- Test: `post_status_test.dart`. New: a fell-out and a "?" aren't hand changes; a missing knife added as 0 blocks Scoring but not Ranked, at the end and in History.
- Status: ✅ Covered (new tests).

**D4. Test sessions: 10 each tap, marked Test, out of the stats, test builds only**
- Code: `testToolsEnabled`, `testToolsProvider`; `ThrowStats.of` and Home skip `test`.
- Test: `test_sessions_test.dart`; new Home test.
- Status: ✅ Covered.

**R1. Test sessions post only in a test build**
- Code: `postStatusOf(…, testTools:)`, `NotPostable.testSession`.
- Test: `test_sessions_test.dart`.
- Status: ✅ Covered.

**R2. Test sessions go only to the test leaderboard**
- Code: `leaderboardFor`, `Leaderboard.test3m`, used by `HistoryPostPanel`.
- Test: `test_sessions_test.dart`; new widget test in `history_post_test.dart`.
- Status: ✅ Covered.

**R3. Test sessions never backed up or synced**
- Code: `SyncedGameHistory.add` and `sync` skip `test`.
- Test: `synced_game_history_test.dart`, group "test sessions".
- Status: ✅ Covered.

**R4. The test board shows only in test builds**
- Code: `LeaderboardsScreen` filters `Leaderboard.test`.
- Test: new, `app_shell_test.dart` (shown / hidden).
- Status: ✅ Covered (new test).

**K1. Posted sessions kept as Posted, at the end and from History**
- Code: `GameNotifier.keepPosted`, `GameRecord.markedPosted`, `HistoryPostPanel`.
- Test: `score_post_test.dart`; `history_post_test.dart`. New: back on the list says Posted; leaving the page mid-post.
- Status: ✅ Covered (after fix 2).

### Backward: code → requirement
- Every new symbol in the two commits traces to A1–A6, D1–D4, R1–R4 or K1. No orphan code.
- The end-of-game post uses `Leaderboard.ranked3m` directly, not `leaderboardFor`. A live session is never a test session, so it's consistent.

### Checks asked for
- History refreshes after a post from a session's page: yes. The panel invalidates `keptGamesProvider`, which History watches. New test.
- A session posted at its end shows Posted in History straight away: yes (`keepPosted` keeps it again and invalidates the list).
- The end panel after a correction made after the end: `Match.postable` turns false and the panel hides. History could still say Can be posted: fix 1.
- `Match.changedByHand` ignores a fell-out and a "?": yes. New tests.
- A knife added as 0 in a normal 5 × 3 session blocks posting at the end and in History: yes. New test.
- Build 14 records (knives, no `changedByHand`) say "kept before": yes. Existing test.
- The test board only in test builds: yes. New test.
- Overflow: the History card's status line fits at 320 dp with 1.6× text, and now wraps (`Flexible`). `HistoryPostPanel` is all wrapping text. Two layout risks elsewhere are in the open questions.

### Fixes (not committed)

**Fix 1: a score "changed" to its own value wasn't kept as a hand change**
- Bug: in a normal 5 × 3 session, picking the same score in the score picker sets `corrected` but changes no knife. `GameNotifier._keep` skipped the save (same knives, same `posted`), so the kept session still had `changedByHand: false`. The end panel stopped offering Post score, but History said Can be posted.
- Fix: `_keep`'s check also includes `changedByHand` (`lib/providers.dart`).
- Test: `score_post_test.dart`, "a score confirmed by hand at its own value after the end is kept as changed". It fails without the fix.

**Fix 2: leaving a session's page while posting lost the Posted mark**
- Bug: `HistoryPostPanel._post` used `ref` after the post. If the page was closed meanwhile (back, during Game Center sign-in or a slow signal), Riverpod throws on `ref`. The score reached Game Center, but the session wasn't kept as Posted, so it could be posted twice.
- Fix: read the history and the provider container before waiting (`lib/ui/history_post_panel.dart`).
- Test: `history_post_test.dart`, "leaving the page while posting: still kept as Posted". It fails without the fix.

**Small: the status line wraps**
- `PostStatusLabel`'s text is `Flexible`.
- Test: `history_post_test.dart`, "a small phone with large text: the status line fits".

**Tests added**
- `test/history/post_status_test.dart`: group "changed by hand, or not" (5 cases).
- `test/ui/history_post_test.dart`: back on the list says Posted; leaving mid-post; a test session posts to the test board; small phone.
- `test/ui/app_shell_test.dart`: the test board shown or hidden (2); Home skips a newer test session.
- `test/leaderboard/score_post_test.dart`: the same-value correction.

### Open questions for Nigel
1. **The Posted mark doesn't sync to another phone.** `SyncedGameHistory.sync` merges by id only. A session posted on one phone stays Can be posted on another phone that already had it. A post made offline isn't backed up later either. Should sync treat "posted on either copy" as posted? Recommended: yes (a small change to `sync`).
2. **A "?" in a normal 5 × 3 session.** It scores 0 and isn't a hand change, so the session can be posted with that 0. Setting it by hand blocks posting. Is that the rule you want?
3. **Play's end panel on a small phone.** The panel under the camera doesn't scroll, and a normal 5 × 3 session now adds the 3 m tick there. It could overflow on a small phone in landscape. Worth a device check, or making the panel scroll.
4. **History's app bar with large text.** At 320 dp and 2× text, "Clear history" overflows the app bar. This was there before the story. Fix it now, or log it?
5. **A post that goes but isn't kept** (the file can't be written) still says Can be posted. Accepted in Design Decisions.
6. Still to confirm on the Mac: the leaderboard week's exact start (`rankedLeaderboardStart`).
