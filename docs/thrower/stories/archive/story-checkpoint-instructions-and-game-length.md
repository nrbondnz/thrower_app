# Story Checkpoint: Instructions, 9-Round Games and Reset

## Story Goal
Testers can read in the app how to set up and how rounds work; a game is a fixed 9 rounds of 3 throws, ending with a final total; the player can reset a game safely.

## Complexity Score
3 (Medium: UI + game layers, game-over branch, 4 acceptance criteria) → Story Agent with 4 tasks.

## Decisions (Nigel, 2026-10-09)
- **Fixed 9-round game.** After round 9 is complete: *Game over* with the final total; further throws are ignored until a new game.
- **Instructions live in a Dart content file** (`lib/ui/instructions.dart`), no new dependency. Rule numbers (rounds, throws per round, ring scores) come from `GameSession` / `TargetModel`, so the text can't drift from the code; a test checks this. Chosen over a Markdown asset + package (easier editing, but adds a dependency and hand-typed numbers).
- **Reset with confirm.** The Play screen's existing *New game* app-bar button becomes *Reset game* and asks first ("Reset this game? Scores will be lost."). At game over a large *New game* button starts again with no confirmation.

## Status
DONE (2026-10-09): committed in `442d1af`; build 1.0.0 (2) uploaded to TestFlight, 1.0.0 (3) archived. Field results from Mark still to come (Device Test Plan S4, P5, P6).

---

## Task 1: Fixed 9-round games
- **Status:** COMPLETE (code + tests); phone check pending
- **What changed:** `GameSession.maxRounds` (9), `isOver`, `_withRounds` (keeps the rules through every change); throws after game over return the same session. `GameNotifier.onEvent` ignores stuck/bounce-out events after game over, so a post-game knife isn't linked to round 9's last throw (its falling out would otherwise zero a real score). Play text: "Round N of 9", and "Game over! Final total: X / Rounds: … / Collect your knives when no one is throwing."
- **Files:** `lib/scoring/game_session.dart`, `lib/providers.dart`, `lib/ui/play_screen.dart`, `test/scoring/game_session_test.dart`, `test/game/game_notifier_test.dart`
- **Checkpoint saved:** 2026-10-09
- **Work:** `GameSession.maxRounds` (default 9) and `isOver` (round 9 complete: 3 throws, or closed early by collecting). Throws after game over are ignored. Play shows "Round N of 9"; at game over "Game over: total X" replaces "collect your knives".
- **Verify:** `flutter test` (new `game_session_test` cases: round 9 ends the game, throws after it are ignored, early-closed round 9 ends it). On the phone: placed-pen throws are hard to do 27 times, so the unit tests carry this one; Nigel checks the "Round N of 9" text.

## Task 2: Reset with confirmation, New game at game over
- **Status:** COMPLETE (code + tests); phone check pending
- **What changed:** app-bar *New game* → **Reset game** (disabled before the first throw) with a confirm dialog; a **New game** `FilledButton` under the scores at game over.
- **Files:** `lib/ui/play_screen.dart`, `test/ui/play_screen_test.dart` (new)
- **Checkpoint saved:** 2026-10-09
- **Depends on:** Task 1
- **Work:** *Reset game* app-bar button with a confirm dialog (Cancel keeps the game); *New game* button shown at game over.
- **Verify:** widget tests (cancel keeps scores; confirm clears them; game over shows New game). On the phone: score a throw, tap Reset game → Cancel (score kept) → Reset (cleared).

## Task 3: Instructions screen
- **Status:** COMPLETE (code + tests); phone check pending
- **What changed:** `lib/ui/instructions.dart`: `InstructionSection`, `instructionSections(rules, target)`, `InstructionsScreen`. *Instructions* (outlined) is the first button on Home. Includes Nigel's tripod note: a stable phone, preferably on a tripod, for calibration and play; calibrate again if it moves.
- **Files:** `lib/ui/instructions.dart` (new), `lib/ui/home_screen.dart`, `test/ui/instructions_test.dart` (new)
- **Checkpoint saved:** 2026-10-09
- **Depends on:** Task 1 (uses `maxRounds`)
- **Work:** `lib/ui/instructions.dart` (headed sections: Setting up, Calibrating, Playing a game, Scoring, Resetting, Safety, Reporting problems) and an *Instructions* button at the top of Home. Safety text never implies it's safe to approach the board.
- **Verify:** widget test (Home → Instructions opens; text states 9 rounds of 3 from the constants). On the phone: tap Instructions and read it.
- **Docs:** Design Decisions → Rounds and Scoring (9 rounds, reset); Common Tasks → "Update the in-app instructions" (when rules change, edit `instructions.dart`).

## Task 4: Traceability review
- **Status:** COMPLETE (matrix below); archive after Nigel's phone check
- **Depends on:** Tasks 1–3
- **Work:** requirement → design → code → test matrix for this story; archive it.

---

## Plan Changes Log
- **2026-10-09:** Nigel approved the plan and asked to run all tasks without pausing ("do all you can of the tasks and I will check in later"); the per-task phone checks are batched for his return.
- **2026-10-09:** Nigel added: tell testers the camera must be in a stable place for calibration and play, preferably on a tripod → added to Task 3 ("Setting up the phone"), with a test.
- **2026-10-09:** Nigel: two versions of the instructions, **Real board** (main) and **Paper target** (paper + Blu Tack) → `InstructionTarget` switch at the top of the page, Real board by default; "Setting up the phone" renamed "Setting up". 8 more tests (248 total). Field test S4 now asks for the Paper target version first.
- **2026-10-09:** Nigel asked to make it as good as possible before Mark gets it: the Device Test Plan and its page were updated (see Doc Update), and the build number bumped to `1.0.0+2` for TestFlight.

---

## Test Report — 2026-10-09

### New Tests
- `game_session_test.dart` → group '9-round games' (8): default 9 × 3; not over after 8 rounds or part-way through 9; over after round 9's 3rd throw; over when round 9 is collected early; throws after game over ignored; a round-9 fall-out after game over still scores 0; a custom length survives every change.
- `game_notifier_test.dart` (3): a post-game stuck knife is ignored, so its falling out changes nothing; "Round 9 of 9"; game-over text with the final total and every round.
- `play_screen_test.dart` (5, new): Reset disabled before the first throw; Cancel keeps scores; confirming clears; no New game mid-game; New game at game over starts again without asking.
- `instructions_test.dart` (9, new): 9 rounds of 3 from the rules; text follows changed rules; ring scores and line rule from `TargetModel`; tripod; lane-safety wording; section order; Home → Instructions; the last section scrolls into view.

### Updated Tests
- `game_notifier_test.dart`: round text now "Round N of 9".

### Results
- `flutter analyze`: no issues. `flutter test`: **240 passed, 0 failed**.

### Notes
- Play widget tests can't use `pumpAndSettle`: the camera never starts in tests and its spinner animates forever; they pump 500 ms instead.

## Doc Update — 2026-10-09

### Files Updated
- `Architecture/Design Decisions.md` → Rounds and Scoring: 9-round games, game over, reset with confirm, in-app instructions (with the rejected alternatives).
- `Operations/Common Tasks.md`: new *Update the In-App Instructions*.
- `stories/backlog.md` → Game modes: 9 rounds + reset done.
- `docs/agents/docs-agent/docs-agent.md`: trigger added: anything testers are told → check `lib/ui/instructions.dart`.

### Drift Fixed (Nigel asked, 2026-10-09)
- `Operations/Device Test Plan.md` and the interactive page (Thrower Field Test, version 5): tripod / completely still mount (S0, S3, R1, with a re-calibrate note); new **S4** read the Instructions, **P5** Reset game, **P6** a whole 9-round game (optional); "Round N of 9" in P1/P2; store vs home-screen name; build 1.0.0 (2) or later; lane-safety line. Existing step IDs unchanged, so saved results stay linked.

---

## Traceability Report — Story: Instructions, 9-Round Games and Reset

| Requirement | Design Reference | Implementation | Test | Status |
|---|---|---|---|---|
| R1: a game is a maximum of 9 rounds (fixed 9) | Design Decisions → Rounds and Scoring (update 2026-10-09) | `GameSession.maxRounds`, `isOver`, `_withThrow` | game_session_test '9-round games' | ✅ Covered |
| R1a: game over shows the final total; later throws ignored | same | `gameText` (isOver branch), `GameNotifier.onEvent` guard | game_notifier_test 'game over shows…', 'after game over a stuck knife is ignored…' | ✅ Covered |
| R2: users can reset the play session | Design Decisions (Reset asks first) | `_PlayScreenState._confirmReset`, `_newGame` | play_screen_test (Cancel / confirm / disabled) | ✅ Covered |
| R2a: start again at game over | same | `New game` FilledButton when `game.isOver` | play_screen_test 'game over shows New game…' | ✅ Covered |
| R3: Instructions button on the main screen opens a new page | Design Decisions (in-app Instructions) | `HomeScreen` → `InstructionsScreen` | instructions_test 'Home → Instructions…' | ✅ Covered |
| R3a: explains setup and how rounds work | same | `instructionSections` | instructions_test (sections, rounds, scoring) | ✅ Covered |
| R3b: instructions can change as the project changes | Common Tasks → Update the In-App Instructions; Docs Agent trigger | rule numbers read from `GameSession` / `TargetModel` | instructions_test 'follows the rules if they change' | ✅ Covered |
| R5: two versions: real board (main) and paper + Blu Tack | Design Decisions (two versions) | `InstructionTarget`, `instructionSections(kind:)`, `SegmentedButton` | instructions_test 'real board…' / 'paper target…' groups, 'opens on Real board…' | ✅ Covered |
| R4: stable camera, preferably a tripod (Nigel) | Plan Changes Log | `instructionSections` → Setting up | instructions_test 'tripod' | ✅ Covered |
| Safety: never imply the lane is clear | Review Agent §7 | `instructionSections` → Safety; reset/collect wording | instructions_test 'lane is clear' | ✅ Covered |

**Coverage:** 10/10 requirements fully covered. **Orphan code:** none (`_withRounds` exists so `maxRounds` survives every change; tested). **Gaps:** button names in the instructions are typed by hand and not checked against the screens (documented in Common Tasks); on-device verification pending.

## Notes
- The TestFlight build for testers needs a new upload (`1.0.0+2`) once this story is done.
