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

| Part | Steps | Checks | Requirements |
|---|---|---|---|
| S: Set up | S0–S4 | print scale (100 mm bar), placement and mount recorded; S4 reads the in-app Instructions, *Paper target* version first, then skims *Real board* (clear / mostly / confusing) | story instructions R3, R4 |
| C: Camera | C1 camera prompt on Calibrate target, picture smooth?; C2 swipe up and return | camera permission, preview, lifecycle | setup R4 |
| F: Find the target | F1 find (confidence, ms, rings line up or turned/mirrored, screenshot); F2 ×3 repeat; F3 dim light; F4 at 1 m; F5 adjust and lock; F6 tap-to-score 5…0 | ring finder, coarse-to-fine, dim-light fallback, adjust/lock, mapping | calibration C1–C6, C8 |
| W: Watching | W1 still 20 s (false motion count); W2 wave → bounced off; W3 hand held → blocked → board visit | motion detector, blocked state, classifier | throw T-R1, T-R2 |
| K: Pen knives | K1–K3: ring by eye vs app score, dot distance from the pen tip (one near a line) | entry point, scoring | T-R3, calibration C5 |
| P: Play | P1 round of 2 sticks + bounce ("Round 1 of 9"); P2 collect → round 2; P3 fall-out (optional); P5 Reset game (cancel / confirm); P6 a whole 9-round game by hand-waves → Game over, extra throw ignored, New game (optional); P4 speed | game session, tracker, play screen, game over, reset | T-R4, T-R5, T-R6; story instructions R1, R2 |
| R: Real board (later) | R1 calibrate at 2 m / 45°; R2 two rounds, by eye vs app | the real thing | all |

Safety: with a real board, the phone and stand sit outside the throwing lane; the phone and the board are only approached when no one is throwing.

## Quick Draw Checks (added 2026-10-15)

For [[story-checkpoint-live-quick-draw]]: Nigel can't check the live camera himself, so these are for his brother, on his iPhone, from a TestFlight build **1.0.0 (7) or later** (`+6` was uploaded from the Mac on 2026-10-14). The interactive page above doesn't have these steps yet; record them in a message (or ask Claude to add a Q part to the page).

**Setup:** two A4 printouts side by side on a wall, about 1 m apart (or two real boards), the phone on a stand **behind where the throwers would stand**, 2–4 m back, seeing both. Pens in Blu Tack stand in for knives; nothing is thrown at paper. A TestFlight build is a release build: no frames/s label or debug line.

| Step | Do | Look for |
|---|---|---|
| Q0 | Open the app | Home shows **Play** ("Rounds on one target"; from build 8, "Rounds of 3 throws, 1 or 2 players") and **Quick draw** ("Two throwers, on a start signal"). Build number. |
| Q1 | Live test → Quick draw (the recording): tap the left bull, then the right, Lock boards, Play | GO! as the footage says go; "Player 2 wins: stuck 5, 0.82 s after go" (about) |
| Q2 | Home → **Quick draw**: tap Player 1's bull, then Player 2's, Lock boards | Both outlined and numbered, lining up with the rings (screenshot). A wrong outline: Choose boards again |
| Q3 | **Start**, three times | 5 beeps a second apart with 5 lights, a pause that differs each time (roughly how long?), then the long, higher beep as the lights go out (no GO! on screen since 2026-10-16). Also with the **silent switch on**, and with music playing (it should go quieter, not stop). **Stand 2–4 m in front of the phone, where a thrower would be: can you hear the beeps there?** Do the lights go out at the same moment as the long beep, or noticeably before it? |
| Q4 | **Paper only.** Start; right after the long beep, press a pen onto board 2, then a moment later wave a hand past board 1 | The result in large type: **Player 2 wins**, board 1 "bounced". Readable from 4 m? Times plausible (under a second or two)? How long after the throws did it appear? |
| Q5 | **Paper only.** Start; press a pen onto board 1 during the pause, before the long beep | Board 1: **false start** |
| Q6 | Start, then **Stop** during the beeps, and once after the long beep; later **Next duel** after a result | Stop: back to Start, no more beeps. Next duel: the boards stay locked |
| Q7 | Ten duels in a row (about 10 minutes) | Does the phone get hot? Does the picture stutter? Does the result take longer each time? |
| Q8 | Later, **real knives**: two experienced throwers, in separate lanes, under the venue's rules; a **third person (the starter) taps Start from behind**, with the phone out of reach of a backswing. Nobody goes forward until both have thrown and agree it's clear, whatever the screen shows (walking to the boards in Q4–Q5 is for paper only) | The winner and scores as seen by eye |

Safety: the phone stays behind the throwers, out of both lines of throw and not between the lanes; nobody goes forward until both have finished.

## Players and Targets Checks (added 2026-10-16)

For [[story-checkpoint-players-and-targets]] (Play for 1 or 2 players, on 1 target taking turns or on 2 targets at once): for Nigel's brother, from a TestFlight build **1.0.0 (8) or later** (Mac Handoff section 000). Record them in a message, as for Quick draw.

**Setup:** M1–M2 need nothing (recordings). M3–M4: one A4 printout, the phone as in Setup above (50 cm, 45°, on a tripod). M5–M8: two printouts side by side, the phone behind, as for Quick draw. Pens in Blu Tack stand in for knives; walking up to paper is fine, **with real knives nobody goes forward while anyone is throwing**.

| Step | Do | Look for |
|---|---|---|
| M0 | Home → **Play** | A setup screen: **1 player / 2 players**; with 2, **1 target / 2 targets**, each with a line saying what it means; **How many rounds? 3 / 5 / 9**; **Start**. 1 player, 9 rounds → Start plays as before; 3 rounds → "Round 1 of 3" |
| M1 | Live test → Target 1 → Calibrate → **2. Play** → 2 players, 1 target → Start | Large **"Player 1's turn"**; after the first round's knives are collected in the footage, **"Player 2's turn"**, and so on; both players' totals. Readable from where a thrower would stand? |
| M2 | Live test → **Play on two targets** (bottom of the page): tap the left bull, then the right, **Lock boards** | Player 1: a bounce-out (0); Player 2: stuck, **5**, each under its own player |
| M3 | **Paper, 1 target, 2 players.** Calibrate, Start; press 3 pens in | After the 3rd: **"Collect your knives"**, then "When no one is throwing. Then Player 2's turn." Take the pens out: **"Player 2's turn"**. The marks clear for Player 2 |
| M4 | Paper, 1 target: Player 1 presses 1 pen, then collects | The turn passes early: "Player 2's turn"; Player 1's round shows one throw |
| M5 | **Two printouts, 2 targets.** Start; tap Player 1's bull, then Player 2's, Lock boards. 3 pens into board 1 | Marks on board 1 only; **"Wait for Player 2"**. Then 3 pens into board 2: **"Collect your knives"**, "Together, when no one is throwing." Take all pens out: both on round 2 |
| M6 | 2 targets: wave a hand past board 2 only | A 0 for **Player 2 only**; Player 1's round unchanged |
| M7 | Optional: a whole 2-player game by hand-waves (either mode) | At the end, **"Player N wins"** or **"A draw"** in large type, every round for both, **New game** |
| M8 | 2 targets for about 10 minutes | Does the phone get hot? Does the picture stutter? |
| M9 | Later, **real knives**, 2 targets: two experienced throwers in separate lanes, under the venue's rules, the phone behind them out of both lines of throw. **Collect together, only when both have finished**, whatever the screen shows | Scores as seen by eye, on the right player |

Safety: "Player 2's turn", "Wait for Player 2" and "Collect your knives" follow the scores, not the lanes. With real knives, nobody goes forward until everyone has finished throwing and agrees it's clear.

## History Checks (added 2026-10-17)

For [[story-checkpoint-game-history]] (finished games of Play kept on the phone; Home → History). In the same TestFlight build as the Players and Targets Checks, **1.0.0 (8) or later**. Nigel can do H0–H4 himself on the Samsung from Android Studio: no throwing, only the Live test recordings.

| Step | Do | Look for |
|---|---|---|
| H0 | Home → **History** (before any game) | **"No games yet"**; no Clear history button |
| H1 | Live test → **Target 1** → Calibrate → **2. Play** → 1 player, **3 rounds** → Start; let the recording play past its third round (about the first minute and a half). Back to Home → **History** | One game: today's date and time, then **"1 player · 3 rounds · Live test: Target 1 · Total …"**, the same total Play showed at the end |
| H2 | Tap the game | Every round's score, the same as Play showed, and the total |
| H3 | Close the app fully (swipe it away), open it again → History | The game is still there |
| H4 | Play another (H1, or 2 players on 1 target), then: open one game and tap the **bin**; then **Clear history** → **Cancel**; then Clear history → **Clear** | The bin removes that game only; Cancel keeps the rest; Clear empties the list, "No games yet" |
| H5 | Start a game and **Reset game** half-way, or leave Play before it ends → History | Nothing new: only finished games are kept |

Nothing in History leaves the phone; deleting the app deletes it.

## When Results Come Back

Read them with `ArtifactData` `list` on the artifact's `results` collection, or from the pasted "Copy results" text. Also check App Store Connect → TestFlight → Feedback for his screenshots and crash reports. Record failures in [[Known Issues]] and as fixes. For a calibration failure, use his screenshot; if it needs the exact analysed frame, reproduce with a debug build attached to the Mac.
