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
| Q0 | Open the app | Home shows **Play** ("Rounds on one target") and **Quick draw** ("Two throwers, on a start signal"). Build number. |
| Q1 | Live test → Quick draw (the recording): tap the left bull, then the right, Lock boards, Play | GO! as the footage says go; "Player 2 wins: stuck 5, 0.82 s after go" (about) |
| Q2 | Home → **Quick draw**: tap Player 1's bull, then Player 2's, Lock boards | Both outlined and numbered, lining up with the rings (screenshot). A wrong outline: Choose boards again |
| Q3 | **Start**, three times | 5 beeps a second apart with 5 lights, a pause that differs each time (roughly how long?), then the long, higher beep as the lights go out (no GO! on screen since 2026-10-16). Also with the **silent switch on**, and with music playing (it should go quieter, not stop). **Stand 2–4 m in front of the phone, where a thrower would be: can you hear the beeps there?** Do the lights go out at the same moment as the long beep, or noticeably before it? |
| Q4 | **Paper only.** Start; right after the long beep, press a pen onto board 2, then a moment later wave a hand past board 1 | The result in large type: **Player 2 wins**, board 1 "bounced". Readable from 4 m? Times plausible (under a second or two)? How long after the throws did it appear? |
| Q5 | **Paper only.** Start; press a pen onto board 1 during the pause, before the long beep | Board 1: **false start** |
| Q6 | Start, then **Stop** during the beeps, and once after the long beep; later **Next duel** after a result | Stop: back to Start, no more beeps. Next duel: the boards stay locked |
| Q7 | Ten duels in a row (about 10 minutes) | Does the phone get hot? Does the picture stutter? Does the result take longer each time? |
| Q8 | Later, **real knives**: two experienced throwers, in separate lanes, under the venue's rules; a **third person (the starter) taps Start from behind**, with the phone out of reach of a backswing. Nobody goes forward until both have thrown and agree it's clear, whatever the screen shows (walking to the boards in Q4–Q5 is for paper only) | The winner and scores as seen by eye |

Safety: the phone stays behind the throwers, out of both lines of throw and not between the lanes; nobody goes forward until both have finished.

## When Results Come Back

Read them with `ArtifactData` `list` on the artifact's `results` collection, or from the pasted "Copy results" text. Also check App Store Connect → TestFlight → Feedback for his screenshots and crash reports. Record failures in [[Known Issues]] and as fixes. For a calibration failure, use his screenshot; if it needs the exact analysed frame, reproduce with a debug build attached to the Mac.
