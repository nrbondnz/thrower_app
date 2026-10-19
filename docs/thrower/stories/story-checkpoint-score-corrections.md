# Story Checkpoint: Score Corrections

## Story Goal
Any throw's score in the game being played can be **changed by hand**, and a throw the camera **didn't see** (a knife that missed the board altogether, or a stuck knife it didn't register) can be **added**, from a 0–5 popup, without jogging the camera. Nigel, 2026-10-17: "there could be times when a thrower misses the target alltogether, and possibly where they dispute the scoring so each score should be able to be pressed on giving a popup of 0-5 possible (hopefully without jogging the camera)". Follows [[story-checkpoint-game-history]] (a corrected game is kept with its corrected scores).

## Complexity Score
6 (Large): scoring → game wiring → UI → vision (the moved-camera check) (4 layers), a data change (`ThrowRecord`, `Match`) (1), physical safety: someone at the phone mid-game (Review Agent §7) (1).

## Status
BUILT: all 4 tasks complete (2026-10-17); Tasks 1–3 committed (`ae4313b`, `facc3ef`, `d35f5b1`). **Waiting for the device checks** ([[Device Test Plan]] → Score Corrections Checks, C0–C7: Nigel on the Samsung for C0–C4; C5–C6 need the live camera; also in TestFlight 1.0.0 (8)). Archive the story once they pass.

## Answered (2026-10-17)
1. **Which scores:** any round of the game being played. The round in progress shows each throw as a big tappable score below the picture; tapping an earlier round's total opens its throws. (Not History: it keeps only round totals.)
2. **Misses:** each round shows its 3 slots (4 · – · –); tapping an **empty slot** opens the same popup: **0** records a miss, **1–5** adds a stuck knife the camera didn't register.
3. **Camera jog:** big targets **below** the picture, never on it; **watching pauses** while the popup is open (a hand isn't a throw); afterwards the app **checks the picture still lines up** with the locked rings and says "The phone may have moved: re-calibrate" if not.

## Acceptance Criteria
1. Tapping a throw's score (this round or an earlier one) opens a popup of 0, 1, 2, 3, 4, 5 and Cancel; the choice replaces the score, and the round, game and player totals follow.
2. Tapping an empty slot of the round in progress (or of an earlier round collected early) adds a throw with the chosen score; 0 is a miss. On one target it counts for the player whose turn it is, and the turn passes after the 3rd throw as usual.
3. A corrected game that is over is kept in History with the corrected scores (once; replacing the kept record). Adding the last throw of the last round ends the game as a detected throw would.
4. While the popup is open, nothing the camera sees is scored; watching resumes when it closes.
5. After a correction, if the picture no longer lines up with the locked rings, Play says so and suggests re-calibrating; a light tap that doesn't move the phone says nothing.
6. The Instructions say: change a score only when no one is throwing; tap lightly; the phone stays out of the line of throw; re-calibrate if told the phone moved.
7. Corrected throws are marked on Play (so a dispute's result can be seen), and a knife that later falls out still scores 0.

## Story Plan

### Task 1: The rule: set or add a throw's score
- **Work:** `GameSession.setScore(round, throw, score)` and adding a throw to a round (a manual throw, `ThrowRecord.corrected`); `Match.setScore(player, round, throw, score)` and a manual throw at the round in progress (one target: the player whose turn it is, counting toward the turn); `GameNotifier.correct(…)`, re-saving a finished game through `_keep`. Scores 0–5 from the `TargetModel`'s rings.
- **Status:** COMPLETE (2026-10-17); Nigel: "commit this and continue to task 2" (`ae4313b`)
- **Verify:** tests (change a stuck score; a bounce-out to 3; add a miss to a round in progress; add the last throw of the game and it ends; a correction after the end re-saves the same record; a later fall-out zeroes a corrected throw).
- **Next:** Task 2.
- **What changed:**
  - `lib/scoring/game_session.dart`: `ThrowResult.missed` (a miss added by hand, 0); `ThrowRecord.corrected`, `ThrowRecord.byHand(score)` (0 → missed, more → stuck with no entry point), `withScore` (keeps the camera's `result` and `point`); `unscored` is false once corrected. `GameSession.byHand(score)` (the next throw, as a detected one), `setScore(round, throw, score)` (also after the game is over), `hasRoomIn(round)`, `addToRound(round, score)` (a round collected early; it stays collected).
  - `lib/scoring/match.dart`: `byHand(score, board:)` (one target: the turn's player, counting toward the turn), `setScore(player, round, throw, score)`, `addToRound(player, round, score)`.
  - `lib/providers.dart`: `GameNotifier.setScore`, `addThrow` (not once that board's game is over), `addToRound`; each re-keeps a game that's over (`_change` → `_keep`: same record, same time; unchanged totals aren't saved again).
  - **No scoring range in the rules:** the popup (Task 2) offers 0–5 from the `TargetModel`'s rings.
- **Verified by:** `flutter test`: 627 passed (18 new), `flutter analyze`: no issues. Nothing to see on the phone until Task 2.
- **Checkpoint saved:** 2026-10-17

### Test Report — 2026-10-17 (Task 1)
- **New:** `game_session_test.dart` (10: a disputed score replaced, totals follow; the camera's result and point kept, marked corrected; a bounce-out scored and a "?" knife given its score; a miss added is a 0 `missed` throw; a knife added counts toward the round; the last throw added ends the game; a round collected early takes a throw and stays collected; a full round takes no more; a corrected knife falling out scores 0; a score set after the end); `match_test.dart` (4: one target, a miss is the turn's player's and completes the turn; a dispute changes the right player's throw; two targets, a miss at board 2 is Player 2's; a correction after the end changes the winner, 12–9 → 12–13); `keeping_games_test.dart` (4: a miss added finishes the game and it's kept; a correction after the end re-saves the same game under the same time; a correction mid-game keeps nothing; nothing added once over).
- **Results:** 627 passed, 0 failed.

### Task 2: Tappable scores and the 0–5 popup on Play
- **Work:** both Play screens: the round in progress as 3 big score slots below the picture (both players' on two targets); earlier rounds' totals tappable → that round's throws; the popup (0–5 as large buttons, Cancel); watching paused while it's open (`ThrowWatcher` stopped and restarted, so the reference picture is taken afresh); corrected scores marked (e.g. a ✎ or a different colour) on the slots and on the picture's score circles.
- **Status:** COMPLETE (2026-10-17); Nigel: "commit this and continue to task 3" (`facc3ef`)
- **Verify:** widget tests. Nigel: Live test → Target 1 → Play: change a score, add a miss, and watch the totals.
- **Next:** Task 3.
- **What changed:**
  - `lib/ui/score_corrections.dart` (new): `ScoreCorrections` (one row a player, under Play's totals: the round in progress as three 56 × 48 slots, "–" for a throw to come; tap a score → the popup → `setScore`; the first empty slot, when it's that player's throw (`Match.nextThrowerAt`), → the popup → `addThrow`; **Rounds** → "Which round?" → that round's throws (`_RoundEditor`: change one, or add to a round collected early, `addToRound`)); `showScorePicker` (0–5 as 64 px buttons, the current score outlined, Cancel); `scoreChoices` (0 and the `TargetModel`'s ring scores); `CorrectionHost` (what a Play screen does around a popup). A score set by hand shows light blue with ✎. The row scales down rather than overflowing on a narrow phone.
  - **Watching pauses while any popup is open:** `ThrowWatcher.pause` / `resume` (frames ignored; on resume `MotionDetector.restart`: the next frame is the new reference, any episode under way dropped, the learned noise kept; the full-resolution before picture taken again; the known knives kept). `PlayBoardsWatcher.pause` / `resume` for two targets.
  - **Marks remember the throw, not its score** (`RoundMarks`: knife id → (entry, `ThrowSlot`), and `ThrowSlot`s beside the board; `addByHand`), so a changed score shows on the picture at once; `paintRoundMarks` reads scores from the `Match` (`throwAt`), light blue if set by hand (`markColour`). `Match`: `ThrowSlot`, `throwAt`, `lastThrowAt`, `nextThrowerAt`.
  - Both Play screens implement `CorrectionHost` and show a row (two players: one each, "P1" / "P2"). Play's text lines are unchanged (they're the large text read from the throwing line).
- **Verified by:** `flutter test`: 646 passed (19 new), `flutter analyze`: no issues.
- **Checkpoint saved:** 2026-10-17

### Test Report — 2026-10-17 (Task 2)
- **New:** `test/ui/score_corrections_test.dart` (9: the choices 0–5; the slots; a score changed, marked ✎, watching paused then resumed; Cancel changes nothing; an empty slot adds a miss, marked beside the board; only the first empty slot; one target, not the other player's mid-turn; Rounds → round → change, paused once for the visit; no Rounds before there's an earlier round); `test/game/throw_watcher_pause_test.dart` (4, the rendered bounce-out through a real `ThrowWatcher`: reported unpaused; paused over the throw, nothing; paused mid-throw, the rest not taken for a throw; resume says ready); `motion_detector_test.dart` (restart drops an episode under way); `play_screen_test.dart` (3: the slots on Play; a row each for two players; a hand-set mark is light blue).
- **Updated:** `round_marks_test.dart` (marks hold throws, not scores; 2 new: a throw the game ignored leaves no mark; a throw added by hand), `two_target_play_screen_test.dart` (the painter reads the `Match`).
- **Results:** 646 passed, 0 failed.

### Task 3: Did the phone move? The check after a correction
- **Work:** after the popup closes, compare the next settled frame with the picture from before it opened, over the board and its surroundings: a whole-picture shift means the phone moved ("The phone may have moved: re-calibrate"); a knife-sized change does not. Measured on renders with the camera nudged by small amounts (`SyntheticScene`) and on the Live test footage, so the threshold has a reason.
- **Status:** COMPLETE (2026-10-17); Nigel: "commit this and continue to task 4" (`d35f5b1`)
- **Verify:** fixture tests (nudged vs not); Nigel taps the phone lightly on its stand, then knocks it.
- **Next:** Task 4.
- **What changed:**
  - `lib/vision/camera_move.dart` (new): `cameraShift(before, after, region)` (the shift that best lines the two pictures up over the board, `bestShift` up to ±8 px, at the watchers' ~320 px); `phoneMovedShift` = **2 px**; `phoneMoved`.
  - **Why 2 px (measured 2026-10-17):** still frames of the Live test footage shift by up to 1 px (compression); Nigel's sofa-arm nudge of 2026-10-09, 1.4 px (the motion detector already treats it as harmless); a knife sticking, a bounce-out and someone collecting the knives (renders), 0. On boards of 40–65 px radius at 320 px, 2 px is 0.03–0.05 of the radius: a sixth to a quarter of a ring's width, enough to score a knife near a line in the next ring. A bigger jump than the search reads as 8 px (still a move).
  - `ThrowWatcher`: `pause` keeps the last picture; after `resume`, the first still frame at least `moveCheckDelay` (0.5 s: a tapped tripod wobbles, then settles) is compared; a move is reported on `moves` (the shift). Only after a pause: ordinary play is unchanged. `PlayBoardsWatcher.moves` gives the board.
  - Play: `phoneMovedMessage` ("The phone may have moved. If the green rings no longer line up with the board, calibrate again."); two targets: `boardMovedMessage(board)` ("…(Player 2's board)… choose the boards again."), in the usual message line.
  - **Not done:** re-locating the rings automatically. The app says so and the user decides, as for "the view changed".
- **Verified by:** `flutter test`: 664 passed (18 new), `flutter analyze`: no issues.
- **Checkpoint saved:** 2026-10-17

### Test Report — 2026-10-17 (Task 3)
- **New:** `test/vision/camera_move_test.dart` (13: the same picture, 0; shifts (1,0) and (1,1) not moved, (2,0), (0,−2), (3,1), (6,0) moved; a jump beyond the search reads 8; a knife, a bounce-out and a retrieval (first vs last frame) not a move; Nigel's nudge 1.41 px, not a move; the Live test footage still for a second, ≤ 1 px); `test/game/throw_watcher_pause_test.dart` (4: through a real `ThrowWatcher`: moved 3 px after a pause, reported once; not moved; a 1 px wobble; no check without a pause); `play_screen_test.dart` (the message).
- **Results:** 664 passed, 0 failed.

### Task 4: Instructions, docs, device checks, traceability
- **Work:** the in-app Instructions (when to touch the phone; misses; disputes); **Review Agent §7** (someone at the phone mid-game, beside the lanes); Design Decisions, Glossary, Data Flow, System Diagram, web pages; Device Test Plan checks; Traceability Agent; backlog.
- **Status:** COMPLETE (2026-10-17), awaiting Nigel's checkpoint
- **Verify:** Nigel reads the instructions; the checks are ready.
- **What changed:**
  - `lib/ui/instructions.dart`: a **Changing a score** section after Scoring (tap a score, 0 to 5, light blue with ✎; a knife that misses: the next empty slot, 0; one the app missed: its score; earlier rounds: Rounds; **go to the phone only when no one is throwing, tap lightly; nothing thrown while a score is open is scored**; if the phone may have moved, check the rings, calibrate again / choose the boards again); in Safety: "Changing a score means going to the phone: only when no one is throwing, and with two targets only when both have finished. Leave the phone where it is; never move it closer to reach it." Paper target: "pen", "paper".
  - **Review Agent fix:** the phone-moved messages now end "…when no one is throwing" (`phoneMovedMessage`, `boardMovedMessage`): they send someone to the phone.
  - **Review Agent checklist** (`docs/agents/review-agent/review-agent.md` §7): a new item, "Does a control invite someone to the phone during a game?", as its directive 4 asks for a new kind of risk.
  - Docs: [[Design Decisions]] → Score Corrections; [[Glossary]] (the components and functions; concepts **Score set by hand**, **Camera shift**); [[Data Flow]]; [[System Diagram]] (`ScoreCorrections`, `cameraShift`); web pages (a **Changing a score** flow; the Screens, ThrowWatcher, MotionDetector and GameSession pages; rebuilt: 9 flows); [[Device Test Plan]] → Score Corrections Checks C0–C7; [[Mac Handoff]] section 000; backlog #14; `CLAUDE.md`, `working-with-nigel.md`.
- **Verified by:** `flutter test`: 667 passed (3 new), `flutter analyze`: no issues.
- **Checkpoint saved:** 2026-10-17

### Test Report — 2026-10-17 (Task 4)
- **New:** `instructions_test.dart` (2: how to change a score and add a miss, with the paper wording; going to the phone only when no one is throwing, tapping lightly, nothing scored meanwhile, the moved message, never moving the phone closer); `two_target_play_screen_test.dart` (the moved message names the board and says when). **Updated:** the section order (Changing a score after Scoring); `play_screen_test.dart` (the message says when).
- **Results:** 667 passed, 0 failed.

### Safety Report — 2026-10-17 (whole story, Review Agent)
- **Files reviewed:** `lib/ui/score_corrections.dart`, both Play screens, `lib/ui/instructions.dart`, `lib/game/throw_watcher.dart`, `lib/vision/camera_move.dart`; `pubspec.yaml`, `AndroidManifest.xml`, `Info.plist` unchanged.
- ✅ §1–§2: no permission, plugin or platform change; Dart only, both platforms alike.
- ✅ §3: no debug-only paths.
- ✅ §4–§5: nothing new is stored or sent; corrected scores reach History only as round totals, as before.
- ✅ §6: the phone-moved check is one `bestShift` over the board (±8 px, every 2nd pixel at ~320 px), once per popup; pausing saves work.
- ⚠️→✅ **§7 Physical safety (the main risk):** this is the first control that brings someone **to the phone during a game**. With one target the phone is about 2 m from the board, 45° to one side: going to it means walking beside the lane, part-way down it. With two targets it's behind the throwers, near a backswing. Mitigations: the slots are passive (nothing ever says "tap now" or calls anyone to the phone); the Instructions say only when no one is throwing (two targets: both finished), tap lightly, never move the phone closer; nothing thrown while a popup is open is scored, so there's no reason to throw while someone is at the phone. **Flagged and fixed:** "The phone may have moved… calibrate again" sent someone to the phone without saying when; it now ends "when no one is throwing". **Residual:** the app can't see whether anyone is throwing; it relies on the players, as for collecting knives. Added to the §7 checklist for future features.
- ✅ §8: no stored format change; rolls back cleanly.
- **Verdict:** OK to commit (the flagged item is fixed).

### Traceability Report — 2026-10-17 (story complete, device checks to come)

- **AC1: tap a throw's score (this round or an earlier one) → 0–5 + Cancel; totals follow**
  - **Design Reference:** Design Decisions → Score Corrections
  - **Implementation:** `ScoreCorrections`, `showScorePicker`, `scoreChoices`, `_RoundList`, `_RoundEditor`; `GameSession.setScore`, `Match.setScore`, `GameNotifier.setScore`
  - **Test:** `score_corrections_test.dart` (change; Cancel; Rounds → round → change); `game_session_test.dart`, `match_test.dart` ('scores set by hand')
  - **Status:** ✅ Covered (device: C1, C3)
- **AC2: an empty slot adds a throw (0 a miss); one target: the turn's player, counting toward the turn**
  - **Design Reference:** Score Corrections
  - **Implementation:** `ThrowRecord.byHand`, `ThrowResult.missed`, `GameSession.byHand` / `addToRound`, `Match.byHand` / `nextThrowerAt`, `GameNotifier.addThrow` / `addToRound`
  - **Test:** `score_corrections_test.dart` (adds a miss; only the first slot; not the other player's mid-turn); `match_test.dart` (the turn's player, completes the turn); `game_session_test.dart`
  - **Status:** ✅ Covered (device: C2, C4)
- **AC3: a corrected finished game is kept with the new scores, once; the last throw added ends the game**
  - **Design Reference:** Score Corrections; Game History
  - **Implementation:** `GameNotifier._change` → `_keep`
  - **Test:** `keeping_games_test.dart` (a miss finishes the game; a correction after the end re-saves the same record and time)
  - **Status:** ✅ Covered
- **AC4: nothing is scored while a popup is open; watching resumes after**
  - **Design Reference:** Score Corrections → without jogging
  - **Implementation:** `ThrowWatcher.pause` / `resume`, `MotionDetector.restart`, `PlayBoardsWatcher.pause` / `resume`, `CorrectionHost`
  - **Test:** `throw_watcher_pause_test.dart` (paused over the throw; mid-throw; ready again); `motion_detector_test.dart` (restart); `score_corrections_test.dart` (pause and resume around every popup)
  - **Status:** ✅ Covered
- **AC5: after a correction, a moved phone is reported; a light tap is not**
  - **Design Reference:** Score Corrections → 2 px
  - **Implementation:** `cameraShift`, `phoneMovedShift`, `ThrowWatcher.moves`, `phoneMovedMessage`, `boardMovedMessage`
  - **Test:** `camera_move_test.dart` (13); `throw_watcher_pause_test.dart` (moved 3 px; not moved; 1 px; no pause)
  - **Status:** ✅ Covered (device: C5, C6)
- **AC6: Instructions: only when no one is throwing; tap lightly; out of the line of throw; re-calibrate if told**
  - **Design Reference:** Score Corrections → Safety
  - **Implementation:** `instructionSections` → Changing a score, Safety
  - **Test:** `instructions_test.dart` (2)
  - **Status:** ✅ Covered (and the Safety Report)
- **AC7: corrected throws are marked; a corrected knife that falls out scores 0**
  - **Design Reference:** Score Corrections
  - **Implementation:** `_Slot` (light blue, ✎), `markColour`, `RoundMarks` (`ThrowSlot`), `paintRoundMarks(match:)`
  - **Test:** `score_corrections_test.dart` ('1✎'); `play_screen_test.dart` (light blue); `round_marks_test.dart`; `game_session_test.dart` (falls out → 0)
  - **Status:** ✅ Covered

- **Coverage:** 7 of 7 with design, code and tests; device checks C0–C7 to come.
- **Backward:** every new symbol traces to an AC. `Match.throwAt` / `lastThrowAt` serve the marks (AC7) and adding by hand (AC2).
- **Stale links:** none. The marks beside the board now show the throw's real score (a stuck knife without an entry still shows 0, as before).

---

## Plan Changes Log
- **2026-10-17:** Planned from Nigel's request; three questions answered as recommended.
- **2026-10-17:** All 4 tasks done; story BUILT, waiting for C0–C7. Review Agent: the phone-moved messages now say "when no one is throwing".

## Notes
- **Safety:** this is the first feature that invites someone to the phone during a game. The phone is beside the lane (Play: 2 m from the board, 45° to one side; two targets: behind the throwers), so the Instructions must say only when no one is throwing, and the Review Agent checks the wording (§7).
- Not in this story: correcting kept games in History (round totals only), a note of who disputed what, Quick draw (a duel has one throw each and its own result).
