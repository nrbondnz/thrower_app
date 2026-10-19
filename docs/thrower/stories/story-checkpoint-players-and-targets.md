# Story Checkpoint: Players and Targets (Game Modes)

## Story Goal
Play (rounds of 3 throws) gets a **second screen** after Home → Play: **how many players, 1 or 2**, and for 2 players **1 target (taking turns) or 2 targets (throwing at the same time)**. Nigel, 2026-10-16: "start on #5 game modes. I think in scoring 3 shots mode, there should be a second screen that says how many players 1 or 2. Also, 1 target(so alternating) or 2 at the same time". Backlog #5 (players); also does part of #10 (each board keeping its own rounds and score over a whole game).

## Complexity Score
6 (Large): UI → game wiring → camera crops → scoring (3), two models (one player's game, the two-player match) (1), branches by mode (1), more than 3 acceptance criteria (1).

## Status
BUILT: all 4 tasks complete (2026-10-16); Tasks 1–3 committed (`a1bbd35`, `89aae25`, `bab4ae9`). **Waiting for the device checks** ([[Device Test Plan]] → Players and Targets Checks, M0–M9, TestFlight 1.0.0 (8) or later, Mac Handoff section 000). Archive the story once they pass, as for the live Quick draw. Plan approved 2026-10-16 ("yes to all, start task 1"): every open question answered as recommended.

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
- **Status:** COMPLETE (2026-10-16); Nigel: "commit this and continue to task 2" (`a1bbd35`)
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
- **Status:** COMPLETE (2026-10-16); Nigel: "commit this and continue to task 3" (`89aae25`)
- **Work:** Play shows whose turn it is (large), both players' round lines and totals; marks clear at each turn; the end result with the winner. **Review Agent** on the wording.
- **Verify (on this PC, no phone):** Live test → Target 1 as 2 players on 1 target: the recording's rounds go to Player 1, Player 2, Player 1, … and the totals add up to the recording's answer key split the same way.
- **Next:** Task 3.
- **What changed:**
  - `Match`: `turnComplete`, `nextTurn` (who throws after this turn, skipping a player whose game is over), `nextThrowStartsRound` (when the board's marks clear).
  - `PlayScreen` (`lib/ui/play_screen.dart`): for two players, `_PlayersPanel` in place of the one-player lines: `turnText` in large type ("Player 1's turn", 32 pt; "Collect your knives" with `turnDetail` "When no one is throwing. Then Player 2's turn."; at the end "Player 2 wins" / "A draw", 44 pt green); `playerTitle` ("Player 1: 23") and `playerDetail` (the round in progress, or every round at the end) for each player, the thrower highlighted; `matchFooter` (the last message; at the end, collect when no one is throwing). Marks clear at each new turn. Reset game / New game work on the whole match.
  - `PlaySetupScreen.playable` adds `sharedTarget`.
  - Instructions: "Tap Play, choose how many players (and, for two, how many targets), then Start. A game is 9 rounds of 3 throws for each player."; a new section, **Two players on one target** (taking turns, Player 1 starts every round, what the screen says, throw only once the other player has collected and stepped back, collecting early, the end and the winner).
  - First draft had the whole "Collect your knives when no one is throwing, then Player 2." at 32 pt: rendered, it took most of the screen and squeezed the camera view, so it was split into a short headline and a smaller line.
- **Verified by:** `flutter test`: 515 passed (13 new), `flutter analyze`: no issues. **The Live test recordings as two players** (`live_replay_test`, both Target 1 and Target 2): the app's own detections fed to a two-player match give Player 1 the one-player game's rounds 1, 3, 5, … and Player 2 rounds 2, 4, 6, …, with the same totals. The panel was rendered in widget tests (turn, collect, game over) and checked by eye. Not run on a phone.
- **Files changed:** `lib/scoring/match.dart`, `lib/ui/play_screen.dart`, `lib/ui/play_setup_screen.dart`, `lib/ui/instructions.dart`; tests below.
- **Checkpoint saved:** 2026-10-16

### Test Report — 2026-10-16 (Task 2)
- **New:** `match_test` (4: a complete turn with Player 2 next; Player 2 next again once Player 1 has finished; marks start at each turn, not within it; one player's marks at each round); `play_screen_test` group 'two players on one target' (3 widget tests: whose turn in large type with both totals; collect first, then the next player; the end with the winner/draw, every round and New game) and 'two-player text' (2); `play_setup_screen_test` 'Start with 2 players on 1 target opens Play taking turns' (replacing 'not playable yet'; two targets still isn't); `instructions_test` (the new section, and its place in the order); `live_replay_test` 'as two players on one target, the rounds alternate between the players' (Target 1 and Target 2).
- **Updated:** `instructions_test` game-length wording ("for each player").
- **Results:** 515 passed, 0 failed.

### Safety Report — 2026-10-16 (Task 2, Review Agent §7 on the wording)
- **Files reviewed:** `lib/ui/play_screen.dart` (`turnText`, `turnDetail`, `matchFooter`), `lib/ui/instructions.dart` (Two players on one target), `lib/ui/play_setup_screen.dart` (`modeDescription`).
- ✅ No platform, permission, plugin, secret or data change (§1–6, 8 not affected).
- ✅ §7: the app never tells a player to throw while someone may be at the board. Once a turn has its throws it says "Collect your knives / When no one is throwing", and names the next player only as "Then Player 2's turn"; "Player 2's turn" alone shows only after the collection is seen (a board visit is reported once the board's region has settled).
- ✅ §7: the Instructions say to throw only once the other player has collected **and stepped back** (the app sees the board, not the lane), alongside the existing Safety section (the app can't tell whether the lane is clear).
- ✅ The result and whose turn it is are in large type (32 / 44 pt), so nobody walks to the phone to read them.
- **Verdict:** OK to commit.

### Doc Update — 2026-10-16 (Task 2)
- `Architecture/Design Decisions.md` → Single Player First, update: what the two-player panel shows, the marks per turn, and the safety point.
- `Architecture/Glossary.md`: `Match`'s new members; the panel's text functions.
- Web pages: Screens → `PlayScreen`.

## Task 3: Two players, two targets
- **Status:** COMPLETE (2026-10-16); Nigel: "commit this and continue to task 4" (`bab4ae9`)
- **Work:** choose and lock both boards (Quick draw's tapping); a `ThrowWatcher` per board on its own crop; each board's marks and its player's rounds; the end result. The Quick draw clip (both boards) becomes a Live test choice for this mode.
- **Verify (on this PC):** Live test → the Quick draw clip, 2 players on 2 targets: Player 1's knife is scored on Player 1's line, Player 2's (Mark's) on Player 2's.
- **Next:** Task 4.
- **What changed:**
  - `lib/game/board_crop.dart` (new): `cropToBoard`, the board-square crop that was inside `QuickDrawWatcher.start`, now shared (Quick draw's tests unchanged and passing).
  - `lib/game/play_boards_watcher.dart` (new): `PlayBoardsWatcher` (a `ThrowWatcher` per board on its crop, at Play's usual pace, for a whole game) and `BoardThrowEvent(board, event, calibration)`.
  - `lib/providers.dart`: `playTargetsProvider` (`PlayTargetsNotifier`, a `QuickDrawTargetsNotifier` kept for the session and reset when the camera changes).
  - `lib/ui/quick_draw_boards.dart`: `BoardChoosing.addBoard` (Quick draw's provider by default), so Play can keep its own boards.
  - `lib/ui/two_target_play_screen.dart` (new): `TwoTargetPlayScreen`: tap Player 1's board, Player 2's, Lock boards; camera set to 1×; each board's marks (`BoardMarksPainter`); `boardsStateText`; `PlayersPanel`; `boardMessage`; Choose boards again (keeps the scores); Reset game / New game; the Live test recording's restart button.
  - `lib/ui/play_screen.dart`: `PlayersPanel` (public), `turnText` / `turnDetail` for two targets ("Wait for Player 2" / "Then collect your knives together."; "Collect your knives" / "Together, when no one is throwing."; nothing while both throw), both players highlighted while playing; `eventMessage` and `paintRoundMarks` pulled out to share.
  - `lib/ui/play_setup_screen.dart`: 2 targets opens `TwoTargetPlayScreen`; every mode is playable, so the "Coming soon" gating is removed.
  - `lib/ui/live_test_screen.dart`: **Two targets → Play on two targets** (below Quick draw): plays the Quick draw recording in this mode. (First placed above Quick draw; that pushed the Quick draw button off the bottom of the test screen and 11 Quick draw screen tests failed, so it went below.)
  - Instructions: new section **Two players on two targets** (phone behind the throwers out of both lines of throw, not between the lanes, out of reach of a backswing; choose and lock before anyone throws; separate lanes; wait for the other player and collect together; the end). Paper: not played on paper.
- **Verified by:** `flutter test`: 531 passed (16 new), `flutter analyze`: no issues. **The Quick draw recording through two-target Play's own path** (`two_target_replay_test`: recorded camera → `PlayBoardsWatcher` from the first frame → `GameNotifier` in two-target mode): **Player 1 (left): one throw, a bounce-out, 0; Player 2 (right, Mark): one throw, stuck, 5**, as the answer key; nothing else taken for a throw. The panel rendered in a widget test ("Wait for Player 2" with both players) and checked by eye. Not run on a phone.
- **Files changed:** above, plus tests below.
- **Checkpoint saved:** 2026-10-16

### Test Report — 2026-10-16 (Task 3)
- **New:** `test/game/two_target_replay_test.dart` (2: each player's one throw, as the answer key); `test/ui/two_target_play_screen_test.dart` (14: choosing in order into Play's own boards, not Quick draw's; locked shows both players and each board's state, no headline; boards kept on leaving and coming back; Choose boards again keeps the scores; camera back to 1×; Setup → 2 targets opens it; Live test → Play on two targets plays the Quick draw recording; text: no headline while both throw, wait for the other, collect together, back to none once collected, the winner, a board's message names its player, short watch states); `instructions_test` (the new section).
- **Removed:** `play_setup_screen_test` 'two targets is not playable yet' (it is now).
- **Results:** 531 passed, 0 failed.

### Safety Report — 2026-10-16 (Task 3, Review Agent)
- **Files reviewed:** `lib/ui/two_target_play_screen.dart`, `lib/ui/play_screen.dart` (`turnText` / `turnDetail`), `lib/ui/instructions.dart` (Two players on two targets), `lib/game/play_boards_watcher.dart`.
- ✅ §1–5, 8: no platform, permission, plugin, secret or data change; frames stay in memory, as before.
- ✅ §6: two `ThrowWatcher`s at Play's pace (at most every 60 ms each) on small crops, the same work as Quick draw's watching; the full-resolution copies are of the crops. To measure on a phone (Device Test Plan, Task 4).
- ✅ §7: two people throwing at once: the Instructions repeat Quick draw's set-up (separate lanes, phone behind the throwers, out of both lines of throw, not between the lanes, out of reach of a backswing); boards chosen and locked before anyone throws; the app never prompts one thrower to collect while the other may still be throwing ("Wait for Player 2", then "Collect your knives / Together, when no one is throwing."). It still can't see the lanes, which the Safety section says.
- ⚠️ Noted, not blocking: a board visit is seen per board. If one thrower walks up early, the app records their round as collected; the other thrower is still throwing next to them. The Instructions say to collect together; the app can't stop it.
- **Verdict:** OK to commit.

### Doc Update — 2026-10-16 (Task 3)
- `Architecture/Design Decisions.md` → Single Player First, update: Task 3 (choosing and keeping the boards, 1×, watching, what the panel says, Live test, safety).
- `Architecture/Glossary.md`: `PlayBoardsWatcher`, `cropToBoard`, `TwoTargetPlayScreen`, `playTargetsProvider`; the panel's two-target text.
- `Architecture/System Diagram.md`: `playTargetsProvider` (71 characters).
- Web pages: a new component page, **PlayBoardsWatcher**, in the game column of the layer diagram; Screens (`TwoTargetPlayScreen`, Live test), Providers (`playTargetsProvider`), the Play flow's caption; Home's Play box now "rounds of 3, 1 or 2 players".

## Task 4: Instructions, docs, device checks, traceability
- **Status:** COMPLETE (2026-10-16), awaiting Nigel's checkpoint
- **Work:** the in-app Instructions (the modes, turns, lanes, collecting together); Design Decisions, Glossary, Data Flow, System Diagram, the web pages; Device Test Plan → **Players and Targets Checks** for the next TestFlight build; Review Agent §7; Traceability Agent; backlog #5 and #10 updated.
- **Verify:** Nigel reads the instructions; the checks are ready for his brother.
- **What changed:**
  - **Instructions, reviewed whole** (Real board and Paper): Playing a game (players and targets on the setup screen, rounds for each player), **Two players on one target** (Task 2), **Two players on two targets** (Task 3), and in **Safety** a new point: *With two players, "Player 2's turn", "Wait for Player 2" and "Collect your knives" only follow the scores. They never mean the lane is clear: look before you go forward.*
  - `turnText` uses `Match.draw` (it was used only by tests: the Traceability Agent's orphan check).
  - **Device Test Plan → Players and Targets Checks** (M0–M9) for Nigel's brother, build 8 or later; Q0's Home caption noted for build 8.
  - **Mac Handoff section 000:** TestFlight 1.0.0 (8), what's in it since build 7 (this story, no GO! on the live screen, Play only once locked on the recording, the web pages), no new plugins or permissions.
  - **Known Issues:** *Two Targets: One Thrower Collecting Early Ends Only Their Round* (by design; a safety rule for the throwers).
  - **Backlog:** #5 players built (history, other game lengths and typed names still to do); #10's "each board's own rounds over a whole game" and "the live camera crop" marked done.
  - CLAUDE.md and `working-with-nigel.md` point to this story (built, device checks to come).
- **Verified by:** `flutter test`: 533 passed (2 new), `flutter analyze`: no issues.
- **Checkpoint saved:** 2026-10-16

### Test Report — 2026-10-16 (Task 4)
- **New:** `instructions_test` "says the two-player prompts only follow the scores, never that the lane is clear"; `two_target_play_screen_test` "each board's marks are drawn on that board: a knife's entry in its crop, moved by the crop's corner" (`BoardMarksPainter`, with Flutter's `paints` matcher: the gap the traceability check found).
- **Results:** 533 passed, 0 failed.

### Traceability Report — 2026-10-16 (story complete, before the device checks)

- **AC1**
  - **Requirement:** Play opens a setup screen: 1 / 2 players; for 2, 1 / 2 targets; Start
  - **Design reference:** Design Decisions → Single Player First (update 2026-10-16)
  - **Implementation:** `PlaySetupScreen`, `modeDescription`, `PlayMode`, `playModeProvider`
  - **Tests:** `play_setup_screen_test` (7); `two_target_play_screen_test` 'Start with 2 players on 2 targets…'; `live_quick_draw_screen_test` 'Play opens the setup screen…'
  - **Status:** ✅ (device: M0)
- **AC2**
  - **Requirement:** 1 player plays exactly as before
  - **Design reference:** same
  - **Implementation:** `PlayScreen` (one-player branch), `Match` solo → one `GameSession`
  - **Tests:** `play_screen_test` (5, unchanged), `game_notifier_test`, `play_through_test`, `live_replay_test` (both recordings), `match_test` 'one player'
  - **Status:** ✅
- **AC3**
  - **Requirement:** 2 players, 1 target: whose turn in large type; throws to that player; turn passes after 3 or a collection; both totals; marks clear each turn
  - **Design reference:** same, Task 2
  - **Implementation:** `Match` (`turn`, `turnThrows`, `turnComplete`, `nextTurn`, `_passTurn`, `nextThrowStartsRound`), `GameNotifier.onEvent`, `PlayersPanel`, `turnText` / `turnDetail` / `playerTitle` / `playerDetail`
  - **Tests:** `match_test` 'two players on one target' (13); `play_screen_test` 'two players on one target' (3) + 'two-player text' (2); `game_notifier_test` 'one target: throws go to whoever's turn it is'; **`live_replay_test` 'as two players on one target…' (both recordings)**
  - **Status:** ✅ (device: M1, M3, M4)
- **AC4**
  - **Requirement:** 2 players, 2 targets: both boards chosen and locked, each on its crop; each board's throws, collections and fall-outs for its player only; both boards' marks
  - **Design reference:** same, Task 3
  - **Implementation:** `TwoTargetPlayScreen`, `BoardChoosing.addBoard`, `playTargetsProvider`, `PlayBoardsWatcher`, `cropToBoard`, `Match` two targets, `GameNotifier` knives by (board, id), `BoardMarksPainter` / `paintRoundMarks`
  - **Tests:** **`two_target_replay_test` (the Quick draw recording: P1 bounce-out 0, P2 stuck 5)**; `two_target_play_screen_test` (15); `game_notifier_test` 'two targets…' (3); `match_test` 'two players on two targets' (3); Quick draw's tests for the shared crop
  - **Status:** ✅ (device: M2, M5, M6, M8)
- **AC5**
  - **Requirement:** At the end: who won or a draw, both totals, large
  - **Design reference:** same
  - **Implementation:** `Match.isOver` / `winner` / `draw`, `turnText` (44 pt), `playerDetail`, `matchFooter`, New game
  - **Tests:** `match_test` (winner, draw, Player 2 still throws round 9, one finishing first on two targets); `play_screen_test` 'at the end…'; `two_target_play_screen_test` 'the winner at the end'
  - **Status:** ✅ (device: M7)
- **AC6**
  - **Requirement:** Safety: own lanes for two targets, collect together; never told to throw while someone may be at the board
  - **Design reference:** Review Agent Safety Reports (Tasks 2, 3); Known Issues → Two Targets: One Thrower Collecting Early
  - **Implementation:** `turnText` / `turnDetail` ("Collect your knives / When no one is throwing", "Wait for Player 2"); Instructions: Two players on one target, Two players on two targets, Safety
  - **Tests:** `instructions_test` (3 new: each section, the Safety point); the text tests above
  - **Status:** ✅ (device: M9, real knives later)
- **AC7**
  - **Requirement:** Rules tested without a camera, and each mode's screen
  - **Design reference:** —
  - **Implementation:** —
  - **Tests:** `match_test` (21), the screen tests above
  - **Status:** ✅

**Coverage:** 7 of 7 requirements with design, code and tests. **Device checks:** all still to come (M0–M9); nothing here has run on a phone.

**Backward check (code → requirement):** every new class and function traces to AC1–AC6. Found and fixed: `Match.draw` was used only by tests (now used by `turnText`); `BoardMarksPainter` had no test (added). The setup screen's "Coming soon" gating, needed only while modes were being built, was removed in Task 3.

**Not covered, by design:** game history, other game lengths, typed names (backlog #5); drag-to-adjust a board (#10).

**Drift noted, not fixed (out of scope):** none found.

---

## Plan Changes Log
- **2026-10-16:** Planned. Waiting for Nigel's approval and answers to the open questions.
- **2026-10-16:** Approved, all questions as recommended ("yes to all, start task 1"). Task 1 done.
- **2026-10-16:** Task 1 committed; Task 2 done ("commit this and continue to task 2").
- **2026-10-16:** Task 2 committed; Task 3 done ("commit this and continue to task 3").
- **2026-10-16:** Task 3 committed; Task 4 done ("commit this and continue to task 4"). Story built; waiting for the device checks before archiving.

## Notes
- Two people throwing at the same time is already allowed in Quick draw, with separate lanes (its Safety Report). Two-target Play is the same set-up, but for a whole game, including collecting.
- No platform, permission or plugin changes are expected.
