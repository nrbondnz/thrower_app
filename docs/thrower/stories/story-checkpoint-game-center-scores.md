# Story Checkpoint: Post Scores to Game Center

## Story Goal
Nigel, 2026-10-22: "How can I set up Game Center to be able to store scores? There would be a best 3 meter score table refreshed each month, previous month results table etc. But to start I would just like to allow users to post scores for particular games, lets say 5 sets of 3 knives at 3 meters." Then: "if they are posting to game centre they would have to go into a strict mode where they can only change scores to mark a bounce out but not to change scores to higher"; full games only; Android not postable for now (backlog #21). Requirement: [[Rankings]].

## Complexity Score
6 (Large): scoring rules → game wiring → UI → a leaderboard service (4 layers); a native plugin and the Game Center capability (platform, Review Agent) (1); more than 3 acceptance criteria (1).

## Status
IN PROGRESS: plan approved 2026-10-22 ("yes, go ahead"); run whole, committing per task ([[dont-ask-again]]); Task 4 stops for the Mac and App Store Connect.

## Acceptance Criteria
1. Play's setup offers a ranked game, **Ranked: 5 × 3 at 3 m** (1 player, one target, scored by the camera), asking the thrower to confirm they throw from 3 m.
2. **Strict mode** in a ranked game: tapping a score offers only **Bounce-out (0)**; an empty slot can only be filled with 0. No score can be raised. (Elsewhere, corrections are as today.)
3. Only a **full** ranked game (all 5 rounds; not Finish game early) can be posted.
4. At the end of a postable game, **Post score** (iPhone only) sends the total (0–75) to the Game Center leaderboard, says whether it went, and can't post the same game twice. On Android the button doesn't show (backlog #21).
5. The leaderboard restarts each month (an App Store Connect setting); **View leaderboard** opens Apple's leaderboard screen.
6. The Instructions explain ranked games, strict mode and posting.

## Story Plan

### Task 1: The ranked game and strict mode (rules, tested)
- **Setup:** Score corrections ([[story-checkpoint-score-corrections]]) and game types ([[story-checkpoint-more-game-types]]) exist.
- **Work:** `GameType.ranked` (5 rounds of 3, 3 m, 1 player, one target, camera-scored); strict corrections in the rules (`setScore` only to 0, adding only 0, refused otherwise); `postable` (ranked, over, not finished early).
- **Verify:** tests: a raise refused, a bounce-out allowed, an added miss allowed, an added 3 refused; a full game postable, an early finish not; Scoring games unchanged.
- **Status:** COMPLETE (2026-10-22)
- **What changed:**
  - `lib/scoring/game_type.dart`: `GameType.ranked` ("Ranked: 5 × 3 at 3 m", 5 rounds only), `strict`, `rankedDistance` (3; `distanceOf` gives it for each round); `handScored` now names Precision and Three targets (Ranked uses the camera).
  - `lib/scoring/match.dart`: strict mode in the rules: `setScore`, `byHand` and `addToRound` refuse anything but 0 when `type.strict` (`_refused`); `postable` (Ranked, one player, over, not finished early).
  - Ranked cases in the setup text and the score pad's switch (it never uses the pad). Ranked already shows under Which game?; Task 2 fixes it to 1 player and adds the 3 m confirmation.
- **Test Report:** `game_type_test.dart` +14 (5 rounds from 3 m; only Ranked strict; bounce-out allowed; raise and change to 1 refused; added 0 allowed, 4 refused; added 2 to a collected round refused, 0 allowed; Scoring unchanged; postable after 5 full rounds (75); not mid-game, not finished early, not a Scoring game, not two players; a Ranked game reads back from History); the defaults and hand-scored lists updated. `flutter analyze`: no issues. `flutter test`: 965 passed.

### Task 2: The screens
- **Work:** Ranked under Which game? on Play's setup (players and targets fixed at 1; the 3 m confirmation); in Play, a "Ranked · 3 m" label and the strict popup (Bounce-out (0) / Cancel); the Instructions section.
- **Verify:** widget tests; on the phone, set up a ranked game and see the strict popup.
- **Status:** COMPLETE (2026-10-22)
- **What changed:**
  - `play_setup_screen.dart`: Ranked hides How many players and targets (always 1 player, one name field, 5 rounds); **I'm throwing from 3 m** (`playRankedDistance`) must be ticked before Start; the description says strict mode and posting (`typeDescription`, no score-pad sentence for Ranked).
  - `play_screen.dart`: `playTitle`: "Ranked · 3 m" (calibrated or not).
  - `score_corrections.dart`: in a strict game the popup offers only 0, with `strictNote` ("Ranked game: a score can only be changed to 0 (a bounce-out, or a miss)."), for a score, an empty slot and an earlier round.
  - `instructions.dart`: a **Ranked games** section (what it is, the 3 m confirmation, strict mode, full games only).
- **Test Report:** `score_corrections_test.dart` +3 (only 0 with the note; bounce-out sets 0; an empty slot adds only 0); `play_setup_screen_test.dart` +2 (one player and 5 rounds, the strict description; Start waits for 3 m, then a 5-round ranked solo game titled "Ranked · 3 m"); `instructions_test.dart` (the section, in order; strict and full-game sentences). `flutter analyze`: no issues. `flutter test`: 970 passed.

### Task 3: Posting, behind a leaderboard interface
- **Work:** `LeaderboardService` (like `AuthService`): `isAvailable`, `signIn`, `submit(leaderboard, score)`, `show(leaderboard)`; a fake for tests; **Post score** and **View leaderboard** at the end of a postable game, showing posted, failed (try again) or not signed in to Game Center. Nothing native yet: the app's service says "not available".
- **Verify:** widget tests with the fake (posted once, failure and retry, hidden for an early finish and on Android).
- **Status:** COMPLETE (2026-10-22)
- **What changed:**
  - `lib/leaderboard/leaderboard_service.dart` (new): `Leaderboard.ranked3m` (ID `ranked.3m.5x3`) and `LeaderboardService` (`signIn`, `submit`, `show`).
  - `lib/providers.dart`: `leaderboardServiceProvider` (null: this build can't post; `main` will override it on the iPhone in Task 4); `ScorePost` (ready, posting, posted, signedOut, failed) and `ScorePostNotifier.post()` (only a `postable` game, never twice; signs in first; back to ready when a new game starts).
  - `lib/ui/post_score_panel.dart` (new), on Play once the game is over: **Post score (N)**, then posted / sign in to Game Center / couldn't post (Try again); **View leaderboard**. Nothing without a service (Android) or for a game that can't be posted.
  - **Plan change:** once posted, the game's scores can't be corrected (`ScoreCorrections` locks its slots and Rounds), so the leaderboard always matches what Play shows.
- **Test Report:** new `test/leaderboard/score_post_test.dart`: 13 (posts the total once; not signed in; no signal then retry; not mid-game, finished early or Scoring; ready again for a new game; the panel's Post score, posted line, Try again, View leaderboard, hidden for an early finish and without a service; corrections locked once posted). `flutter analyze`: no issues. `flutter test`: 983 passed.

### Task 4: Game Center (stops for the Mac and App Store Connect)
- **Work:** the Flutter plugin (likely `games_services`: check it posts to a recurring leaderboard), `GameCenterLeaderboardService`, iOS only; "Be Careful" Review Agent before committing the plugin. Nigel: App Store Connect → Game Center → a **recurring monthly** leaderboard (ID e.g. `ranked.3m.5x3`, whole number, high to low, range 0–75); Xcode (in the foreground) → **+ Game Center** capability; tick Game Center on the app version. Steps written into the Mac Handoff.
- **Verify:** a TestFlight build: post a score from a ranked game and see it in View leaderboard (sandbox).

### Task 5: Docs, device checks, traceability
- **Work:** Docs Agent (requirement [[Rankings]], Design Decisions, glossary, web pages, Device Test Plan, Mac Handoff); Traceability Agent; an Android build (the button hidden).

## Assumptions (say if wrong)
- Ranked games are **one player** on the phone: Game Center posts for the person signed in to Game Center on that iPhone.
- The 3 m distance is the thrower's word (a confirmation), as Precision's distances are.
- A ranked game is camera-scored (not the score pad).

---

## Plan Changes Log
- **2026-10-22 (Task 3):** a posted game's scores are locked (not in the plan): otherwise a correction to 0 after posting would leave the leaderboard higher than Play.
