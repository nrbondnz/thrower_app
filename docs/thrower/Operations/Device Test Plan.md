# Device Test Plan

Real-phone checks of the target calibration and throw detection stories, for Nigel's brother to run **on an iPhone, remotely, from a TestFlight build** (2026-10-08). The interactive version records each step's result for Nigel and Claude to read:

**https://claude.ai/artifact/ScmvKRs7GPj7QfTnwxWpW2** ("Thrower Field Test"; results in its `results` collection, one document per step id: `status`, `fields`, `note`, `updated`).

The page is private until Nigel shares it. **Share it with the tester as a Contributor** (he needs a claude.ai sign-in) so his results save to it. Otherwise share it by link: he can read it, the page keeps his answers on his phone, and he sends them with **Copy results** in a message.

## iPhone Notes

- **Install via TestFlight** (the tester is remote), as an **internal tester** (Nigel, 2026-10-08: immediate access, no beta review): Nigel adds him in App Store Connect with a limited role and access to this app only, then to an internal TestFlight group ([[Common Tasks#Ship a Build to TestFlight (Remote iPhone Testers)]]). He accepts two emails (App Store Connect, then TestFlight) and installs from the TestFlight app. Step S0 records the build number.
- **Release build:** no frames/s label, error detail or frame dump (all debug-only). C1 asks whether the picture is smooth instead.
- **Evidence:** **screenshots sent with TestFlight's *Share Beta Feedback*** at F1, K1, P1 and on any failure; they arrive in App Store Connect → TestFlight → Feedback, with any crash reports.
- **Biggest iPhone risk:** frame orientation (rings rotated or mirrored relative to the preview); F1 asks this explicitly.
- Auto-Lock off while testing.
- **Names:** the store/TestFlight name is **Knife and Axe Thrower**; the home-screen name is still **Thrower App** (`CFBundleDisplayName`).
- **Build:** 1.0.0 (2) or later (Instructions, 9-round games, Reset). Updated 2026-10-09, [[story-checkpoint-instructions-and-game-length]].

## Setup

A4 printout at 100% (`reference/printable/target-A4.pdf`), taped flat at chest height. Phone **about 50 cm away at ~45°**, **on a tripod** (or otherwise held completely still; re-calibrate if it moves): that's how the app sees an 80 cm board from 2 m. **A grey pen pushed into Blu Tack** (sticking out ~10 cm) stands in for a knife. Nothing is thrown at the printout.

## Steps and What They Verify

- **S: Set up**
  - **Steps:** S0–S4
  - **Checks:** print scale (100 mm bar), placement and mount recorded; S4 reads the in-app Instructions, *Paper target* version first, then skims *Real board* (clear / mostly / confusing)
  - **Requirements:** story instructions R3, R4
- **C: Camera**
  - **Steps:** C1 camera prompt on Calibrate target, picture smooth?; C2 swipe up and return
  - **Checks:** camera permission, preview, lifecycle
  - **Requirements:** setup R4
- **F: Find the target**
  - **Steps:** F1 find (confidence, ms, rings line up or turned/mirrored, screenshot); F2 ×3 repeat; F3 dim light; F4 at 1 m; F5 adjust and lock; F6 tap-to-score 5…0
  - **Checks:** ring finder, coarse-to-fine, dim-light fallback, adjust/lock, mapping
  - **Requirements:** calibration C1–C6, C8
- **W: Watching**
  - **Steps:** W1 still 20 s (false motion count); W2 wave → bounced off; W3 hand held → blocked → board visit
  - **Checks:** motion detector, blocked state, classifier
  - **Requirements:** throw T-R1, T-R2
- **K: Pen knives**
  - **Steps:** K1–K3: ring by eye vs app score, dot distance from the pen tip (one near a line)
  - **Checks:** entry point, scoring
  - **Requirements:** T-R3, calibration C5
- **P: Play**
  - **Steps:** P1 round of 2 sticks + bounce ("Round 1 of 9"); P2 collect → round 2; P3 fall-out (optional); P5 Reset game (cancel / confirm); P6 a whole 9-round game by hand-waves → Game over, extra throw ignored, New game (optional); P4 speed
  - **Checks:** game session, tracker, play screen, game over, reset
  - **Requirements:** T-R4, T-R5, T-R6; story instructions R1, R2
- **R: Real board (later)**
  - **Steps:** R1 calibrate at 2 m / 45°; R2 two rounds, by eye vs app
  - **Checks:** the real thing
  - **Requirements:** all

Safety: with a real board, the phone and stand sit outside the throwing lane; the phone and the board are only approached when no one is throwing.

## Quick Draw Checks (added 2026-10-15)

For [[story-checkpoint-live-quick-draw]]: Nigel can't check the live camera himself, so these are for his brother, on his iPhone, from a TestFlight build **1.0.0 (7) or later** (`+6` was uploaded from the Mac on 2026-10-14). The interactive page above doesn't have these steps yet; record them in a message (or ask Claude to add a Q part to the page).

**Setup:** two A4 printouts side by side on a wall, about 1 m apart (or two real boards), the phone on a stand **behind where the throwers would stand**, 2–4 m back, seeing both. Pens in Blu Tack stand in for knives; nothing is thrown at paper. A TestFlight build is a release build: no frames/s label or debug line.

- **Q0**
  - **Do:** Open the app
  - **Look for:** Home shows **Play** ("Rounds on one target"; from build 8, "Rounds of 3 throws, 1 or 2 players") and **Quick draw** ("Two throwers, on a start signal"). Build number.
- **Q1**
  - **Do:** Live test → Quick draw (the recording): tap the left bull, then the right, Lock boards, Play
  - **Look for:** GO! as the footage says go; "Player 2 wins: stuck 5, 0.82 s after go" (about)
- **Q2**
  - **Do:** Home → **Quick draw**: tap Player 1's bull, then Player 2's, Lock boards
  - **Look for:** Both outlined and numbered, lining up with the rings (screenshot). A wrong outline: Choose boards again
- **Q3**
  - **Do:** **Start**, three times
  - **Look for:** 5 beeps a second apart with 5 lights, a pause that differs each time (roughly how long?), then the long, higher beep as the lights go out (no GO! on screen since 2026-10-16). Also with the **silent switch on**, and with music playing (it should go quieter, not stop). **Stand 2–4 m in front of the phone, where a thrower would be: can you hear the beeps there?** Do the lights go out at the same moment as the long beep, or noticeably before it?
- **Q4**
  - **Do:** **Paper only.** Start; right after the long beep, press a pen onto board 2, then a moment later wave a hand past board 1
  - **Look for:** The result in large type: **Player 2 wins**, board 1 "bounced". Readable from 4 m? Times plausible (under a second or two)? How long after the throws did it appear?
- **Q5**
  - **Do:** **Paper only.** Start; press a pen onto board 1 during the pause, before the long beep
  - **Look for:** Board 1: **false start**
- **Q6**
  - **Do:** Start, then **Stop** during the beeps, and once after the long beep; later **Next duel** after a result (from build 9: **Next round**)
  - **Look for:** Stop: back to Start, no more beeps. Next duel / Next round: the boards stay locked
- **Q7**
  - **Do:** Ten duels in a row (about 10 minutes)
  - **Look for:** Does the phone get hot? Does the picture stutter? Does the result take longer each time?
- **Q8**
  - **Do:** Later, **real knives**: two experienced throwers, in separate lanes, under the venue's rules; a **third person (the starter) taps Start from behind**, with the phone out of reach of a backswing. Nobody goes forward until both have thrown and agree it's clear, whatever the screen shows (walking to the boards in Q4–Q5 is for paper only)
  - **Look for:** The winner and scores as seen by eye

Safety: the phone stays behind the throwers, out of both lines of throw and not between the lanes; nobody goes forward until both have finished.

## Players and Targets Checks (added 2026-10-16)

For [[story-checkpoint-players-and-targets]] (Play for 1 or 2 players, on 1 target taking turns or on 2 targets at once): for Nigel's brother, from a TestFlight build **1.0.0 (8) or later** (Mac Handoff section 000). Record them in a message, as for Quick draw.

**Setup:** M1–M2 need nothing (recordings). M3–M4: one A4 printout, the phone as in Setup above (50 cm, 45°, on a tripod). M5–M8: two printouts side by side, the phone behind, as for Quick draw. Pens in Blu Tack stand in for knives; walking up to paper is fine, **with real knives nobody goes forward while anyone is throwing**.

- **M0**
  - **Do:** Home → **Play**
  - **Look for:** A setup screen: **1 player / 2 players**; with 2, **1 target / 2 targets**, each with a line saying what it means; **How many rounds? 3 / 5 / 9**; **Start**. 1 player, 9 rounds → Start plays as before; 3 rounds → "Round 1 of 3"
- **M1**
  - **Do:** Live test → Target 1 → Calibrate → **2. Play** → 2 players, 1 target → Start
  - **Look for:** Large **"Player 1's turn"**; after the first round's knives are collected in the footage, **"Player 2's turn"**, and so on; both players' totals. Readable from where a thrower would stand?
- **M2**
  - **Do:** Live test → **Play on two targets** (bottom of the page): tap the left bull, then the right, **Lock boards**
  - **Look for:** Player 1: a bounce-out (0); Player 2: stuck, **5**, each under its own player
- **M3**
  - **Do:** **Paper, 1 target, 2 players.** Calibrate, Start; press 3 pens in
  - **Look for:** After the 3rd: **"Collect your knives"**, then "When no one is throwing. Then Player 2's turn." Take the pens out: **"Player 2's turn"**. The marks clear for Player 2
- **M4**
  - **Do:** Paper, 1 target: Player 1 presses 1 pen, then collects
  - **Look for:** The turn passes early: "Player 2's turn"; Player 1's round shows one throw
- **M5**
  - **Do:** **Two printouts, 2 targets.** Start; tap Player 1's bull, then Player 2's, Lock boards. 3 pens into board 1
  - **Look for:** Marks on board 1 only; **"Wait for Player 2"**. Then 3 pens into board 2: **"Collect your knives"**, "Together, when no one is throwing." Take all pens out: both on round 2
- **M6**
  - **Do:** 2 targets: wave a hand past board 2 only
  - **Look for:** A 0 for **Player 2 only**; Player 1's round unchanged
- **M7**
  - **Do:** Optional: a whole 2-player game by hand-waves (either mode)
  - **Look for:** At the end, **"Player N wins"** or **"A draw"** in large type, every round for both, **New game**
- **M8**
  - **Do:** 2 targets for about 10 minutes
  - **Look for:** Does the phone get hot? Does the picture stutter?
- **M9**
  - **Do:** Later, **real knives**, 2 targets: two experienced throwers in separate lanes, under the venue's rules, the phone behind them out of both lines of throw. **Collect together, only when both have finished**, whatever the screen shows
  - **Look for:** Scores as seen by eye, on the right player

Safety: "Player 2's turn", "Wait for Player 2" and "Collect your knives" follow the scores, not the lanes. With real knives, nobody goes forward until everyone has finished throwing and agrees it's clear.

## History Checks (added 2026-10-17)

For [[story-checkpoint-game-history]] (finished games of Play kept on the phone; Home → History). In the same TestFlight build as the Players and Targets Checks, **1.0.0 (8) or later**. Nigel can do H0–H7 himself on the Samsung from Android Studio: no throwing, only the Live test recordings.

- **H0**
  - **Do:** Home → **History** (before any game)
  - **Look for:** **"No games yet"**; no Clear history button
- **H1**
  - **Do:** Live test → **Target 1** → Calibrate → **2. Play** → 1 player, **3 rounds** → Start; let the recording play past its third round (about the first minute and a half). Back to Home → **History**
  - **Look for:** One game: today's date and time, then **"1 player · 3 rounds · Live test: Target 1 · Total …"**, the same total Play showed at the end
- **H2**
  - **Do:** Tap the game
  - **Look for:** Every round's score, the same as Play showed, and the total
- **H3**
  - **Do:** Close the app fully (swipe it away), open it again → History
  - **Look for:** The game is still there
- **H4**
  - **Do:** Play another (H1, or 2 players on 1 target), then: open one game and tap the **bin**; then **Clear history** → **Cancel**; then Clear history → **Clear**
  - **Look for:** The bin removes that game only; Cancel keeps the rest; Clear empties the list, "No games yet"
- **H5**
  - **Do:** Start a game and **Reset game** half-way, or leave Play before it ends → History
  - **Look for:** Nothing new: only finished games are kept
- **H6**
  - **Do:** Live test → Target 1 → Play, 1 player, **9 rounds**; after round 2's knives are collected in the footage, **Finish game** → Cancel, then Finish game → **Finish**
  - **Look for:** Cancel: play goes on. Finish: **"Game over after 2 of 9 rounds!"** (or 3, if round 3 had started: it counts) with the total; **New game**; no Finish game button. History: **"2 of 9 rounds"**
- **H7**
  - **Do:** Live test → Target 1 → Play, **2 players, 1 target**; Finish game during **Player 2's** first turn, or just after Player 1's second
  - **Look for:** The winner on the rounds both have played; Player 1's extra round shows **"(not counted)"**, and "Finished early: judged on 1 of 9 rounds." The same in History

Nothing in History leaves the phone; deleting the app deletes it.

## Score Corrections Checks (added 2026-10-17)

For [[story-checkpoint-score-corrections]] (tap a score to change it, or an empty slot to add a throw the camera missed). Nigel can do C0–C4 on the Samsung with the Live test; C5–C6 need the live camera and the A4 printout. **Only go to the phone when no one is throwing.**

- **C0**
  - **Do:** Live test → Target 1 → Play, 1 player
  - **Look for:** Under the totals, three big score slots (– – –)
- **C1**
  - **Do:** When the first knife scores, tap its slot → choose a different score
  - **Look for:** The popup shows 0–5 with the current score outlined; the slot, the circle on the picture (light blue) and the totals all change
- **C2**
  - **Do:** Tap the next empty slot (–) → **0**
  - **Look for:** A light-blue 0 beside the board; the round has one more throw; Cancel instead changes nothing
- **C3**
  - **Do:** After round 1's knives are collected: **Rounds** → Round 1 → change a throw → Done
  - **Look for:** Round 1's total and the game total change
- **C4**
  - **Do:** 2 players, 1 target: during Player 1's turn
  - **Look for:** Player 2's empty slots can't be tapped; Player 1's can
- **C5**
  - **Do:** Live camera, paper target, locked: open a score, tap the phone lightly, close it
  - **Look for:** No message; play goes on
- **C6**
  - **Do:** Open a score, knock or turn the stand a little, close it
  - **Look for:** **"The phone may have moved…"**; the green rings no longer on the board; calibrate again
- **C7**
  - **Do:** Later, real knives: a thrower misses the board altogether
  - **Look for:** Add it as 0 from the empty slot, when no one is throwing

## Quick Draw Match Checks (added 2026-10-19)

For [[story-checkpoint-quick-draw-match]] (from build 9): the live Quick draw as a **match of three rounds** (the rules from Nigel's brother: the first to stick wins a round, a bounce-out loses, the same frame → the higher score, the same score → a drawn round; level after three → extra rounds). On **paper** (pens pressed on by hand, as in Q4–Q5) unless it says real knives.

- **QM0**
  - **Do:** Home → Quick draw, lock both boards, **Start**; press a pen onto board 1 after the long beep
  - **Look for:** The result: **"Round 1 of 3"**, "Player 1 wins", each player's line, and **"Player 1 leads 1–0"**. Buttons: **Next round** and **Finish match**
- **QM1**
  - **Do:** Next round
  - **Look for:** Start, and the line "Round 2 of 3 (Player 1 leads 1–0). Throwers ready? …"; the boards stay locked
- **QM2**
  - **Do:** Round 2: board 1 again (2–0), then round 3
  - **Look for:** Round 3 is still played at 2–0. After it: **"Player 1 wins the match 3–0"** (or 2–1) in large green type, and **New match**
- **QM3**
  - **Do:** New match; play three rounds so it ends level (e.g. 1–1 and a round with no throws)
  - **Look for:** After round 3: **Extra round**; the line says "Extra round (Level 1–1)…"; the first extra round won ends the match
- **QM4**
  - **Do:** New match; after one round, **Finish match** → Cancel, then Finish match → Finish
  - **Look for:** Cancel: the match goes on. Finish: the match result straight away (level is "Match drawn")
- **QM5**
  - **Do:** Is the result panel readable from the throwing line (about 4 m), held the way he uses the phone (upright or sideways)?
  - **Look for:** Round, winner and match line readable; nothing cut off
- **QM6**
  - **Do:** Later, **real knives**, as Q8: two experienced throwers, separate lanes, the starter behind them taps Start and Next round
  - **Look for:** Each round's winner as seen by eye; knives collected together between rounds; nobody goes to the phone during a round

## Named Players Checks (added 2026-10-19)

For [[story-checkpoint-named-players]] (from build 9): players can be given names in place of "Player 1" and "Player 2". Nigel can do N0–N5 on the Samsung with the Live test; N6 needs the live camera.

- **N0**
  - **Do:** Live test → Target 1 → Play, **2 players, 1 target**: type two names (e.g. Jo, Sam) → Start
  - **Look for:** "Jo's turn" in large type; the totals "Jo: …" / "Sam: …"; the correction rows labelled Jo / Sam
- **N1**
  - **Do:** Play to the end (or **Finish game**)
  - **Look for:** "Jo wins" / "Sam wins" / "A draw"; then **History**: the game says "Sam wins 61–58" and its page heads the rounds with the names
- **N2**
  - **Do:** Close the app completely, open it, Play
  - **Look for:** The names are filled in again
- **N3**
  - **Do:** Clear one name → Start
  - **Look for:** That player is "Player 1" (or "Player 2") again
- **N4**
  - **Do:** Type a long name (e.g. "Bartholomew Smithson")
  - **Look for:** It stops at 16 letters; "…'s turn" still fits the screen; the correction row shows its first letters ("Barth…")
- **N5**
  - **Do:** Live test → Quick draw: **Names** → change them → Save, then choose the boards and Play
  - **Look for:** "Tap the centre of Jo's board"; the result line names the winner; Cancel instead changes nothing
- **N6**
  - **Do:** Live camera: Home → Quick draw with names, one round
  - **Look for:** "Jo wins", "Jo leads 1–0"; **Names** is hidden once Start is tapped

## Adjust Boards Checks (added 2026-10-19)

For [[story-checkpoint-adjust-boards]] (backlog #10, from build 9): either board's outline can be dragged into place before locking, and **Adjust boards** unlocks them. Nigel can do A0–A4 on the Samsung with the Live test; A5 needs the live camera.

- **A0**
  - **Do:** Live test → Quick draw: tap both bulls
  - **Look for:** Both outlines in blue, each with two white handles; "Both boards found. Drag an outline…"
- **A1**
  - **Do:** Drag inside board 2 a little to one side, then back
  - **Look for:** Only board 2 moves, smoothly; board 1 stays put
- **A2**
  - **Do:** Drag a white handle on board 1
  - **Look for:** Board 1 turns or stretches; let go and it stays; the rings keep lining up with the paint when dragged back
- **A3**
  - **Do:** Lock boards, then **Adjust boards**
  - **Look for:** The boards unlock, both kept (no need to tap them again); drag one, Lock again; Play works as before
- **A4**
  - **Do:** Play → 2 players, 2 targets (Live test): lock, play a little, **Adjust boards**, drag, Lock boards
  - **Look for:** The scores so far stay; watching starts again ("ready" for both)
- **A5**
  - **Do:** Live camera, Quick draw: after a round, **Adjust boards**
  - **Look for:** Shown between rounds, hidden once Start is tapped; the match score carries on

## Account Checks (added 2026-10-19)

For [[story-checkpoint-app-user-accounts]] (accounts on AWS Amplify, London). Named **ACC**n so they don't clash with the story's acceptance criteria (AC1–AC7). Nigel on the Samsung, with a build that has the backend's settings ([[Common Tasks]] → Connect the App to the Amplify Backend).

- **ACC0**
  - **Do:** Open the app, signed out
  - **Look for:** **Home straight away**, never a sign-in screen; the person icon top right; Play, History and Quick draw all work signed out
- **ACC1**
  - **Do:** Person icon → Create account (email) → the emailed code → signed in
  - **Look for:** "Signed in as" your email; done 2026-10-19 ("sign in works")
- **ACC2**
  - **Do:** Sign out; sign in again; close the app fully and reopen
  - **Look for:** Still signed in after reopening
- **ACC3**
  - **Do:** (After Task 3 deploys) Person icon → **Sign in with Google**
  - **Look for:** Google's page says **Thrower**, then back in the app signed in; done 2026-10-20 ("google sign in works", Samsung, job 7)
- **ACC4**
  - **Do:** (After Task 3, iPhone) **Sign in with Apple**
  - **Look for:** Apple's sheet, then signed in
- **ACC5**
  - **Do:** (After Task 4 deploys) Signed in, play and finish a game → Account
  - **Look for:** "Your games and player names are backed up." (or "Backed up: 1 game sent…")
- **ACC6**
  - **Do:** Sign in on a second phone (or clear the app's data and sign in again)
  - **Look for:** History and the player names come back ("…brought to this phone")
- **ACC7**
  - **Do:** Airplane mode, finish a game, then signal back → Account → **Back up now**
  - **Look for:** The game stays in History throughout; it backs up once there's signal
- **ACC8**
  - **Do:** **Delete account** → Cancel; then Delete account → confirm
  - **Look for:** Cancel: nothing changes. Confirm: signed out; signing in with that email fails; the phone's History stays. **Claude checks** with the CLI that the Cognito user and every `KeptGame` / `PlayerNameList` row of that `sub` are gone
- **ACC9**
  - **Do:** Two test accounts, A and B: A backs up a game; then B signs in on another phone (or after clearing the app's data)
  - **Look for:** B's History doesn't get A's game. **Claude checks** with the CLI that each user's rows are theirs (`allow.owner()`); this replaces the story's "tests against the sandbox" (no sandbox)

## Game Type Checks (added 2026-10-20)

For [[story-checkpoint-more-game-types]]: two more games on Play, **Precision** and **Three targets**, scored by hand on a score pad (no camera). Nigel on the Samsung; no board or knives needed (tap made-up scores). Named **GT**n.

- **GT0**
  - **Do:** Home → Play: tap each chip under **Which game?** in turn (Scoring, Precision, Three targets), with 2 players
  - **Look for:** Scoring: How many targets? and 3 / 5 / 9 rounds, as before. Precision: no target choice, "7 rounds" (fixed), the distances in the description. Three targets: no target choice, 3 / 5 / 7 rounds (7 chosen), "one knife at each target"
- **GT1**
  - **Do:** Precision, **1 player** → Start
  - **Look for:** The score pad (no camera): "Your turn" in large type, "Round 1 of 7: from 3 m"; buttons 5, 4, 3, 2, 1 and **Miss**; the line about scoring when no one is throwing
- **GT2**
  - **Do:** Tap 3 scores; then 3 more
  - **Look for:** After 3, "Collect your knives"; the next tap starts round 2, "from 5 m"; the rounds line "Rounds: 3 m: …, 5 m: …"; the distances follow 3, 5, 7, 3, 4, 5, 7 m
- **GT3**
  - **Do:** Finish all 21 knives
  - **Look for:** "Game over! N" with N the sum of the taps; **New game** shows
- **GT4**
  - **Do:** Home → **History**: the Precision game, then open it
  - **Look for:** The line starts "Precision · 1 player · 7 rounds"; the game's page lists "Round 1 (3 m): …" to "Round 7 (7 m): …"; no "Live test" mark
- **GT5**
  - **Do:** Play → Three targets, **2 players** named (e.g. Jo, Sam), 3 rounds → Start
  - **Look for:** "Jo's turn", "Round 1 of 3: at target 1"; after each tap the target goes 2, then 3
- **GT6**
  - **Do:** Tap Jo's 3 knives, then Sam's 3, and play to the end
  - **Look for:** After Jo's third: "Collect your knives" and "When no one is throwing. Then Sam's turn."; then "Sam's turn" at target 1; at the end "Jo wins" / "Sam wins" / "A draw" matching the totals
- **GT7**
  - **Do:** In a new game, tap **Miss**; then tap a score in a player's row and change it
  - **Look for:** Miss counts 0; the changed score shows light blue with ✎ and the total updates
- **GT8**
  - **Do:** Mid-game, **Finish game** → Cancel, then Finish game → confirm; then **New game**
  - **Look for:** Cancel changes nothing; confirming ends the game ("Finished early: judged on N of M rounds" with two players) and keeps it in History; New game starts the same game type afresh, the names kept
- **GT9**
  - **Do:** Signed in, finish a Precision game → Account
  - **Look for:** It's backed up ("Your games and player names are backed up." or "Backed up: 1 game sent…"); on another phone (or after clearing the app's data and signing in) it comes back as Precision, with its distances

## Board Finding Checks (added 2026-10-21)

For [[story-checkpoint-gapped-rings]] (requirement [[Board Finding]]): Mark's stencilled boards (rings painted in arcs with gaps) are found by **Tap the board** on Play's Calibrate. Nigel on the Samsung for BF0–BF7, with a picture of Mark's boards on the PC monitor; BF8 is for Mark on his real boards. Named **BF**n.

**Setup:** open `test/fixtures/marks_boards/frame-1s.jpg` full-screen on the PC monitor (three boards on a fence, the middle one near the picture's centre). Put the phone on a stand facing the monitor, so the picture of the boards fills most of the camera view. No knives needed: nothing is thrown at a monitor.

- **BF0**
  - **Do:** Home → Play (1 player, 1 target) → Calibrate → **Find target**
  - **Look for:** "Target not found: … Try Tap the board." or "Not sure about the target (…) … or tap the board.", or an outline in the wrong place (the net, or the wrong board). Either is expected: Find target alone doesn't read these boards
- **BF1**
  - **Do:** Look at the buttons before tapping anything else
  - **Look for:** **Tap the board** shows beside Find target (and Lock target, if an outline is shown)
- **BF2**
  - **Do:** Tap **Tap the board**
  - **Look for:** The outline disappears; the status says "Tap the middle of the board in the picture."; the "only when no one is throwing" note shows; Find target is greyed out; the button now says **Cancel tap**
- **BF3**
  - **Do:** Tap **Cancel tap**, then Tap the board again
  - **Look for:** Cancel returns to the previous status (no search runs); the second Tap the board waits for a tap again
- **BF4**
  - **Do:** Tap the **middle board's red bull** on the picture
  - **Look for:** A short search, then an outline whose rings sit on the paint: the red bull, then the two broken black rings. Note the time the status shows (ms)
- **BF5**
  - **Do:** Drag the outline a little if needed, then **Lock target**; tap the picture on the red bull, the inner black ring, the outer black ring, and the wood beyond it
  - **Look for:** Red = 5, inner black = 3, outer black = 1, beyond the outer black = 0 (wood between the black rings: 4 and 2)
- **BF6**
  - **Do:** Re-calibrate → Tap the board → tap the **right board's** bull (in shade); then try again tapping a little to the right of its bull
  - **Look for:** On the bull: an outline on its rings. A little to the right: may be wrong (a known limit, [[Known Issues]] → Stencilled Boards); dragging the outline, or tapping again on the bull, fixes it
- **BF7**
  - **Do:** Close the picture. Play → Live test (one of Nigel's recordings) → Calibrate → **Find target**
  - **Look for:** Found as before, with no tap: Nigel's own boards are unchanged. Also try Tap the board on its bull: found the same
- **BF8 (Mark, on his real boards)**
  - **Do:** Phone on a stand beside the lane, out of the line of throw, with the whole of the board being thrown at in view. Play → Calibrate → Find target; if it isn't found, **Tap the board** and tap the middle of that board. Only when no one is throwing. Lock, then throw a round
  - **Look for:** The outline on the rings of the board tapped (not a neighbour); throws score red 5, wood 4, inner black 3, wood 2, outer black 1. A screenshot of the outline before locking, and of any wrong score

## Drawn Board Checks (added 2026-10-21)

For [[story-checkpoint-quick-draw-areas]] (from build 9; requirement [[Game Type]], Quick draw): Quick draw's boards **drawn round by finger**, timed only, never scored (Mark's request). Nigel can do QA0–QA4 on the Samsung with Live test → Quick draw (the recording); QA5–QA7 need the live camera, on **paper** (pens pressed on by hand, as in Q4–Q5) unless it says real knives. Named **QA**n. Drawing is on the screen, never at the boards, and only when no one is throwing.

- **QA0**
  - **Do:** Live test → Quick draw. Before tapping anything, look at the buttons; tap **Draw round the boards**
  - **Look for:** The button shows before any board is chosen; it now says **Tap the boards**; the line says "Draw a finger round the edge of Player 1's board (round, square or rectangular). Any knife that sticks inside counts: the time wins, not the score."
- **QA1**
  - **Do:** Drag a finger round the left board, just outside its outer ring; lift; then round the right board
  - **Look for:** A light blue path follows the finger; on lift it becomes an outline round the board with **no rings** inside, and player number 1 above it; then the same for 2; "Both boards found. Drag an outline to fit its board…"
- **QA2**
  - **Do:** Choose boards again; make a tiny loop (a small flick) on board 1, then a long thin stroke
  - **Look for:** Each time: "That loop is too small or too flat for a board. Draw a finger round…"; no outline added; a proper loop then works
- **QA3**
  - **Do:** With both drawn, drag one outline inside to move it, and a white handle to stretch it; Lock boards; then **Adjust boards** and drag again; Lock
  - **Look for:** The drawn outlines move and stretch as tapped ones do, still with no rings; they stay drawn (no rings appear) after Adjust boards
- **QA4**
  - **Do:** Lock boards → Play
  - **Look for:** Under each board only a time ("0.82 s"), no score; the bottom line "Player 2 wins: stuck, 0.82 s after go. Player 1 bounced out." (no "stuck 5")
- **QA5**
  - **Do:** Leave Quick draw (back), then Home → Quick draw (live); and Choose boards again there
  - **Look for:** Still in drawing mode (the button says **Tap the boards**): the choice is kept for the session. After closing and reopening the app it's back to tapping
- **QA6**
  - **Do:** Live: draw round both boards, Lock, Start; after the long beep press a pen onto both boards **at the same moment** (two people, or one hand each), a few rounds
  - **Look for:** Times only on the result panel; when both land on the same frame, **"A draw"** (no score to break it), and the round counts for neither
- **QA7**
  - **Do:** Home → Play → 2 players, 2 targets → choose the boards
  - **Look for:** **No** Draw round the boards button: two-target Play still taps the boards and scores the rings, as before
- **Mark, on his real boards (with QM6's safety: separate lanes, a starter behind the throwers):** draw round each board, play a match. Do the times and winners match what he sees? A screenshot of the drawn outlines before locking.

### Round or Four-Cornered Boards (added 2026-10-21)

For [[story-checkpoint-board-outlines]] (from build 10; requirement [[Game Type]], Quick draw; why in [[Design Decisions]] → Quick Draw: Round or Four-Cornered Boards): a loop drawn round a **square or rectangular** board becomes four corners, a round one stays an oval. QA8 can be done on Live test → Quick draw (the recording's boards are round); QA9–QA14 need the live camera. A sheet of A4 paper taped flat makes a rectangular board; a square of card makes a square one; knives are only pens pressed on by hand, as in Q4–Q5. Drawing and dragging are on the screen, never at the boards, and only when no one is throwing.

- **QA8 (a round board stays round)**
  - **Do:** Live test → Quick draw → Draw round the boards; draw round each round board, even a bit shakily
  - **Look for:** Both become ovals (no corners), with the two white handles in the drag stage as before; the line says "Draw a finger round the edge of Player 1's board (round, square or rectangular)…"
- **QA9 (a square board)**
  - **Do:** Live Quick draw, the phone square on to a square of card; draw round its edges, going into each corner
  - **Look for:** A four-cornered outline whose corners sit on the card's corners (not an oval); a white handle on each corner while it can be adjusted; player number above it
- **QA10 (a rectangle seen from the side)**
  - **Do:** Move the phone well to one side of an A4 sheet (as when the phone sits beside the lane); draw round the sheet
  - **Look for:** Four corners on the sheet's corners as the camera sees them: the far edge shorter than the near one (not squared up into a rectangle)
- **QA11 (drag a corner)**
  - **Do:** Before locking, drag one corner handle a little; drag inside the outline to move it; Lock boards; then **Adjust boards** and drag a corner again; Lock
  - **Look for:** Only that corner moves with the finger; dragging inside moves the whole outline; after Adjust boards the corners are still there and draggable
- **QA12 (a fold refused)**
  - **Do:** Drag one corner across the outline, past the opposite edge
  - **Look for:** The corner stops following once the outline would cross itself (the outline never folds into a bow tie); dragging it back works
- **QA13 (a board running off the picture)**
  - **Do:** Frame the phone so a sheet runs off the side of the picture; draw round it, going past the picture's edge
  - **Look for:** The outline is cut at the picture's edge (corners on the edge, none outside the picture); the board can still be locked and played
- **QA14 (a knife in a corner counts)**
  - **Do:** With square or rectangular boards locked, Start; after the long beep press a pen onto one board **right in a corner**, and onto the other near its middle
  - **Look for:** Both are seen and timed ("0.82 s"); the corner one isn't missed. Also a pen just **outside** a board's edge, a hand's width away: not counted

## Ranked Game Checks (added 2026-10-22)

For [[story-checkpoint-game-center-scores]] (requirement [[Rankings]]; why in [[Design Decisions]] → Ranked Games and Game Center): **Ranked: 5 × 3 at 3 m**, strict mode and posting to a monthly Game Center leaderboard. RK0–RK4 and RK9 work on any build with the story (a real board, or the A4 printout with pens in Blu Tack). RK5–RK8 need the **iPhone** with the Game Center setup done ([[Mac Handoff]] → Build 11) and a TestFlight build; sandbox scores are kept apart from live ones. Changing a score means going to the phone: only when no one is throwing. Named **RK**n.

- **RK0 (setup)**
  - **Do:** Home → Play → Which game? → **Ranked: 5 × 3 at 3 m**
  - **Look for:** No How many players / targets (one name field only); "5 rounds" fixed; the description mentions strict mode and posting; **Start** greyed out until **I'm throwing from 3 m** is ticked. Via Live test (a recording chosen and calibrated) → Play: **no Ranked chip**
- **RK1 (the game)**
  - **Do:** Tick 3 m → Start; calibrate; throw (or press pens into the printout)
  - **Look for:** The title says **"Ranked · 3 m"**; throws scored by the camera as in Scoring; 5 rounds of 3
- **RK2 (strict popup on a score)**
  - **Do:** Between rounds, tap a scored throw's slot
  - **Look for:** The popup offers **only 0**, with "Ranked game: a score can only be changed to 0 (a bounce-out, or a miss)."; tapping 0 makes it 0 (light blue, ✎) and the total drops
- **RK3 (strict popup on an empty slot and an earlier round)**
  - **Do:** When a throw wasn't seen, tap the empty slot; then **Rounds** → an earlier round → a throw
  - **Look for:** Both offer only 0 with the same note; no way to enter 1–5 anywhere
- **RK4 (finished early)**
  - **Do:** A new Ranked game; after 2 rounds, **Finish game** → confirm
  - **Look for:** "Game over after 2 of 5 rounds!"; **no Post score** and no View leaderboard; the game is in History as Ranked
- **RK5 (post a full game, iPhone)**
  - **Do:** Signed in to Game Center (Settings → Game Center); play all 5 rounds → **Post score (N)**
  - **Look for:** "Posting…", then **"Posted to the leaderboard: N."** with N the game's total; the Post score button goes (it can't post twice)
- **RK6 (locked after posting)**
  - **Do:** After RK5, tap a score slot; look for **Rounds**
  - **Look for:** Nothing opens; Rounds is gone; the total stays N. **New game** → a new Ranked game shows Post score again at its end
- **RK7 (View leaderboard)**
  - **Do:** Tap **View leaderboard**
  - **Look for:** Apple's leaderboard screen opens on "3 m · 5 rounds of 3" for the **current week** (the leaderboard restarts weekly), with the RK5 score under your Game Center nickname; closing it returns to Play
- **RK8 (not signed in; no signal)**
  - **Do:** Sign out of Game Center in Settings, finish a Ranked game → Post score; then sign in again → Try again. Separately, Airplane mode → Post score
  - **Look for:** Not signed in: "Sign in to Game Center (in the iPhone's Settings) to post, then try again." with **Try again**, which posts once signed in. No signal: "Couldn't post the score. Check the signal and try again." with Try again. No crash either way
- **RK9 (Android)**
  - **Do:** On the Samsung, launch the app; play a full Ranked game
  - **Look for:** No Google Play Games sign-in popup or warning at launch; at the end **no Post score or View leaderboard** (Android can't post yet, backlog #21); RK0–RK4 behave as on the iPhone
- **RK10 (15 knives; a posted score is final)**
  - **Do:** In a Ranked game, collect the knives after only 2 throws in one round (walk to the board), then finish all 5 rounds. Then tap that round (Rounds) and add the missing knife as 0. On a later game, post the score, then pull a knife out of the board before collecting
  - **Look for:** After 5 rounds with a short round: the game is over but **no Post score**; after adding the 0: **Post score** appears. After posting, pulling a knife out **doesn't change** the total on Play or in History

## Round Done Checks (added 2026-10-23)

For the follow-up to [[story-checkpoint-game-center-scores]] (requirements [[Round Play]] and [[Rankings]]; why in [[Design Decisions]] → Rounds Move On: Round Done). A round used to wait for the camera to see the knives collected, so three bounce-outs left Play stuck on "Round complete…". Any phone; a real board, or the A4 printout with a hand wave for a bounce-out. Go to the phone only when no one is throwing. Named **RD**n.

- **RD0 (Ranked: three bounce-outs move on)**
  - **Do:** A Ranked game; throw 3 knives that all bounce out (printout: wave a hand 3 times)
  - **Look for:** After the 3rd, **Round 2 of 5** shows by itself, with no Round done button and no one at the board. Play on to 5 rounds without collecting: **Post score** appears (iPhone)
- **RD1 (Scoring: Round done starts round 2)**
  - **Do:** A one-player Scoring game; 3 bounce-outs (or 3 knives, then don't go to the board)
  - **Look for:** **Round done** appears under the scores only after the 3rd throw; tapping it shows round 2, empty, and the button goes. A knife from round 1 that then falls out still scores 0
- **RD2 (one target, two players: Round done passes the turn)**
  - **Do:** 2 players, 1 target; Player 1 throws 3 bounce-outs
  - **Look for:** **Round done** appears; tapping it makes it **Player 2's turn**. After Player 2's 3 throws, Round done again starts round 2 with Player 1
- **RD3 (two targets: only once both have finished)**
  - **Do:** 2 players, 2 targets; Player 1 throws 3, Player 2 only 2
  - **Look for:** No Round done while Player 2 is still throwing; it appears after Player 2's 3rd throw, and tapping it starts round 2 on both boards. No Round done once the game is over

## App Design Checks (added 2026-10-23)

For [[story-checkpoint-app-design]] (requirements [[Look and Feel]] and [[Throwing Stats]]; design in [[App Design Index]]; why in [[Design Decisions]] → App Design: Themes, Tabs and Stats). Any phone, build 1.0.0 (14) or later. Named **AD**n.

**Older checks' paths:** the checks above were written for the old Home. Read them as:
- "Home → Play" = **START THROWING** on Home (or Throw → Rounds);
- "Home → Quick draw" = Home or Throw → **Quick draw**;
- "Home → History" = the **History** tab;
- "Home → Calibrate target", "Home → Live test", "Home → Instructions" = the **Setup** tab;
- "Home → Account" (the person icon) = Setup → **Account**.

- **AD0 (the tabs)**
  - **Do:** Open the app; tap each tab along the bottom
  - **Look for:** Four tabs: **Home, Throw, History, Setup**; each opens its page, and the tab is highlighted. No crash
- **AD1 (Home's hero and last session)**
  - **Do:** On Home before any session (a fresh install, or after Clear history), then again after throwing one full one-thrower session
  - **Look for:** The target drawn in red and wood, **THROWER**, and "Every throw seen. Every score counted." Before: "Your sessions will show here." After: the kind and time (e.g. "Scoring · 23 Oct, 14:32"), **Points**, **Per knife** and **5s** matching the session; tapping the card opens History. A two-thrower session shows each thrower's points instead
- **AD2 (Start throwing)**
  - **Do:** Tap **START THROWING**; Back; tap the **Rounds** card; Back; tap **Quick draw**
  - **Look for:** Start throwing and Rounds open Play's setup (players, targets, Which game?). Quick draw opens the live Quick draw. The bar is hidden on those screens, and Back returns to Home
- **AD3 (Throw tab and the Leaderboard)**
  - **Do:** Open **Throw** on the iPhone, then on the Samsung
  - **Look for:** iPhone: **Rounds**, **Quick draw** and **Leaderboard**; Leaderboard opens Game Center's ranked table (signed in to Game Center). Samsung: Rounds and Quick draw only, no Leaderboard
- **AD4 (Setup's tools and Account)**
  - **Do:** Open **Setup**; tap Instructions, Calibrate target, Live test and Scoring test target in turn (Back after each)
  - **Look for:** Each opens as it did from the old Home. **Account** shows only in a build with accounts, and opens the Account screen. Home no longer has the tools or the person icon
- **AD5 (Appearance, kept after restart)**
  - **Do:** Setup → Appearance → **Light**; look at Home, Throw and History. Then **Dark**. Then close the app fully (swipe it away) and open it again
  - **Look for:** Light: off-white pages, white cards, amber buttons. Dark: charcoal pages, dark cards, amber buttons. After the restart, Dark is still chosen and shown
- **AD6 (Phone follows the phone's dark mode)**
  - **Do:** Setup → Appearance → **Phone**. Switch the phone's own dark mode on, then off (Control Centre or Settings)
  - **Look for:** The app goes dark, then light, with the phone, without restarting
- **AD7 (camera screens stay dark)**
  - **Do:** Appearance → **Light**. Open Play (START THROWING → Start), Calibrate target, the live Quick draw, and a Precision session's score pad
  - **Look for:** Each is dark (black around the picture, white text), as before. Back on Home, it's light again
- **AD8 (History's stats, checked by hand)**
  - **Do:** Clear history (or note the numbers first). Throw two one-thrower Scoring sessions on this build. Write down each knife's score from Play. Open **History**
  - **Look for:** **Sessions** 2; **Knives** = knives thrown; **Per knife** = points ÷ knives (one decimal place); **5s** = knives in the bull; **Hit rate** = knives that scored ÷ knives thrown; **Best round** = the best round total. After a full Ranked session: **Best ranked** = its total, in place of Best round. Live test sessions don't change the numbers
- **AD9 (sessions kept before the knives were)**
  - **Do:** On a phone with sessions kept by build 13 or earlier, install build 14 over it (TestFlight update, never delete), then throw one more session; open History
  - **Look for:** Sessions counts them all; under the stats: "Knives, per knife, 5s and hit rate: from the 1 of N sessions kept with each knife." The older sessions still open with every round. A phone whose sessions all came from build 14 shows no such note
- **AD10 (Play's big total)**
  - **Do:** One thrower, any Scoring session; throw a round
  - **Look for:** The session total in large amber numbers with "points" under it, above a bolder round line; both readable from the throwing line. Two throwers look as before
- **AD11 (History's look)**
  - **Do:** Open History with a few sessions; tap one; Back
  - **Look for:** The stats card on top, then SESSIONS, each session a card (when in bold; how it was played and the result). Tapping opens every round, as before; Delete and Clear history still work

## Posting From History Checks (added 2026-10-23)

For [[story-checkpoint-posting-from-history]] (requirement [[Rankings]]; why in [[Design Decisions]] → Posting From History). Build 1.0.0 (15) or later. Posting needs the **iPhone**, signed in to Game Center (Settings → Game Center), and a TestFlight build made with the test tools ([[Mac Handoff]] → Build 15). TestFlight has no Game Center sandbox, so real sessions post to the real board, and test sessions only to the Test board. Go to the phone only when no one is throwing. Named **PH**n.

**Changes to older checks:** the **Throw** tab is now **Leaderboards**. Read AD0's tabs as Home, Leaderboards, History, Setup, and AD3 as PH7. Rounds and Quick draw are on Home, under **Throwing types**.

- **PH0 (test sessions: add)**
  - **Do:** Setup → **Test sessions (test build only)** → **Add 10 test sessions**; open History
  - **Look for:** "Added 10 test sessions to History."; 10 new sessions dated this week, each marked **Test · Can be posted**. A mix of Ranked and Scoring, 5 rounds each
- **PH1 (the status on each card)**
  - **Do:** In History, look at your own sessions: a Ranked one, a normal 5-round Scoring one, a 2-player one, a Live test one, a score-pad one (Precision or Three targets)
  - **Look for:** Every card ends with **Can be posted**, **Posted** or **Cannot be posted**. Sessions kept before this build say Cannot be posted
- **PH2 (why it can't be posted)**
  - **Do:** Open several Cannot be posted sessions
  - **Look for:** Under the status, "Why: …" with a reason that fits: two throwers; played on a Live test recording; scored on the score pad; only 3 m, 5 rounds of 3 can be posted; not a full 5 rounds of 3 knives; a score was changed by hand; thrown in an earlier leaderboard week; kept before sessions could be posted from History
- **PH3 (post a Ranked session from History)**
  - **Do:** Open a session that says Can be posted and is Ranked (a test one is fine) → **Post score (N)**
  - **Look for:** No 3 m tick (Ranked asked at its start). "Posting…", then "Posted to the leaderboard: N."; the status turns **Posted** and the button goes. Back in History, the card says Posted. (A test session goes to the Test board: PH12)
- **PH4 (post a normal session: the 3 m tick)**
  - **Do:** Open a Scoring session that says Can be posted
  - **Look for:** **I threw from 3 m (board to throwing line)**, unticked; Post score is greyed out until it's ticked. Tick it → Post score → Posted, as PH3
- **PH5 (a normal session at its end)**
  - **Do:** One thrower, Scoring, 5 rounds, no score changed by hand; throw all 5 rounds (3 knives each)
  - **Look for:** At the end, **Post score** with the 3 m tick, greyed until ticked; posting works as for Ranked. Then in History the session says **Posted**. Change one score by hand in another such session: no Post score at the end, and History says "a score was changed by hand"
- **PH6 (Posted stays Posted)**
  - **Do:** After PH3–PH5, close the app fully and open it again; open History
  - **Look for:** The posted sessions still say **Posted**, with no Post score. With an account signed in, they still say Posted after a backup
- **PH7 (the Leaderboards tab)**
  - **Do:** Tap **Leaderboards** at the bottom; tap **3 m knives · 3 × 5**
  - **Look for:** The tab bar reads Home, Leaderboards, History, Setup. The page shows the 3 m knives · 3 × 5 card and a "More to come" line (friends, area, club). In a test build, a second card: **Test: 3 m knives · 3 × 5**. Tapping a card opens that Game Center board for this week
- **PH8 (an earlier week)**
  - **Do:** After the leaderboard's week has turned over (a week after 2026-10-23, or later), open a session from the week before that wasn't posted
  - **Look for:** **Cannot be posted**, "Why: thrown in an earlier leaderboard week." A session from the new week can still be posted. Note the day and time the change happened (it checks the leaderboard's start time)
- **PH9 (Android)**
  - **Do:** On the Samsung: open History and a session that can be posted; open the Leaderboards tab
  - **Look for:** The statuses show as on the iPhone. A session's page says "Posting is on the iPhone for now." with no Post score. Leaderboards says "Leaderboards are on the iPhone (Game Center) for now."
- **PH10 (Throwing types)**
  - **Do:** Open Home
  - **Look for:** The heading above Rounds and Quick draw says **Throwing types** (not Quick actions); both cards open as before
- **PH11 (test sessions: left out, then removed)**
  - **Do:** Note History's stats and Home's last session. Add 10 test sessions; look again. Then Setup → **Remove test sessions**
  - **Look for:** Adding them doesn't change the stats or Home's last session. Remove says "Removed N test sessions." and only the Test sessions go; your own sessions stay. Signed in to an account: test sessions don't appear on another phone after a backup
- **PH12 (a test session posts to the Test leaderboard only)**
  - **Do:** In the TestFlight build (test tools), post a **Test** session from History with an unusual total (note it). Then Leaderboards → **Test: 3 m knives · 3 × 5**, and then **3 m knives · 3 × 5**
  - **Look for:** The total is on the **Test** board under your Game Center nickname, and **not** on the real 3 m knives · 3 × 5 board
- **PH13 (no test tools without the flag)**
  - **Do:** Install a **store**-flavor release build (Android: `app-store-release.apk`; iPhone: an archive of the **store** scheme, or, until the schemes exist, a build made without `THROWER_TEST_TOOLS`). Open Setup, Leaderboards, and History on a phone that still has Test sessions
  - **Look for:** Setup has **no Test sessions (test build only)** section. Leaderboards shows only 3 m knives · 3 × 5, no Test board. Any Test session says **Cannot be posted**, "Why: a test session, in a build without the test tools."

## Compliance Checks (added 2026-10-23)

For [[story-checkpoint-compliance]] (requirements [[Instructions and Safety]], [[Accounts and Sign-In]], [[Website]]; why in [[Design Decisions]] → Compliance: Policies and Help and Support). Build 1.0.0 (15) or later on the iPhone; a PC build on the Samsung. Do CP0 to CP4 on **both phones**. CP5 and CP6 wait until the website pages are published ([[Common Tasks]] → Publish the Website Pages): until then the links open but show "not found". Named **CP**n.

- **CP0 (Help and support on Setup)**
  - **Do:** Open **Setup**
  - **Look for:** A section headed **Help and support** with: Instructions, Support (Email us: kaat-support@knifeandaxethrower.com), Help online, Privacy Policy, Terms of Service, Delete account. Instructions opens as before
- **CP1 (the web links open)**
  - **Do:** Tap **Help online**, then **Privacy Policy**, then **Terms of Service**, coming back to the app each time
  - **Look for:** Each opens in the phone's browser (Safari, or Chrome on the Samsung), outside the app, at knifeandaxethrower.com/support, /privacy and /terms. Back in the app, Setup is as it was. Before publishing, a "not found" page is fine
- **CP2 (Support opens the mail app)**
  - **Do:** Tap **Support**
  - **Look for:** The mail app opens a new email to **kaat-support@knifeandaxethrower.com**, subject **Thrower support**. If the phone has no mail app set up, a message at the bottom gives the address instead (no crash)
- **CP3 (Delete account without accounts)**
  - **Do:** Tap **Delete account** (in a build with no accounts, as TestFlight builds are now)
  - **Look for:** A page, **Delete account**: "There is no account on this phone"; sessions and names are only on this phone; delete sessions in History (Clear history); Game Center scores are kept by Apple. Nothing is deleted by opening it
- **CP4 (the Delete Your Account website button)**
  - **Do:** On the CP3 page, tap **Delete Your Account (website)**
  - **Look for:** The browser opens knifeandaxethrower.com/delete-account. (In a build with accounts, later: Delete account on Setup opens the Account screen instead, with its own Delete account; see AC checks)
- **CP5 (the published pages)**
  - **Do:** After publishing, open each page on knifeandaxethrower.com: /privacy, /terms, /support, /delete-account, /delete-data
  - **Look for:** Each says **Last updated 23 October 2026** (or a later date if changed since). Privacy has section 4, Leaderboards (Apple Game Center). Terms has section 5, Leaderboards. Delete account names Setup → Help and support → Delete account. Support has the posting and leaderboard answers. Every footer links all five. Repeat CP1 and CP4: now the real pages show
- **CP6 (Play's account deletion URL works without the app)**
  - **Do:** On a computer, or a phone without Thrower, in a private browser window: open **https://knifeandaxethrower.com/delete-account**
  - **Look for:** The page opens with no sign-in, says how to delete an account in the app or by email, and what's deleted and kept. (Google Play checks this URL from outside the app)

## Leaderboard Table Checks (added 2026-10-23)

For [[story-checkpoint-monthly-tables]] (backlog #22; requirement [[Rankings]]; why in [[Design Decisions]] → Leaderboard Tables: This Week and Last Week). The first build with the tables from the Mac (build 15 or later), on the iPhone, signed in to Game Center, after the leaderboard setup. LT7 is on the Samsung. Named **LT**n.

- **LT0 (This week shows the posted scores and your row)**
  - **Do:** Post a score (a ranked session, or one from History). Then **Leaderboards** → **3 m knives · 3 × 5**
  - **Look for:** A screen with **This week** and **Last week** tabs, on This week. Rows of place, Game Center nickname and score, best first. Your row is highlighted with "(you)" and your posted total. Pull down to refresh: the same rows
- **LT1 (Last week, in the first week)**
  - **Do:** Tap **Last week** (before the leaderboard's first week has ended)
  - **Look for:** "No results for last week yet." No error and no spinner left turning. After the first week ends: last week's rows instead
- **LT2 (This week with no scores)**
  - **Do:** If you can, open the table at the start of a new week, before anyone posts
  - **Look for:** "No scores yet this week. Post one at the end of a full session."
- **LT3 (signed out of Game Center)**
  - **Do:** iPhone Settings → Game Center → sign out. Open the table. Then sign back in and tap **Try again**
  - **Look for:** "Sign in to Game Center (in the iPhone's Settings) to see the leaderboard." with **Try again**. After signing in, Try again shows the table
- **LT4 (no signal)**
  - **Do:** Turn on airplane mode. Open the table (or pull to refresh). Then turn airplane mode off and tap **Try again**
  - **Look for:** "Couldn't load the leaderboard. Check the signal and try again." with **Try again**; no crash. With signal back, Try again shows the table
- **LT5 (Open in Game Center)**
  - **Do:** On the table screen, tap **Open in Game Center**
  - **Look for:** Apple's own leaderboard screen for 3 m knives · 3 × 5, with the same scores. Closing it comes back to the table
- **LT6 (View leaderboard from the end of a session)**
  - **Do:** Finish a postable session, tap **Post score**, then **View leaderboard**
  - **Look for:** The app's table opens (not Apple's screen) on **This week**, with the new score in it. Back returns to Play
- **LT7 (Android)**
  - **Do:** On the Samsung, open the **Leaderboards** tab
  - **Look for:** "Leaderboards are on the iPhone (Game Center) for now." No table and no crash
- **LT8 (a long nickname)**
  - **Do:** Look at a row with a long Game Center nickname (change yours to a long one if none, then refresh)
  - **Look for:** The name is cut short with "…". The place and score stay in line and readable. "(you)" still shows on your row if it fits

## Small Fixes Checks (added 2026-10-23)

For the small fixes in commit 7939fa2 (requirements [[Look and Feel]], [[Rankings]], [[Game Recording]]; why in [[Design Decisions]] → Small Fixes: Play's Panel and Posted Sync). Named **SF**n.

- **SF0 (a small phone at the end of a session)**
  - **Do:** On the smallest phone you have, with large text on (Settings → Display → Text size), finish a postable session on Play
  - **Look for:** **Post score**, **View leaderboard** and **New game** are all in sight without scrolling. The scores above them scroll. The camera picture still shows above the panel
- **SF1 (two throwers on one target)**
  - **Do:** Play with 2 players on 1 target. Throw a round each, with large text on
  - **Look for:** **Round done** stays in sight under the scores. With 2 targets, the board buttons (Adjust boards) stay in sight too
- **SF2 (posted on one phone, Posted on the other)**
  - **Do:** Signed in to the same account on two phones, post a session on one. On the other, sign in again (or **Back up now**), then open History
  - **Look for:** The session says **Posted** on both, and neither offers Post score. (Needs a build with accounts)
- **SF3 (the Clear history icon)**
  - **Do:** Open **History** with some sessions kept. Long-press the bin icon at the top, then tap it
  - **Look for:** A bin icon (not the words) in the title bar, with the tooltip "Clear history". Tapping it asks first, as before. It fits with large text on

## Store Hygiene Checks (added 2026-10-23)

For [[story-checkpoint-store-release-hygiene]] (backlog #6; requirement [[Instructions and Safety]]; why in [[Design Decisions]] → Store-Release Hygiene). Named **SH**n.

- **SH0 (no test tools in a store build)**
  - **Do:** Install a **store**-flavor release build (Android: `app-store-release.apk`; iPhone: an archive of the **store** scheme, or, until the schemes exist, a build made without `THROWER_TEST_TOOLS`). Open **Setup**, then Setup → **Instructions** → Quick draw
  - **Look for:** Tools has only **Calibrate target**: no **Live test** and no **Scoring test target**. The Quick draw instructions don't mention the Live test recording
- **SH1 (present in a test build)**
  - **Do:** Install a **beta**-flavor build (TestFlight from the beta scheme, `app-beta-release.apk`, or a debug run with `--flavor beta`). Open Setup, then the Instructions' Quick draw section
  - **Look for:** Tools has **Calibrate target**, **Live test** and **Scoring test target**, and each opens as before. The Quick draw instructions mention the Live test recording (Setup, then Live test, then Quick draw)

## Flavor Checks (added 2026-10-23)

For [[story-checkpoint-store-release-hygiene]] Task 2 (two build flavors, **beta** and **store**; why in [[Design Decisions]] → Build Flavors: Beta and Store). FL2 waits for the Mac's Xcode schemes ([[Mac Handoff]] → Flavors: beta and store schemes). Named **FL**n.

- **FL0 (the store APK: no Live test, no test tools)**
  - **Do:** On the Samsung, `flutter build apk --release --flavor store`, then `adb install -r build/app/outputs/flutter-apk/app-store-release.apk`. Open **Setup**, **Leaderboards** and Setup → **Instructions** → Quick draw
  - **Look for:** Tools has only **Calibrate target**. No **Test sessions (test build only)** section, no Test leaderboard card. The Quick draw instructions don't mention the Live test recording. The APK is about 76 MB, not about 164 MB. History and names are still there (same app ID)
- **FL1 (the beta APK: both)**
  - **Do:** `flutter build apk --release --flavor beta`, then `adb install -r build/app/outputs/flutter-apk/app-beta-release.apk`. Open the same screens
  - **Look for:** Tools has **Calibrate target**, **Live test** and **Scoring test target**. **Test sessions** is on Setup, and the Test board on Leaderboards. Live test plays a recording. The Quick draw instructions mention the Live test recording
- **FL2 (an iPhone archive from each scheme)**
  - **Do:** On the Mac, once the schemes exist: archive **beta** and install it (TestFlight), then archive **store** (an App Store build; check it before any submission)
  - **Look for:** The beta archive has `flutter_assets/assets/live/`, and Setup has Live test and Test sessions. The store archive has no `assets/live/`, and Setup has no test tools. `grep FLAVOR ios/Flutter/Generated.xcconfig` showed the matching flavor before each archive
- **FL3 (Live test absent when the recordings are missing)**
  - **Do:** On the iPhone, before the Xcode schemes exist: a build with no flavor, made with `THROWER_TEST_TOOLS` (or a debug run from Xcode). It has test tools but no recordings
  - **Look for:** Setup has **Scoring test target** and Test sessions, but **no Live test**. The Quick draw instructions don't mention the Live test recording. Nothing crashes

## When Results Come Back

Read them with `ArtifactData` `list` on the artifact's `results` collection, or from the pasted "Copy results" text. Also check App Store Connect → TestFlight → Feedback for his screenshots and crash reports. Record failures in [[Known Issues]] and as fixes. For a calibration failure, use his screenshot; if it needs the exact analysed frame, reproduce with a debug build attached to the Mac.
