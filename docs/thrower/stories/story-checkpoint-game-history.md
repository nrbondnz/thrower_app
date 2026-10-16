# Story Checkpoint: Game History

## Story Goal
Finished games of Play are **kept on the phone** and can be looked back at: when, how it was played, each player's rounds and total, who won. Nigel, 2026-10-16: "start on game lengths, then history". Backlog #5 (the last part, apart from typed names). Follows [[story-checkpoint-players-and-targets]] (built; device checks to come) and the game-length choice (3, 5 or 9 rounds, done 2026-10-16).

## Complexity Score
5 (Medium–Large): storage → game wiring → a new screen (3), a new data model (`GameRecord`) (1), a dependency change (`path_provider` made direct; Review Agent) (1).

## Status
IN PROGRESS: Task 1 of 4 complete (2026-10-16), waiting for Nigel's checkpoint. Plan approved 2026-10-16 ("commit this, yes to all, start task 1"): every open question answered as recommended.

## What Exists (checked 2026-10-16)
- `Match` (`lib/scoring/match.dart`): each player's `GameSession` (rounds, throws, totals), `mode`, `maxRounds`, `isOver`, `winner`, `draw`. Everything a record needs is there when a game ends.
- Nothing is saved between app launches today (the calibration and the game live only for the session).
- **`path_provider` is already in the app**, pulled in by `audioplayers` (`pubspec.lock`). Listing it in `pubspec.yaml` adds no new native code, permission or size.

## Questions (answered 2026-10-16: "yes to all", as recommended)
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
- **Status:** COMPLETE (2026-10-16), awaiting Nigel's checkpoint
- **Work:**
  - `GameRecord` (pure Dart): when, mode, rounds, Live test or not, each player's round totals, total, winner / draw; `toJson` / `fromJson` (with a version number, so the format can change later).
  - `GameHistory` (interface): `load`, `add`, `delete`, `clear`. `FileGameHistory`: one JSON file in the app's documents folder (`path_provider`, made a direct dependency: **Review Agent**). A damaged file is set aside, not lost or crashed on.
  - `gameHistoryProvider`; tests use a temporary folder or a fake.
- **Verify:** tests (save, reload, delete, clear, a damaged file).
- **Next:** Task 2.
- **What changed:**
  - `lib/history/game_record.dart` (new): `GameRecord` (`id`, `finishedAt`, `mode`, `rounds`, `players`, `recording`; `fromMatch`, `totals`, `winner`, `draw`, `liveTest`, `toJson`, `fromJson`, `version` 1).
  - `lib/history/game_history.dart` (new): `GameHistory` (interface), `FileGameHistory` (one JSON file; saves through a `.tmp` file, one at a time; a damaged or newer-version file renamed `….damaged-<time>` and the history started afresh), `GameHistoryException` (`setAside`).
  - `lib/providers.dart`: `gameHistoryProvider` (`FileGameHistory(getApplicationSupportDirectory)`).
  - `pubspec.yaml`: `path_provider: ^2.1.6` (already in the app via `audioplayers`); `pubspec.lock`: only "transitive" → "direct main".
  - **Plan change:** the app's **support** folder, not its documents folder (both private to the app; support is for app data and isn't shown in the Files app).
- **Verified by:** `flutter test`: 561 passed (22 new), `flutter analyze`: no issues. Nothing to see on a phone yet (Tasks 2–3).
- **Checkpoint saved:** 2026-10-16

### Test Report — 2026-10-16 (Task 1)
- **New:** `test/history/game_record_test.dart` (12: from a finished match; a Live test game; one player / a draw; JSON both ways through text; no `recording` for the camera; six kinds of unreadable JSON); `test/history/game_history_test.dart` (10, on a temporary folder: empty with no file; newest first; found again by a new history on the same folder (the app reopened); the same game kept once; delete and clear; ten saves at once all land; no temporary file left; a damaged file set aside under another name, and a new game starting afresh; a newer version's file set aside; a folder that can't be written says so).
- **Results:** 561 passed, 0 failed.

### Safety Report — 2026-10-16 (Task 1, Review Agent: `pubspec.yaml`)
- **Files reviewed:** `pubspec.yaml`, `pubspec.lock`, `lib/history/*`, `lib/providers.dart`; `AndroidManifest.xml` and `Info.plist` checked, unchanged.
- ✅ §1 Permissions: none needed (the app's own folder); none added.
- ✅ §2 Parity: `path_provider` covers iOS and Android (and was already built into both through `audioplayers`); no `Podfile`, Gradle or `ios/` / `android/` change.
- ✅ §3 Debug/release: no debug-only paths.
- ✅ §4 Secrets: none.
- ✅ §5 Privacy: games (dates, scores, the mode) stay in the app's own support folder; nothing is sent anywhere. **Noted:** like all app data, the file is in the phone's own backups (iCloud; Android's auto-backup, `allowBackup` not set, so on) and is deleted with the app. No change to the store privacy answers (nothing is collected by the developer).
- ✅ §6 Size: no new native code or assets; each game is well under 1 KB.
- ✅ §7 Physical safety: not affected.
- ✅ §8 Rollback: a new file only; removing the feature leaves an unused file, nothing else.
- **Verdict:** OK to commit.

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
- **2026-10-16:** Approved ("commit this, yes to all, start task 1"). Task 1 done; the file goes in the support folder rather than the documents folder (see Task 1).

## Notes
- Not in this story: typed player names (with accounts, #4), statistics across games (averages, best round), sharing a result, remembering the calibration between launches (a carry-over that could use the same storage later).
