# Story Checkpoint: Game History

## Story Goal
Finished games of Play are **kept on the phone** and can be looked back at: when, how it was played, each player's rounds and total, who won. Nigel, 2026-10-16: "start on game lengths, then history". Backlog #5 (the last part, apart from typed names). Follows [[story-checkpoint-players-and-targets]] (built; device checks to come) and the game-length choice (3, 5 or 9 rounds, done 2026-10-16).

## Complexity Score
5 (Medium–Large): storage → game wiring → a new screen (3), a new data model (`GameRecord`) (1), a dependency change (`path_provider` made direct; Review Agent) (1).

## Status
IN PROGRESS: Tasks 1–4 complete (2026-10-17); **Task 5 (Finish game) complete, waiting for Nigel's checkpoint**; Task 6 next. Tasks 1–4 committed (`a276c91`, `d0054ab`, `06d608b`, `22da9cc`). **Waiting for the device checks** ([[Device Test Plan]] → History Checks, H0–H5: Nigel on the Samsung for H0–H4, and in TestFlight 1.0.0 (8) with the Players and Targets Checks). Archive the story once they pass. Plan approved 2026-10-16 ("commit this, yes to all, start task 1"): every open question answered as recommended.

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
- **Status:** COMPLETE (2026-10-17); Nigel: "commit this and continue to task 4" (`06d608b`)
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
- **Status:** COMPLETE (2026-10-17), awaiting Nigel's checkpoint
- **Verify:** Nigel reads the instructions; the checks are ready.
- **What changed:**
  - `lib/ui/instructions.dart`: a **History** section after Resetting (kept when a game finishes; Home → History, newest first, tap for every round; Live test games marked; reset or unfinished games not kept; the bin, and Clear history which asks first; stays on this phone, sent nowhere, deleted with the app). Same text for the paper target.
  - Docs: [[Design Decisions]] → Game History (when a game is kept, the History screen; `lib/ui/` row); [[Glossary]] (`_keep`, `clockProvider`, `historySaveErrorProvider`, `HistoryScreen` / `GameRecordScreen` and their text functions; concept **Kept game**); [[Data Flow]] (Play: keeping the game, viewing it); [[System Diagram]] (HistoryScreen, the history providers, a HISTORY box, `path_provider` under native code).
  - Web pages (`tool/web_docs/content.py`, `build.py`, `docs/web/assets/styles.css`; rebuilt): a **History** lane (its own colour and clock icon) with a **GameHistory** component page, a **Keeping and viewing finished games** flow page, History on the Screens and Providers pages, `path_provider` among the plugins.
  - [[Device Test Plan]] → **History Checks** (H0–H5); [[Mac Handoff]] section 000: build 8 now also carries game lengths and history (no Podfile change).
  - **Drift fixed on the way:** "9 rounds" in both diagrams, the Play flow and the GameSession page now say 3, 5 or 9 (stale since game lengths, 2026-10-16).
- **Verified by:** `flutter test`: 587 passed (1 new), `flutter analyze`: no issues; `python tool/web_docs/build.py`: index + 8 flows + 25 components.
- **Checkpoint saved:** 2026-10-17

### Test Report — 2026-10-17 (Task 4)
- **New:** `test/ui/instructions_test.dart`: 'History: finished games only, where to find them, delete and clear, kept on the phone'; the section-order test now has **History** after Resetting (the paper target's sections still match the real board's).
- **Results:** 587 passed, 0 failed.

### Doc Update Log — 2026-10-17 (Tasks 2–4)
- **Updated:** `Architecture/Design Decisions.md`, `Architecture/Glossary.md`, `Architecture/Data Flow.md`, `Architecture/System Diagram.md`, `Operations/Device Test Plan.md`, `Operations/Mac Handoff.md`, `stories/backlog.md` (#5), `CLAUDE.md` and `docs/working-with-nigel.md` (project overview).
- **Created:** `docs/web/components/game-history.html`, `docs/web/flows/game-history.html` (generated).
- **Not changed:** the interactive Thrower Field Test page (as for the M and Q checks, the H checks live in the Device Test Plan and come back in a message).
- **Drift noted, not fixed:** the System Diagram's UI tree doesn't show `PlaySetupScreen` or `TwoTargetPlayScreen` (players-and-targets story).

### Safety Report — 2026-10-17 (Tasks 2–4, Review Agent)
- **Files reviewed:** `lib/providers.dart` (`_keep`), `lib/ui/history_screen.dart`, `lib/ui/home_screen.dart`, both Play screens, `lib/ui/instructions.dart`; `pubspec.yaml`, `AndroidManifest.xml`, `Info.plist` unchanged since Task 1's report.
- ✅ §1 Permissions: none added; the history is in the app's own folder.
- ✅ §2 Parity: Dart only; the same on iOS and Android.
- ✅ §3 Debug/release: no debug-only paths; Live test games are kept like any other, marked with the recording's name (and go with the Live test recordings when backlog #6 removes them from release builds).
- ✅ §4 Secrets: none.
- ✅ §5 Privacy: dates and scores only, no images or names; nothing sent anywhere; the Instructions say so ("stays on this phone… Deleting the app deletes it"). The file is in the phone's own backups (noted in Task 1); no change to the store privacy answers.
- ✅ §6 Size and performance: saving runs without waiting, after the game ends; the History list loads one small file when opened.
- ✅ §7 Physical safety: History is reached from Home, not from Play, so nothing prompts anyone to the phone or the board during a game; the "Couldn't save" snack bar needs no action.
- ✅ §8 Rollback: no stored data migrated; Delete removes one game without asking (one game, on purpose), Clear history asks first.
- **Verdict:** OK to commit.

### Traceability Report — 2026-10-17 (story complete, device checks to come)

| Requirement | Design Reference | Implementation | Test | Status |
|---|---|---|---|---|
| AC1: a finished game is saved: when, mode, rounds, each player's rounds and total, the winner or a draw; Live test games marked | Design Decisions → Game History | `GameRecord.fromMatch`, `totals`, `winner`, `draw`; `GameNotifier._keep` (`recordingChoiceProvider`) | `game_record_test.dart`; `keeping_games_test.dart` ('a finished game is kept…', 'a two-player game is kept when both have finished…', 'a Live test game…'); `live_replay_test.dart` ('a 3-round game played on it is kept…') | ✅ Covered (device: H1) |
| AC2: survives closing and reopening the app | Game History → one file, safe writes | `FileGameHistory` (`game_history.json`, support folder) | `game_history_test.dart` ('found again by a new history on the same folder') | ✅ Covered (device: H3) |
| AC3: Home → History, newest first; a game shows every round of each player | Game History → The History screen | `HomeScreen`, `HistoryScreen`, `GameRecordScreen`, `whenText`, `summaryText` | `history_screen_test.dart` (list order, line texts, a game's rounds); `widget_test.dart` ('home screen opens the History') | ✅ Covered (device: H1–H2) |
| AC4: delete one game; Clear history removes all, after asking | The History screen | `GameRecordScreen._delete`, `_HistoryScreenState._clear` | `history_screen_test.dart` (delete; Clear → Cancel; Clear → Clear) | ✅ Covered (device: H4) |
| AC5: unfinished games not saved; a finished game saved once | When a game is kept | `GameNotifier.onEvent` → `_keep` (`_finishedAt`, `_kept`; reset in `build` / `newGame`) | `keeping_games_test.dart` (nothing while on; reset half-way; throws after the end; knife falling out after the end; two games after New game) | ✅ Covered (device: H5) |
| AC6: a file that can't be read or written doesn't stop Play; History says it couldn't load | Safe writes; When a game is kept | `GameHistoryException`, `historySaveErrorProvider` + Play's snack bar, `HistoryScreen` error + Try again | `game_history_test.dart` (damaged, newer version, unwritable folder); `keeping_games_test.dart` ('if it can't be saved…'); `play_screen_test.dart` ('says when a finished game could not be saved'); `history_screen_test.dart` ('couldn't load… tries again') | ✅ Covered |
| AC7: nothing leaves the phone; no new permission | Game History → Privacy | no network code; app support folder | Review Agent (Tasks 1 and 4); `instructions_test.dart` (History: 'stays on this phone') | ✅ Covered (by review) |

- **Coverage:** 7 of 7 requirements with design, code and tests; device checks H0–H5 to come.
- **Backward:** every new symbol traces to an AC. **Minor:** `GameRecord.liveTest` is used only by tests (the screens read `recording` for the name); harmless, keep for the History filter or statistics that may come later, or drop it then.
- **Stale links:** none; the "9 rounds" drift from the game-length change was fixed in Task 4.

## Task 5: Finish game: the rule, and the button on Play
- **Status:** COMPLETE (2026-10-17), awaiting Nigel's checkpoint. Plan approved: "commit this and go".
- **Asked for:** Nigel, 2026-10-17: "There needs to be a button 'finish game' so games can finish after fewer rounds". Answered: a round in progress **counts** (its throws so far, as collecting early does); with two players the winner is decided on **equal rounds** (the rounds both have played; an extra round is shown and kept but doesn't count).
- **Work:**
  - `GameSession.finish()` / `finished`: `isOver` also when finished. `Match.finish()` finishes every player. `Match.countedRounds` (the fewest rounds any player has played) and the winner / draw on those rounds; a game played to the end is unchanged (both have every round).
  - `GameNotifier.finishGame()`: finishes the match and keeps it in the history (Task 2's `_keep`, once).
  - Both Play screens: **Finish game** beside Reset game, while a game with throws is on. It asks first ("Finish the game now? It ends with the rounds played so far and is kept in History."). Game over then says "Game over after 4 of 9 rounds", and with two players, the result on the counted rounds, an extra round marked "not counted".
  - `GameRecord`: the winner on equal rounds too (the round lists already show how many were played: **no file format change**).
- **Verify:** tests (finish mid-round, after Player 1's turn, on two targets, with no throws: no button). Nigel: Live test → Target 1 → Play, 9 rounds, **Finish game** after round 2 → the result, then History.
- **Next:** Task 6.
- **What changed:**
  - `lib/scoring/game_session.dart`: `finished`, `finish()`, `finishedEarly`; `isOver` is also true once finished (so later throws are ignored, as at the end).
  - `lib/scoring/match.dart`: `finish()`, `finishedEarly`, `countedRounds` (the fewest rounds any player has played), `countedTotals`; `winner` / `draw` on the counted totals (a game played to the end: every round, unchanged).
  - `lib/history/game_record.dart`: `finishedEarly`, `countedRounds`, `countedTotals`; `winner` on equal rounds. JSON unchanged (version 1).
  - `lib/providers.dart`: `GameNotifier.finishGame()` (nothing for a game over or with no throws), kept through `_keep`.
  - `lib/ui/play_screen.dart`: `gameOverText` ("Game over after 2 of 9 rounds!"), `confirmFinishGame` (the shared dialog); `playerTitle` shows the counted total once over, `playerDetail` marks a round "(not counted)", `matchFooter` "Finished early: judged on 1 of 9 rounds."; **Finish game** in the app bar (greyed before the first throw, gone once over). `lib/ui/two_target_play_screen.dart`: the same button.
- **Verified by:** `flutter test`: 605 passed (18 new), `flutter analyze`: no issues.
- **Checkpoint saved:** 2026-10-17

### Test Report — 2026-10-17 (Task 5)
- **New:** `game_session_test.dart` (4: a round in progress counts; throws after finishing ignored; a game already over unchanged; a knife falling out afterwards still 0); `match_test.dart` (6: one player; after Player 1's turn, judged on round 1 (9–3, not 24–3); equal rounds level is a draw; two targets with part-rounds, and a player with none; a full game unchanged; no throws after finishing); `game_record_test.dart` (equal rounds in the record, through JSON); `keeping_games_test.dart` (Finish game keeps once with the part-round; no throws, nothing); `play_screen_test.dart` (5: greyed before a throw; asks, Cancel; Finish → "Game over after 2 of 9 rounds! Final total: 16", New game, button gone; two players' texts and footer).
- **Results:** 605 passed, 0 failed.

## Task 6: Finish game in History, Instructions, docs and checks
- **Work:** History: "4 of 9 rounds" (finished early) in the list and on a game, and the rounds that don't count marked. The Instructions (Finish game, what counts, equal rounds). Design Decisions, Glossary, Data Flow, web pages; Device Test Plan H6–H7; Review Agent; traceability (a new acceptance criterion, AC8).
- **Verify:** Nigel reads the Instructions; the checks are ready.

---

## Plan Changes Log
- **2026-10-16:** Planned. Waiting for Nigel's approval and answers to the open questions.
- **2026-10-16:** Approved ("commit this, yes to all, start task 1"). Task 1 done; the file goes in the support folder rather than the documents folder (see Task 1).
- **2026-10-17:** Task 2 done. Added: a game whose last-round knife falls out after the end is saved again with the new score (same record), and Play says so if a save fails.
- **2026-10-17:** Task 3 done. Delete one game asks nothing (only Clear history asks, as planned).
- **2026-10-17:** Task 4 done; story BUILT, waiting for H0–H5. History ships in TestFlight build 8 with players and targets.
- **2026-10-17:** Scope change (Nigel): a **Finish game** button, so a game can end after fewer rounds. Planned as Tasks 5–6; the story goes back to IN PROGRESS. Answered: a round in progress counts; two players are judged on equal rounds.

## Notes
- Not in this story: typed player names (with accounts, #4), statistics across games (averages, best round), sharing a result, remembering the calibration between launches (a carry-over that could use the same storage later).
