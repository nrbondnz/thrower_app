# Story Checkpoint: Named Players

## Story Goal
Players can be given names in place of "Player 1" and "Player 2": "Mark wins", not "Player 2 wins". Stage 1 of the [[Accounts Roadmap]], in Nigel's model (2026-10-19): the app user **names players**, who **just have scores** ("they could just as well be player 2"). A name is a label on a seat for a game: no player list, no history of their own, nothing sent anywhere. Friends with their own accounts come in stage 3. Requirement: [[Player Names]].

## Complexity Score
6 (Large):
- layers: scoring (`Match`), history (`GameRecord`), a new store for the names, and the UI (Play, two targets, History, Quick draw) (4);
- a stored-data change (`GameRecord` version 2) (1);
- more than 3 acceptance criteria (1).

## Status
PLANNED (2026-10-19): waiting for Nigel's approval of the plan. No code yet.

## Answered (2026-10-19)
1. **Remembering:** the **last names used, kept on the phone**: the setup screen fills them in, even after the app is closed. Change them by typing. No list to manage.
2. **A blank seat** shows **"Player 1" / "Player 2"**, as today. Naming is optional.
3. **Players:** still **1 or 2**; more players taking turns is its own story (backlog).
4. **Quick draw** uses **the same names** ("Tap the centre of Mark's board", "Mark wins the match 2–1"), changeable on its screen before Start.

## Decisions Taken Without Asking (say if wrong)
- **Names are part of the game** (`Match`): the history record, the result and every line on screen read them from the game. Changing a name mid-game renames that game; it doesn't restart it. **New game** keeps the names.
- **Up to 16 characters**, trimmed. A longer name wouldn't fit the large "Mark's turn" text read from the throwing line. Two seats with the same name are allowed.
- **Stored in their own small file** (`player_names.json`, in the app's private folder, beside the history), behind an interface like `GameHistory`. They live in a new edge folder, `lib/settings/`, because names aren't history. If the file can't be read, the names start blank; nothing else depends on it.
- **History keeps the names a game was played with.** Games kept before this story show "Player 1" / "Player 2", as now.

## Acceptance Criteria
1. Play's setup screen has a name field for each player (one for 1 player, two for 2). Blank means "Player 1" / "Player 2".
2. The names are filled in next time, even after the app is closed.
3. Play and two-target Play use the names everywhere a player is named: whose turn, wait for, the totals, the winner, the score-correction rows, the board messages.
4. History shows each game's names, and old games still show Player 1 / Player 2. (The stored format becomes version 2; version 1 files still read.)
5. Quick draw uses the same names: choosing the boards, the result, the match. They can be changed on its screen before Start.
6. Renaming during a game keeps the scores; New game keeps the names.
7. Names stay on the phone: nothing is sent anywhere (Review Agent).

## Story Plan

### Task 1: Names in the game, the history record and a store
- **Setup:** `Match` (`lib/scoring/match.dart`) numbers its players; `GameRecord` (version 1) stores round totals only.
- **Work:**
  - **`Match`:** `names` (a name or null per player), `withNames(…)` (same game, new names), `nameOf(i)` (the name, or "Player i+1").
  - **`GameRecord` version 2:** each player's name; `nameOf(i)`; version 1 files still read; a newer version is still set aside, as now.
  - **`PlayerNamesStore`** (interface) and **`FilePlayerNamesStore`** (`lib/settings/`): `load` and `save`, with safe writes.
  - **`playerNamesProvider`:** loads at start, saves on change.
  - **`GameNotifier`:** puts the names on the game without restarting it; New game keeps them.
- **Verify:** tests:
  - `nameOf` with and without names;
  - renaming keeps the scores;
  - a version 2 record round-trips, and a version 1 file still reads;
  - the store saves, loads, and starts blank on a damaged file;
  - New game keeps the names.

  Nothing to see on the phone yet.
- **Next:** Task 2.

### Task 2: Names on the setup screen, Play and History
- **Setup:** Task 1.
- **Work:**
  - **The setup screen:** a name field per player, filled with the last names (16 characters at most).
  - **Every "Player N" in Play, two-target Play, the score-correction rows and History** comes from `nameOf`:
    - `turnText`, `turnDetail`, `playerTitle`, `matchFooter`;
    - the two-target board messages;
    - `ScoreCorrections` (its row labels: the name's first letters, or P1 / P2);
    - History's `resultText` and `GameRecordScreen`.
- **Verify:** widget tests:
  - names typed show in the turn line, the totals, the winner and History;
  - a blank name is Player 1;
  - names are filled in again on the next visit;
  - the longest name fits the turn line on a narrow phone.

  **Nigel:** Live test → Play, 2 players, type two names, play, and check History.
- **Next:** Task 3.

### Task 3: Names in Quick draw
- **Setup:** Task 2.
- **Work:**
  - **Quick draw's screen** gets a **Names** button before Start, with two fields, the same names as Play.
  - The texts take the names:
    - `choosingInstruction` ("Tap the centre of Mark's board"), `boardLines`;
    - `verdictText` and the result panel (`headline`, `matchText`, `roundLabel`'s line);
    - the recorded Quick draw too.
- **Verify:** widget tests (the board instruction, the round and match result with names, blank → Player 1). **Nigel:** Live test → Quick draw with names.
- **Next:** Task 4.

### Task 4: Instructions, docs, device checks, traceability
- **Setup:** Task 3.
- **Work:**
  - `lib/ui/instructions.dart`: naming players (optional, remembered, kept on the phone);
  - [[Design Decisions]] (names in the game; the store; `GameRecord` version 2);
  - [[Glossary]] (named player; `PlayerNamesStore`), [[System Diagram]], [[Data Flow]], web pages;
  - [[Device Test Plan]] → Named Players checks; [[Mac Handoff]] (build 9 or 10);
  - [[Player Names]] status; the backlog.
  - **Review Agent:** §5 (names of real people stored on the phone, not sent), §8 (the version 1 → 2 history format).
  - **Traceability Agent** report.
- **Verify:** `flutter test`; Nigel reads the Instructions; the checks are ready.

---

## Plan Changes Log
- **2026-10-19:** Planned from Nigel's model of app users, named players and friends; four questions answered as recommended (last names kept on the phone; blank is Player N; 1 or 2 players; Quick draw too).

## Notes
- Friends (other app users, linked accounts, throws recorded on their own app) are stage 3 of the [[Accounts Roadmap]]. A seat will then be a named player **or** a friend, so `Match.names` should stay a label, not become an identity.
