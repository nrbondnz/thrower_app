# Story Checkpoint: Game History

## Story Goal
Finished games of Play are **kept on the phone** and can be looked back at: when, how it was played, each player's rounds and total, who won. Nigel, 2026-10-16: "start on game lengths, then history". Backlog #5 (the last part, apart from typed names). Follows [[story-checkpoint-players-and-targets]] (built; device checks to come) and the game-length choice (3, 5 or 9 rounds, done 2026-10-16).

## Complexity Score
5 (Medium–Large): storage → game wiring → a new screen (3), a new data model (`GameRecord`) (1), a dependency change (`path_provider` made direct; Review Agent) (1).

## Status
PLANNED (2026-10-16). Waiting for Nigel's approval and answers to the open questions. No code yet.

## What Exists (checked 2026-10-16)
- `Match` (`lib/scoring/match.dart`): each player's `GameSession` (rounds, throws, totals), `mode`, `maxRounds`, `isOver`, `winner`, `draw`. Everything a record needs is there when a game ends.
- Nothing is saved between app launches today (the calibration and the game live only for the session).
- **`path_provider` is already in the app**, pulled in by `audioplayers` (`pubspec.lock`). Listing it in `pubspec.yaml` adds no new native code, permission or size.

## Open Questions (for Nigel, with recommendations)
1. **How games are stored.** **Recommended (architectural): a `GameHistory` interface, with one JSON file in the app's own documents folder behind it** (`path_provider`). It's small, readable, easy to test with a temporary folder, and when accounts come (backlog #4) a backend version can replace the file without touching the screens. *Alternatives:* `shared_preferences` (meant for settings, a new plugin, awkward for a growing list); a database (`sqflite` / `drift`: a new native plugin, far more than a list of games needs).
2. **Which games are kept.** **Recommended: finished games only** (every player has played every round). A game reset or left half-way isn't kept.
3. **Live test games.** **Recommended: kept, marked "Live test"**, so the history can be tried on a phone with the recordings, without throwing. **Clear history** removes them along with the rest. *Alternative:* not kept at all (a cleaner list, but nothing to look at until real games are played).
4. **Where it's seen.** **Recommended: a History button on Home** (under Play): a list, newest first ("16 Oct, 14:32 · 2 players, 1 target · 5 rounds · Player 2 wins 61–58"); tap one for every round of each player. **Delete** one game, or **Clear history** (asks first).
5. **How many are kept.** **Recommended: all of them** (a game is well under 1 KB). A limit can come later if needed.

## Acceptance Criteria
1. When a game of Play ends, it is saved on the phone: date and time, mode, rounds, each player's round totals and total, the winner (or a draw); a Live test game is marked so.
2. It survives closing and reopening the app.
3. Home → **History** lists the games, newest first; tapping one shows every round of each player.
4. One game can be deleted; **Clear history** removes all, after asking.
5. A game that isn't finished is not saved; a finished game is saved once (not again on rebuilds, New game, or leaving Play).
6. If the file can't be read or written, Play still works, and History says it couldn't load (nothing crashes).
7. Nothing leaves the phone (Review Agent: privacy; no new permission).

---

## Task 1: The record and the store
- **Status:** NOT STARTED
- **Work:**
  - `GameRecord` (pure Dart): when, mode, rounds, Live test or not, each player's round totals, total, winner / draw; `toJson` / `fromJson` (with a version number, so the format can change later).
  - `GameHistory` (interface): `load`, `add`, `delete`, `clear`. `FileGameHistory`: one JSON file in the app's documents folder (`path_provider`, made a direct dependency: **Review Agent**). A damaged file is set aside, not lost or crashed on.
  - `gameHistoryProvider`; tests use a temporary folder or a fake.
- **Verify:** tests (save, reload, delete, clear, a damaged file).
- **Next:** Task 2.

## Task 2: Save each finished game
- **Work:** when a `Match` becomes over, its `GameRecord` is added, once. Live test games marked. Not for reset or unfinished games.
- **Verify (on this PC):** a widget test plays a short game to the end and finds it saved once; Live test → Target 1, a 3-round game, is saved as "Live test".
- **Next:** Task 3.

## Task 3: The History screen
- **Work:** Home → **History**: the list (newest first), a game's rounds, delete one, **Clear history** (asks first), "No games yet", and "Couldn't load the history" if the file fails.
- **Verify:** Nigel opens History on his Samsung after a Live test game (no throwing needed).
- **Next:** Task 4.

## Task 4: Instructions, docs, device checks, traceability
- **Work:** the in-app Instructions (History, what's kept and where); Design Decisions, Glossary, Data Flow, System Diagram, web pages; Device Test Plan checks for the next TestFlight build; Review Agent; Traceability Agent; backlog #5.
- **Verify:** Nigel reads the instructions; the checks are ready.

---

## Plan Changes Log
- **2026-10-16:** Planned. Waiting for Nigel's approval and answers to the open questions.

## Notes
- Not in this story: typed player names (with accounts, #4), statistics across games (averages, best round), sharing a result, remembering the calibration between launches (a carry-over that could use the same storage later).
