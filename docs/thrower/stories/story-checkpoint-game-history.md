# Story Checkpoint: Game History

## Story Goal
Finished games of Play are **kept on the phone** and can be looked back at: when, how it was played, each player's rounds and total, who won. Nigel, 2026-10-16: "start on game lengths, then history". Backlog #5 (the last part, apart from typed names). Follows [[story-checkpoint-players-and-targets]] (built; device checks to come) and the game-length choice (3, 5 or 9 rounds, done 2026-10-16).

## Complexity Score
5 (Medium–Large): storage → game wiring → a new screen (3), a new data model (`GameRecord`) (1), a dependency change (`path_provider` made direct; Review Agent) (1).

## Status
IN PROGRESS: Task 3 of 4 complete (2026-10-17), waiting for Nigel's checkpoint. Tasks 1–2 committed (`a276c91`, `d0054ab`). Plan approved 2026-10-16 ("commit this, yes to all, start task 1"): every open question answered as recommended.

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
- **Status:** COMPLETE (2026-10-16); committed (`a276c91`)
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
- **Status:** COMPLETE (2026-10-17); Nigel: "commit this and continue to task 3" (`d0054ab`)
- **Work:** when a `Match` becomes over, its `GameRecord` is added, once. Live test games marked. Not for reset or unfinished games.
- **Verify (on this PC):** a widget test plays a short game to the end and finds it saved once; Live test → Target 1, a 3-round game, is saved as "Live test".
- **Next:** Task 3.
- **What changed:**
  - `lib/providers.dart`: `GameNotifier.onEvent` keeps the game (`_keep`) when an event leaves the match over: a `GameRecord.fromMatch` with the Live test recording's name (`recordingChoiceProvider`), added to `gameHistoryProvider` without waiting. **Once:** the record is made under the time the game finished (`_finishedAt`), so its `id` stays the same; an unchanged game isn't saved again (`_kept`); a last-round knife **falling out after the end** saves the same record again with the new score (replacing it, not a second game). `build` and `newGame` forget both, so a reset half-way keeps nothing. New `clockProvider` (the time now; tests fix it) and `historySaveErrorProvider` (why the last save failed, cleared by the next one that works).
  - `lib/ui/play_screen.dart`, `lib/ui/two_target_play_screen.dart`: a snack bar, "Couldn't save this game to History.", when a save fails; play goes on (acceptance 6).
  - `lib/history/game_history.dart`: a failure to find the app's folder (e.g. no `path_provider` plugin) becomes a `GameHistoryException`, like any other read or write failure.
- **Verified by:** `flutter test`: 573 passed (12 new), `flutter analyze`: no issues. On a phone: nothing to see until Task 3's History screen.
- **Checkpoint saved:** 2026-10-17

### Test Report — 2026-10-17 (Task 2)
- **New:** `test/history/keeping_games_test.dart` (9, through `GameNotifier` with a fake history and a fixed clock: nothing kept while the game is on; a finished game kept once with when it finished; throws and a visit after the end don't keep it again; a last-round knife falling out after the end updates the kept game under its first time; two games after New game; a game reset half-way not kept; a two-target game kept only when both have finished, with the winner; a Live test game kept with its recording's name; a failed save leaves play going on and the reason for Play, cleared by the next save that works). `test/history/memory_game_history.dart` (the fake). `test/ui/play_screen_test.dart`: Play shows the snack bar when a save fails. `test/game/live_replay_test.dart`: on each Live test recording (Target 1 and Target 2), the throws the app finds, played as a 3-round game through Play's notifier, are kept once under the recording's name.
- **Results:** 573 passed, 0 failed.
- **Notes:** no platform, permission or dependency change, so no Review Agent run; the docs for the whole story come in Task 4, as planned.

## Task 3: The History screen
- **Work:** Home → **History**: the list (newest first), a game's rounds, delete one, **Clear history** (asks first), "No games yet", and "Couldn't load the history" if the file fails.
- **Status:** COMPLETE (2026-10-17), awaiting Nigel's checkpoint
- **Verify:** Nigel opens History on his Samsung after a Live test game (no throwing needed).
- **Next:** Task 4.
- **What changed:**
  - `lib/ui/history_screen.dart` (new): `HistoryScreen` loads `gameHistoryProvider` when opened: a list, newest first (`whenText`: "16 Oct, 14:32"; `summaryText`: "2 players, 1 target · 5 rounds · Player 1 wins 61–58", "· Live test: Target 1" for a recording); "No games yet"; "Couldn't load the history" with the reason and **Try again**; **Clear history** in the app bar (only when there are games) asks first ("Clear history?", Cancel / Clear). `GameRecordScreen`: how it was played, the result, each player's total and every round; **Delete** (bin icon, no question asked: one game, on purpose) goes back to the list, which reloads. A failed delete or clear says so in a snack bar.
  - `lib/ui/home_screen.dart`: an outlined **History** button under Play, captioned "Finished games of Play".
- **Verified by:** `flutter test`: 586 passed (13 new), `flutter analyze`: no issues. **On the Samsung:** Home → Live test → Target 1 → Play a 3-round game to the end (about the first minute and a half), back to Home → History.
- **Checkpoint saved:** 2026-10-17

### Test Report — 2026-10-17 (Task 3)
- **New:** `test/ui/history_screen_test.dart` (12: the date text; four list lines, as a table (one player, two players with a winner, a draw on two targets, a Live test game); the list newest first; "No games yet" with no Clear history; a load failure with its reason, then Try again; a game's rounds, totals and winner; Delete goes back to a shorter list; Clear history's Cancel keeps all; Clear confirmed empties it). `test/widget_test.dart`: Home opens History.
- **Found and fixed by the tests:** `_reload`'s `setState` returned the reload's future (a Flutter assertion).
- **Results:** 586 passed, 0 failed.

## Task 4: Instructions, docs, device checks, traceability
- **Work:** the in-app Instructions (History, what's kept and where); Design Decisions, Glossary, Data Flow, System Diagram, web pages; Device Test Plan checks for the next TestFlight build; Review Agent; Traceability Agent; backlog #5.
- **Verify:** Nigel reads the instructions; the checks are ready.

---

## Plan Changes Log
- **2026-10-16:** Planned. Waiting for Nigel's approval and answers to the open questions.
- **2026-10-16:** Approved ("commit this, yes to all, start task 1"). Task 1 done; the file goes in the support folder rather than the documents folder (see Task 1).
- **2026-10-17:** Task 2 done. Added: a game whose last-round knife falls out after the end is saved again with the new score (same record), and Play says so if a save fails.
- **2026-10-17:** Task 3 done. Delete one game asks nothing (only Clear history asks, as planned).

## Notes
- Not in this story: typed player names (with accounts, #4), statistics across games (averages, best round), sharing a result, remembering the calibration between launches (a carry-over that could use the same storage later).
