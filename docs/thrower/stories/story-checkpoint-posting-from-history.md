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
PLANNED 2026-10-23: waiting for Nigel's approval. Then run whole, committing per task.

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
- **Verify:** widget tests with the fake leaderboard; on the iPhone, post one from History (TestFlight posts to Game Center's sandbox).

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
- A Test session posted from a TestFlight build goes to Game Center's **sandbox** leaderboard, which is separate from the live one.
- Sessions kept before this story don't record hand changes, so they show **Cannot be posted: kept before posting from History**.

---

## Plan Changes Log
- (none yet)
