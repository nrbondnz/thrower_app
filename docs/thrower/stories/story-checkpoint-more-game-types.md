# Story Checkpoint: More Game Types (Precision, Three Targets)

## Story Goal
Two more ways to play, from Nigel (2026-10-20), scored by hand on a score pad for now (the camera later):
- **Precision:** 7 rounds of 3 knives (21), one round from each distance: **3, 5, 7, 3, 4, 5, 7 m** (Nigel's best guess; to confirm). In competition the whole set is thrown 4 times (84 knives, "a marathon"): backlogged.
- **Three targets** (Nigel's name for now, in place of "Multi"): three 5-ring boards; each round a thrower throws one knife at each target; 3, 5 or 7 rounds.
- Both: 1 or 2 players, **taking turns** (Player 1 throws 3 and collects, then Player 2); KATTA scoring (5 to 1, 0 a miss); the highest total wins.

Requirement: [[Game Type]].

## Complexity Score
5 (Large): scoring → UI → history (3 layers), a new history format (version 3), several acceptance criteria.

## Status
IN PROGRESS: plan approved 2026-10-20 ("ok, go"); run whole, committing per task ([[dont-ask-again]]).

## Answers (2026-10-20)
- Precision distances: "lets guess at 3,5,7,3,4,5,7" (Nigel listed 8 distances for 7 rounds).
- Three targets: the same 5-ring boards, KATTA scoring.
- Two players: take turns.
- Name: "Three targets".

---

## Task 1: Rules and records (scoring code, tested)
- **Status:** COMPLETE (2026-10-20)
- **What changed:**
  - `lib/scoring/game_type.dart` (new): `GameType` (`scoring`, `precision`, `threeTargets`), each with its `label`, `roundChoices` ([3, 5, 9], [7], [3, 5, 7]), `defaultRounds`, `handScored`, `distanceOf(round)` and `targetOf(index)`; `precisionDistances` = [3, 5, 7, 3, 4, 5, 7].
  - `Match`: a `type` (Scoring unless given), kept through every change; `nextDistance` and `nextTarget` for whoever throws next (`nextThrowerAt`). The turn and round rules are unchanged: the types differ only in where knives are thrown from or at.
  - `GameRecord` **version 3**: `type`, written only for the new types (a Scoring game is written as version 2 wrote it); missing reads as Scoring; an unknown type is a `FormatException` (a newer app's game: the History file and the backup already set such games aside).
  - `providers.dart`: `gameTypeProvider` (`GameTypeNotifier`, Scoring unless chosen); `GameNotifier` builds the match with the type and a length the type offers (else its `defaultRounds`); `newGame` keeps the type.
- **Tests:** `test/scoring/game_type_test.dart` (new, 23: the types, Precision alone and in turns, Three targets, the type kept, the record round trip and old and unknown records); `keeping_games_test.dart` (+4: Precision's 7 rounds, Three targets' length, a hand-scored game kept with its type, New game keeps the type); the version checks in `game_record_test` and `game_history_test` updated to 3.
- **Verified by:** `flutter test`: 833 passed; `flutter analyze`: no issues.

## Task 2: Choose and play them (setup + score pad)
- **Status:** COMPLETE (2026-10-20); device check to come (GT checks, Task 3)
- **What changed:**
  - `lib/ui/play_setup_screen.dart`: **Which game?** first (chips `playGame-<type>`). Precision and Three targets: no target choice (two players take turns: `sharedTarget`); their own lengths (Precision "7 rounds", fixed; Three targets 3, 5 or 7); a length the type doesn't offer goes to its default; their description (`typeDescription`: the distances; one knife at each target; taking turns; the score pad). **Start** opens the score pad for them.
  - `lib/ui/score_pad_screen.dart` (new): `ScorePadScreen`, no camera:
    - large `padHeadline` ("Mark's turn", "Your turn", "Collect your knives", "Mark wins", "A draw", "Game over! 63") and `padWhere` ("Round 2 of 7: from 5 m", "Round 1 of 3: at target 2", "When no one is throwing. Then Nigel's turn.");
    - `ScorePad`: 5, 4, 3, 2, 1 and **Miss** (from the target model's rings), feeding `GameNotifier.addThrow`;
    - a safety line: score when no one is throwing, or have someone who isn't throwing keep score;
    - each player's total and rounds (`padPlayerDetail`: Precision's with distances, "3 m: 12, 5 m: 9"), and Play's `ScoreCorrections` rows (tap a slot to change it);
    - **Finish game** (asks first), **New game**; kept in History through the same `gameProvider`.
  - `providers.dart`: a hand-scored game is never kept as a Live test game (no recording); `GameLengthNotifier.choices` now comes from `GameType.scoring`.
- **Tests:** `test/ui/score_pad_screen_test.dart` (new, 17: the setup choices, Precision alone, Three targets for two, Finish game, a correction, the texts); `play_setup_screen_test.dart`: a taller test screen (the setup screen grew).
- **Verified by:** `flutter test`: 850 passed; `flutter analyze`: no issues. On the Samsung: to come.

## Task 3: History, Instructions, docs, backlog, traceability
- **Status:** IN PROGRESS

---

## Plan Changes Log
- (none yet)
