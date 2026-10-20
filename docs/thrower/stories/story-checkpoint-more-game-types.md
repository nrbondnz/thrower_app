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
- **Status:** IN PROGRESS

## Task 3: History, Instructions, docs, backlog, traceability
- **Status:** NOT STARTED

---

## Plan Changes Log
- (none yet)
