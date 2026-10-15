# Story Checkpoint: Live Quick Draw

## Story Goal
Quick draw with the phone's **live camera**: two throwers, one board each, side by side, throwing on the app's own start signal. The app times each knife from "go", sees whether it sticks and scores it, and says who won, readable from the throwing line. Nigel, 2026-10-15: *"start the live camera quick draw, but as a different button so its clear, one version is for scoring rounds on one target and the other is quick draw."* Builds on the recording version, [[story-checkpoint-quick-draw]] (archived). Backlog #9 (and the live-camera part of #10).

**Not in this story:** recording and sharing with scoring overlays, for Quick draw and for Play. That's the next story ("Record and share", [[backlog]] #11), with Nigel's decisions already taken (below).

## Complexity Score
7 (Large): UI → camera → vision → game (4), a new start-signal flow with false starts (1), platform-dependent camera settings (60 fps, sideways Android frames) (1), more than 3 acceptance criteria (1).

## Status
IN PROGRESS: Task 1 built, waiting for Nigel's device check (2026-10-15). Backlog #12 (Play's round display) fixed first, at Nigel's request.

## Decisions (Nigel, 2026-10-15)
- **A separate Home button, "Quick draw"**, beside **Play**: Play stays single-target rounds (9 rounds of 3); Quick draw is the two-thrower duel. Live test → Quick draw stays for the recording.
- **Two stories**, live Quick draw first, then record and share.
- For the next story (recorded here so it isn't lost): overlays are **composited after recording** (the camera's own video plus a timeline of scoring events, drawn on by the phone's video framework when sharing: AVFoundation on iOS, Media3 on Android; no FFmpeg); **Play records each throw as a short clip**; recordings have **sound from the microphone** (a new permission: Review Agent).

## Carried Over (decided earlier)
- The winner: the **first knife to stick** wins; a bounce-out or a false start loses; the same frame is a draw; none stuck, no winner (2026-10-14).
- The start signal: **like Formula 1, 5 beeps, a random pause, then a longer "go" beep** (Nigel and Mark, 2026-10-14). The beeps play with the iPhone's silent switch on and duck other audio.
- Boards are chosen by **tapping each centre, Player 1 then Player 2**, then locked; there may be more boards in view (2026-10-14).
- **Analyse every frame in order, report late**; analysis starts **1 s before go** (2026-10-15). Any earlier is an obvious false start.
- Impact = the frame with the largest change on the board's face (`MotionEpisode.impact`).
- Safety (Review Agent, Quick draw Safety Report): the in-app instructions' Quick draw points; **the result must be readable from the throwing line**; nobody needs to touch the phone between "Play" and the result.

## Acceptance Criteria
1. Home has **Play** (rounds on one target) and **Quick draw** (two throwers) as separate buttons, each saying what it is.
2. Quick draw opens the live camera full screen; tapping Player 1's board, then Player 2's, outlines and numbers them; Lock boards.
3. Start: 5 beeps, a random pause, a long "go" beep, with **GO!** on screen; heard with the silent switch on.
4. Every camera frame from 1 s before go is analysed, in order (the result may come late); each knife is timed from go and judged stuck (with its score) or bounced; a knife before go is a false start.
5. The result is shown **large enough to read from the throwing line** (about 4 m), with the winner and each player's time and score.
6. Ready for the next duel without touching the board calibration (after the knives are collected).
7. Works with the phone upright on both platforms (Android's sideways frames, iOS's upright ones). The recording version (Live test → Quick draw) and Play are unchanged.

---

## Task 1: A Quick draw button and the live screen
- **Status:** BUILT, waiting for Nigel's device check (2026-10-15)
- **What changed:**
  - Home: **Play** ("Rounds on one target") and **Quick draw** ("Two throwers, on a start signal").
  - `LiveQuickDrawScreen` (`lib/ui/live_quick_draw_screen.dart`): the live camera full screen (system bars hidden), via `CameraView` (which now takes a `camera:` provider; default `cameraProvider`) and its own `liveQuickDrawCameraProvider`, so camera errors, background release and re-open work as on Play. Tap Player 1's board, then Player 2's, Lock boards, Start again. No game yet: locked says "Boards locked."
  - Shared with the recording's Quick draw (`lib/ui/quick_draw_boards.dart`): `BoardChoosing` (the tap → find → outline flow and its instruction line), `BoardsOverlay`, `BoardsPainter` (each board scaled from its own image size), `boardLines`, `quickDrawLine`. `QuickDrawScreen` now uses them.
  - **Taps are fractions of the picture** (`TapLocator`, `locateTappedInFrame`): turned into pixels after the frame is turned upright, so a sideways Android frame lands on the same board.
  - Not done: zoom on the Quick draw screen (both boards must be in view; zooming in is rarely wanted). Add if Nigel finds the boards too small.
- **Test Report (2026-10-15):** `flutter analyze` clean; `flutter test` 424 passed, 0 failed. New `live_quick_draw_screen_test.dart` (Home's two buttons and captions; Play still opens Play; Quick draw full screen asking for Player 1; tap both in order then lock, taps as fractions; Start again; camera refused shows the camera error; leaving restores the bars), `tapped_target_locator_test.dart` → a sideways (90°) frame with fraction taps finds the board where measured. Updated: `quick_draw_screen_test.dart` (taps as fractions).
- **Work:** Home: **Quick draw** next to **Play**, with a line each ("Rounds on one target" / "Two throwers, on a start signal"). The Quick draw screen works with either camera: the live camera full screen (with zoom as on Calibrate) or the recording (Live test). Tap each board on the live picture (taps → upright image pixels, whatever the sensor's rotation), outline and number, Lock boards. No game yet.
- **Verify:** Nigel, on a phone: Home → Quick draw, points it at two boards (or two A4 printouts side by side), taps each bull, sees "1" and "2" outlined, locks.
- **Save:** widget tests (both buttons; the live screen's tap flow with a fake camera); tap-to-image mapping tested for 0°/90°/270° rotation.
- **Doc Update Log (2026-10-15):**
  - `Architecture/Design Decisions.md`: new section **Quick Draw: the Live Screen** (the Home button and its reason, `LiveQuickDrawScreen`, `CameraView`'s `camera:`, `liveQuickDrawCameraProvider`, no zoom); Choosing the Boards by Tapping: **taps are fractions**, converted after the frame is turned upright, and the shared `quick_draw_boards.dart`; `QuickDrawScreen` points to the live version; code layout rows (`lib/ui/`, `lib/vision/`). Also backlog #12: Rounds and Scoring update (`awaitingNextRound`, `roundNumber`, `finishedRounds`; `roundText` / `gameText`).
  - `Architecture/Glossary.md`: `LiveQuickDrawScreen`, `quick_draw_boards.dart` (`BoardChoosing`, `BoardsOverlay`, `BoardsPainter`, `boardLines`, `quickDrawLine`), `CameraView.camera`, `liveQuickDrawCameraProvider`, `TapLocator`; `QuickDrawScreen`'s "tap (image pixels)" removed; `locateTappedInFrame` converts fractions; `GameSession`'s new getters; the Quick draw and Seed (tap) centre concepts.
  - `Architecture/System Diagram.md`: Home → `LiveQuickDrawScreen`, the shared `quick_draw_boards`, `liveQuickDrawCameraProvider`; the recording box's footer (story complete, the live game on Home).
  - `Architecture/Data Flow.md`: "choosing the boards" box for both screens, taps as fractions turned into pixels after the upright turn; a Tap row in Coordinate Spaces.
  - Drift for later: the in-app Instructions still say Quick draw is "Live test, then Quick draw" (Task 5); Known Issues → Quick Draw: a Board Isn't Found applies to the live screen too (Start again doesn't rewind there).

## Task 2: 60 fps, and every frame's board crops in order
- **Status:** NOT STARTED
- **Depends on:** Task 1
- **Work:**
  - `LiveCamera` asks for **60 fps** for Quick draw (the plugin's `fps`), falling back to what the phone gives; the screen shows the rate in debug builds.
  - `CroppedCamera` learns **rotation**: on Android the frames arrive sideways, so the board's rectangle is mapped into the sensor's frame and the crop turned upright.
  - **A live analysis feed:** as each frame arrives, copy just the two boards' crops (small: ~250 × 250 each) into a queue; the watchers analyse the queue in order, timed by when each frame arrived. If analysis is slower than the camera, it falls behind (the result is late) but loses nothing. The camera itself may drop frames if the phone is overloaded; the debug label shows how many.
- **"Be Careful" review** (camera settings).
- **Verify:** the frames/s label on Nigel's Samsung and iPhone; a hand waved over each board in turn shows motion on that board only.
- **Save:** crop-and-rotate tests (YUV and BGRA, 90°/270°); the queue loses no frame when analysis is slow.

## Task 3: The start signal
- **Status:** NOT STARTED
- **Depends on:** Task 2
- **Work:** **Start** (after Lock boards): 5 short beeps, about 1 s apart, then a **random pause: one of 1.0, 1.2, 1.4 … 3.0 s** (Nigel, 2026-10-15: "choose any 0.2 of a second between 1 and 3 seconds"), then a longer "go" beep; **GO!** on screen. The beeps are small bundled sounds (made by a tool, like the target printout), played through the existing audio path (ducks other audio, ignores the silent switch). "Go" is stamped on the camera's clock when the go beep is asked to play; the sound's own start delay is the same for both players, so the winner is fair (absolute times may be a little late; measured on each phone if possible). Analysis starts 1 s before go, as on the recording.
- **Verify:** Nigel hears the countdown and sees GO! with the beep; the pause differs each time.
- **Save:** countdown timing tests with a fake clock and fake sound (the order, the random pause within its range, go time).

## Task 4: The live duel and a readable result
- **Status:** NOT STARTED
- **Depends on:** Task 3
- **Work:** after go, each board's watcher times and scores its knife (`QuickDrawWatcher`, `judgeQuickDraw`, as on the recording); a knife landing during the countdown is a false start. The result in **large type** (readable at ~4 m: the winner's player number, each time and score), plus a short result sound. **Next duel:** once someone has collected the knives (a board visit on both boards, or a "Ready" tap), Start again without re-tapping the boards.
- **Verify:** two throwers (or two people placing pens on two A4 printouts after GO!, and one too early) see the right winner from where they stand.
- **Save:** tests with recorded frame sequences through the live path (the Quick draw clip's frames fed as a live camera, sideways and upright).

## Task 5: Docs, instructions, traceability
- **Status:** NOT STARTED
- **Depends on:** Task 4
- **Work:** the in-app Instructions' Quick draw section for the live game (the start signal, where to stand, reading the result; the safety points re-checked by the Review Agent); Design Decisions, diagrams, Known Issues; Traceability Agent over criteria 1–7.
- **Verify:** Nigel reads the summary.
- **Save:** story archived.

---

## Plan Changes Log

- **2026-10-15:** Task 1: no zoom on the Quick draw screen for now (the plan said "with zoom as on Calibrate"); both boards must stay in view.
- **2026-10-15:** Approved by Nigel. The random pause is one of 1.0–3.0 s in 0.2 s steps. Backlog #12 (Play's round display) fixed first.
- **2026-10-15:** Plan drafted; Nigel's decisions recorded above.

---

## Notes
- **Testing without real boards:** two A4 printouts side by side work for Tasks 1–3; for Task 4, pens pressed on after GO! (a hand wave for a bounce-out). Real knives need two lanes and two throwers.
- **Live timing limits** (Mac, 2026-10-15, backlog #9): frames are stamped when they arrive in Dart, not when captured, so there's some jitter; both boards come from the same frames, so it's fair between players. At 30 fps (if a phone won't do 60) a close duel is more often a draw.
