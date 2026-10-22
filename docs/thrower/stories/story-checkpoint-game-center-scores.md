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
- **Status:** PC side COMPLETE (2026-10-22); **waiting for Nigel** on the Mac and in App Store Connect ([[Mac Handoff]] → 000000 → Game Center setup, before build 11), then the TestFlight check.
- **What changed:**
  - `pubspec.yaml`: `games_services: 5.3.0` (published 2026-08-02; iOS 14+ pod; the app targets iOS 15).
  - `lib/leaderboard/game_center_leaderboard_service.dart` (new): `signIn` (GameKit sign-in, then whether signed in), `submit` (`submitScore` to `ranked.3m.5x3`; Game Center's error throws → Try again), `show`.
  - `lib/main.dart`: the service on the iPhone only (`Platform.isIOS`); Android has none, so no Post score.
  - `android/app/src/main/AndroidManifest.xml`: **Review Agent fix**: the plugin's Play Games pieces removed (`tools:node="remove"`: `PlayGamesInitProvider`, `GamesResolutionActivity`, the exported `PlayGamesAppShortcutsActivity`), which otherwise started Play Games at every Android launch for nothing.
  - Docs: [[Mac Handoff]] (the App Store Connect leaderboard, `pod install`, the Xcode Game Center capability, ticking Game Center on the version, privacy labels, the check); [[Privacy Policy (Draft)]] (a Game Center section).
- **Safety Report (Review Agent, 2026-10-22):** DO NOT COMMIT until the Play Games start-up pieces are removed; done and re-checked (merged manifest: none left; release APK 156.0 MB; on the phone: starts, no Play Games warning). Passed: permissions (none new), iOS target, nothing at start on iOS, no secrets, failures handled (sign-in cancelled, leaderboard missing, no signal), panel only after the game, rollback. Before TestFlight: the Game Center entitlement and leaderboard (Nigel). Before the App Store: privacy labels (User Content → Gameplay Content) and the policy section.
- **Test Report:** new `test/leaderboard/game_center_leaderboard_service_test.dart`: 3 (the score goes to `ranked.3m.5x3` with its value; Game Center's refusal throws; View leaderboard opens it). Sign-in is left to the device check (it reads the plugin's player stream). `flutter analyze`: no issues. `flutter test`: 986 passed.

### Task 5: Docs, device checks, traceability
- **Work:** Docs Agent (requirement [[Rankings]], Design Decisions, glossary, web pages, Device Test Plan, Mac Handoff); Traceability Agent; an Android build (the button hidden).

#### Doc Update: 2026-10-22 (Docs Agent)

**Files updated**
- `requirements/Game Centre/Rankings.md`: status 🟡 partly built; What Exists Today (Ranked, strict mode, full games only, Post score / View leaderboard, the monthly leaderboard, Android none, what's not yet); Monthly Ranking; the Trust question answered for the first step; links to Design Decisions.
- `requirements/Basic Setup/Scoring Rules.md`: strict mode (and locked once posted); the rankings question answered.
- `requirements/Basic Setup/Game Type.md`: Ranked in What's Wanted and What Exists Today (not offered on a Live test recording).
- `requirements/Instructions and Safety.md`: the *Ranked games* section, including the posting paragraph added in Task 5.
- `requirements/Requirements Index.md`: Rankings 💭 → 🟡; notes on Scoring Rules and Game Type.
- `Architecture/Design Decisions.md`: new **Ranked Games and Game Center (2026-10-22)** (the game, strict mode, full games only, `LeaderboardService`, the recurring monthly leaderboard, post once and lock, `games_services`, the Android manifest removals, privacy); More Game Types' `handScored` note.
- `Architecture/Glossary.md`: `GameType.ranked` / `strict` / `rankedDistance`, `Match.postable`, the Ranked setup, `strictNote`, corrections locked once posted, `LeaderboardService` (`Leaderboard`, `GameCenterLeaderboardService`, `leaderboardServiceProvider`, `ScorePostNotifier`, `PostScorePanel`); concepts Ranked game, Strict mode, Leaderboard (recurring), Posted.
- `Architecture/System Diagram.md`: the Ranked UI, the wiring, a LEADERBOARD box, `games_services` in native code, an Apple Game Center box; the plugin rule.
- `Architecture/Data Flow.md`: new **Ranked Game: Posting a Score to Game Center**; App Start notes the iPhone's leaderboard override.
- `tool/web_docs/content.py` (+ `build.py`: the overview's Auth column also shows LeaderboardService): component `leaderboard-service`, flow `ranked-post`, Ranked in Screens, Providers and GameSession; rebuilt `docs/web/`.
- `Operations/Device Test Plan.md`: **Ranked Game Checks RK0–RK9**.
- `Operations/Mac Handoff.md`: Game Center goes out in build 11 (build 10 was bumped before these commits); RK checks in Then.
- `Troubleshooting/Known Issues.md`: `games_services` starts Google Play Games on Android (the manifest removals).
- `CLAUDE.md`, `docs/working-with-nigel.md`: the story in progress; `lib/leaderboard/`.

**Checked, consistent:** [[Privacy Policy (Draft)]] → Game Center; [[Mac Handoff]]'s setup steps (leaderboard ID `ranked.3m.5x3`, 0–75, recurring monthly) match `Leaderboard.ranked3m`.

**Drift items**
- `lib/` and `test/` had uncommitted Task 5 changes while these docs were written (Ranked left out on a Live test recording, `ScorePostNotifier.canPost`, the Instructions' posting paragraph). The docs describe them; recheck the docs if those changes are altered before they are committed.

## Assumptions (say if wrong)
- Ranked games are **one player** on the phone: Game Center posts for the person signed in to Game Center on that iPhone.
- The 3 m distance is the thrower's word (a confirmation), as Precision's distances are.
- A ranked game is camera-scored (not the score pad).

---

## Plan Changes Log
- **2026-10-22 (Task 3):** a posted game's scores are locked (not in the plan): otherwise a correction to 0 after posting would leave the leaderboard higher than Play.

---

## Traceability Report — 2026-10-22
- 6 acceptance criteria: AC1, AC2, AC4 covered; AC3 and AC6 had gaps; AC5 waits for Nigel's Game Center setup and the TestFlight check. No orphan code. No other way found to raise a ranked score (fell-out only sets 0; History can't edit; the score pad is never reached).
- **Fixed (2026-10-22):**
  - **G1:** a Ranked game played on a Live test recording could be posted. Play's setup leaves Ranked out on a recording; `ScorePostNotifier.canPost` (and so the panel) refuses a recording.
  - **G3:** New game while a score was posting marked the new game posted. `post()` only settles its answer if the game is still the same; corrections are also locked while posting (G3b).
  - **G4:** solo was enforced by the setup screen only; `GameNotifier.build` now makes a ranked game solo whatever mode was last chosen.
  - **G6:** the Instructions now explain Post score and View leaderboard (iPhone, Game Center sign-in, public nickname, monthly restart, locked once posted, not Android or Live test).
  - **G7:** View leaderboard signs in first and says so if it can't open.
  - Tests: `score_post_test.dart` +5 (a recording not posted; New game while posting; ranked forced solo; locked while posting; View leaderboard's message), `play_setup_screen_test.dart` +1 (no Ranked on a recording), `instructions_test.dart` (the posting sentences). `flutter test`: 992 passed.
- **For Nigel (rules decisions):**
  - **G2:** Post score appears as soon as the last knife lands, before the knives are collected; a knife that then falls out lowers Play and History but not a score already posted. Offer Post score only after the last round's knives are collected, or ignore falling out once posted?
  - **G5:** a round collected early (fewer than 3 knives) still counts as a round, so a "full" game can have fewer than 15 knives. Require 3 throws in every round (strict mode can add a 0) before posting?
  - **G8:** in strict mode a knife the camera saw stick but couldn't place scores 0 and can't be set to its real score. Accept (camera failures cost points), or allow setting such a "?" throw?
- **Nigel's answers (2026-10-22), built the same day:**
  - **G2:** "The user should choose to post at the end of the game if they want to share their score": Post score stays an optional choice at the end; a posted score is final (`GameNotifier.markFinal` while posting and after: a knife falling out no longer changes it; undone if the post fails).
  - **G5:** yes, 3 per round: `Match.postable` needs every round's 3 throws (missing ones can be added as 0).
  - **G8:** keep a "?" throw at 0; the Instructions say so.
  - Tests: `game_type_test.dart` +2 (a short round: over but not postable; the 0 added: postable); `score_post_test.dart` +2 (a knife falling out after posting changes nothing; before posting it scores 0 and the lower total is posted); `instructions_test.dart` (15 knives, "?" stays 0). Device check RK10. `flutter test`: 996 passed.
