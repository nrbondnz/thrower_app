# Story Checkpoint: Players and Targets (Game Modes)

## Story Goal
Play (rounds of 3 throws) gets a **second screen** after Home → Play: **how many players, 1 or 2**, and for 2 players **1 target (taking turns) or 2 targets (throwing at the same time)**. Nigel, 2026-10-16: "start on #5 game modes. I think in scoring 3 shots mode, there should be a second screen that says how many players 1 or 2. Also, 1 target(so alternating) or 2 at the same time". Backlog #5 (players); also does part of #10 (each board keeping its own rounds and score over a whole game).

## Complexity Score
6 (Large): UI → game wiring → camera crops → scoring (3), two models (one player's game, the two-player match) (1), branches by mode (1), more than 3 acceptance criteria (1).

## Status
IN PROGRESS: Task 1 of 4 complete (2026-10-16), waiting for Nigel's checkpoint. Plan approved 2026-10-16 ("yes to all, start task 1"): every open question answered as recommended.

## What Exists (checked 2026-10-16)
- `GameSession` (`lib/scoring/game_session.dart`): one player's game, 9 rounds of 3, immutable; a board visit (collecting knives) closes a round; throwing on without collecting starts the next round.
- `GameNotifier` (`lib/providers.dart`) turns one `ThrowWatcher`'s events into the session; `PlayScreen` shows one target's marks, the round line and the game total.
- Quick draw already has the two-board pieces: boards **tapped Player 1 then Player 2** and locked (`BoardChoosing`, `QuickDrawTargets`), and a `ThrowWatcher` per board on its own crop of the picture (`CroppedCamera`, as in `QuickDrawWatcher`).

## Questions (answered 2026-10-16: "yes to all", as recommended)
1. **One target: what is a turn?** **Recommended: a player throws their 3 knives, the knives are collected, then it's the other player's turn** (the app can't tell whose knife is whose, so knives from two players on the board at once would be guesswork). The turn passes after the 3rd knife, or earlier when someone collects. *Alternative:* alternate every knife; then the board holds both players' knives and a knife that falls out can't be put to the right player for sure.
2. **One target: who starts each round?** **Recommended: Player 1 every round** (simple to follow from the throwing line). *Alternative:* the starter alternates each round.
3. **Names.** **Recommended: "Player 1" and "Player 2" for now**, as Quick draw does; typed names can come with accounts (backlog #4).
4. **Two targets: choosing the boards.** **Recommended: tap Player 1's board, then Player 2's, then Lock, as in Quick draw** (the same code). *Alternative:* Calibrate each board separately with Find target; slower and new code.
5. **Not in this story:** other game lengths and game history (the rest of backlog #5). The new screen has room for a "Rounds" choice later.

## Acceptance Criteria
1. Home → **Play** opens a setup screen: **Players: 1 / 2**; with 2 players, **Targets: 1 (take turns) / 2 (throw together)**; then **Start**.
2. **1 player** plays exactly as today.
3. **2 players, 1 target:** the screen says whose turn it is, large enough to read from the throwing line; each throw is scored to that player; the turn passes after 3 knives or when the knives are collected; both players' totals show; the board's marks clear at each new turn.
4. **2 players, 2 targets:** both boards are chosen and locked, each watched on its own crop; each board's throws, rounds, collections and knives falling out belong to that board's player only; both boards' marks show.
5. At the end (each player has played 9 rounds): **who won** (or a draw) and both totals, large enough to read from the throwing line.
6. **Safety** (Review Agent §7): the in-app instructions say each thrower needs their own lane for two targets, and that with two targets both throwers finish and collect together; the app never tells a player to throw while the other may be at the board.
7. Tests cover the match rules (turns, collecting early, falling out, the winner, a draw) without a camera, and each mode's screen.

---

## Task 1: Match rules, and the setup screen
- **Status:** COMPLETE (2026-10-16), awaiting Nigel's checkpoint
- **Work:**
  - `Match` (pure Dart, `lib/scoring/`): a `GameSession` per player, and the mode (`PlayMode`: one player; two players on one target; two players on two targets). One target: whose turn it is, the turn passing after 3 knives or a collection, a knife falling out going back to the player who threw it. Two targets: each board's events go to its player's session. Totals, game over, the winner or a draw.
  - `GameNotifier` holds a `Match`; one player stays as today.
  - The setup screen after Home → Play (and Live test → Play), remembering the last choice for the session.
- **Verify:** tests for the rules; Home → Play shows the setup screen; 1 player on Live test → Target 1 plays as before.
- **Next:** Task 2.
- **What changed:**
  - `lib/scoring/match.dart` (new): `PlayMode` (`solo`, `sharedTarget`, `twoTargets`, with `players` / `targets`) and `Match` (a `GameSession` per player; `stuck` / `bounceOut` / `boardVisited` take the `board`; `turn`, `turnThrows`, `playerAt`, `takesThrowAt`, `fellOut(player, round, throw)`, `isOver`, `winner`, `draw`, `isEmpty`).
  - `lib/providers.dart`: `playModeProvider` (`PlayModeNotifier`, session-long, default `solo`); `GameNotifier` now holds a `Match`, rebuilt when the mode or the camera changes; `onEvent(…, board:)`; knives remembered by (board, knife id), and a visit or scene change forgets only that board's.
  - `lib/ui/play_setup_screen.dart` (new): `PlaySetupScreen` (Players 1 / 2; Targets 1 / 2 for two players; a line saying what the mode means, `modeDescription`; Start). Only `solo` is playable so far (`PlaySetupScreen.playable`); the two-player modes say "Coming soon."
  - Home → Play and Live test → 2. Play open the setup screen; Home's caption is now "Rounds of 3 throws, 1 or 2 players".
  - `PlayScreen` and the Instructions read Player 1's game (`players.first`); the Instructions say "Tap Play, choose 1 player, then Start."
- **Verified by:** `flutter test`: 502 passed (30 new), `flutter analyze`: no issues. The setup screen was rendered in a widget test and looked right. Not run on a phone (Nigel can't test on a device; none needed for this task).
- **Files changed:** `lib/scoring/match.dart`, `lib/providers.dart`, `lib/ui/play_setup_screen.dart`, `lib/ui/play_screen.dart`, `lib/ui/home_screen.dart`, `lib/ui/live_test_screen.dart`, `lib/ui/instructions.dart`; tests below.
- **Checkpoint saved:** 2026-10-16

### Test Report — 2026-10-16 (Task 1)
- **New:** `test/scoring/match_test.dart` (17: modes; one player; one target: Player 1 first, turn passes on collecting, collecting early, a visit before any throw, a 4th knife without collecting, Player 1 starts every round, falling out goes to the thrower, winner, Player 2 still throws round 9, draw, ignored after the end; two targets: each board its own player, collecting at one board, one finishing first); `test/ui/play_setup_screen_test.dart` (7: 1 player first, 2 players asks for targets, the two-target wording, Start opens Play, two-player modes not yet playable, opens on the last choice, the same choice keeps the game); `game_notifier_test.dart` group 'two players' (6: a new mode starts a new game, each board scores for its player, same knife id on two boards, a visit at one board, turns on one target, a new game keeps the mode).
- **Updated:** `game_notifier_test`, `play_through_test`, `play_screen_test`, `live_test_screen_test` (the state is a `Match`); `live_quick_draw_screen_test` (Home's caption; Play → setup → Start → Play).
- **Results:** 502 passed, 0 failed.

### Doc Update — 2026-10-16 (Task 1)
- `Architecture/Design Decisions.md` → Single Player First: update for one or two players (the modes, `Match`, the turn rule and why, two targets, winner and draw, names, what's built).
- `Architecture/Glossary.md`: `Match` / `PlayMode` / `playModeProvider` / `PlaySetupScreen`; concept **Turn**.
- `Architecture/Data Flow.md`, `Architecture/System Diagram.md`: `GameNotifier.onEvent(board) → Match`; `playModeProvider` (lines kept at 71 characters).
- Web pages (`tool/web_docs/content.py`, rebuilt): Screens (`PlaySetupScreen`), Providers (`playModeProvider`, `Match`), the GameSession page (now "GameSession and Match"), the Play flow.
- `stories/backlog.md` #5 links this story.
- Instructions: one sentence updated; the two-player sections come with Tasks 2–4.

## Task 2: Two players, one target
- **Work:** Play shows whose turn it is (large), both players' round lines and totals; marks clear at each turn; the end result with the winner. **Review Agent** on the wording.
- **Verify (on this PC, no phone):** Live test → Target 1 as 2 players on 1 target: the recording's rounds go to Player 1, Player 2, Player 1, … and the totals add up to the recording's answer key split the same way.
- **Next:** Task 3.

## Task 3: Two players, two targets
- **Work:** choose and lock both boards (Quick draw's tapping); a `ThrowWatcher` per board on its own crop; each board's marks and its player's rounds; the end result. The Quick draw clip (both boards) becomes a Live test choice for this mode.
- **Verify (on this PC):** Live test → the Quick draw clip, 2 players on 2 targets: Player 1's knife is scored on Player 1's line, Player 2's (Mark's) on Player 2's.
- **Next:** Task 4.

## Task 4: Instructions, docs, device checks, traceability
- **Work:** the in-app Instructions (the modes, turns, lanes, collecting together); Design Decisions, Glossary, Data Flow, System Diagram, the web pages; Device Test Plan → **Players and Targets Checks** for the next TestFlight build; Review Agent §7; Traceability Agent; backlog #5 and #10 updated.
- **Verify:** Nigel reads the instructions; the checks are ready for his brother.

---

## Plan Changes Log
- **2026-10-16:** Planned. Waiting for Nigel's approval and answers to the open questions.
- **2026-10-16:** Approved, all questions as recommended ("yes to all, start task 1"). Task 1 done.

## Notes
- Two people throwing at the same time is already allowed in Quick draw, with separate lanes (its Safety Report). Two-target Play is the same set-up, but for a whole game, including collecting.
- No platform, permission or plugin changes are expected.
