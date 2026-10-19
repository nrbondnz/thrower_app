# Story Checkpoint: Named Players

## Story Goal
Players can be given names in place of "Player 1" and "Player 2": "Mark wins", not "Player 2 wins". Stage 1 of the [[Accounts Roadmap]], in Nigel's model (2026-10-19): the app user **names players**, who **just have scores** ("they could just as well be player 2"). A name is a label on a seat for a game: no player list, no history of their own, nothing sent anywhere. Friends with their own accounts come in stage 3. Requirement: [[Player Names]].

## Complexity Score
6 (Large):
- layers: scoring (`Match`), history (`GameRecord`), a new store for the names, and the UI (Play, two targets, History, Quick draw) (4);
- a stored-data change (`GameRecord` version 2) (1);
- more than 3 acceptance criteria (1).

## Status
IN PROGRESS: Task 3 of 4 complete (2026-10-19), awaiting Nigel's checkpoint. Tasks 1–2 committed (`9802369`). Plan approved ("commit this and start task 1", `52173fc`).

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
- **Status:** COMPLETE (2026-10-19); committed with Task 2 (`9802369`)
- **What changed:**
  - `lib/scoring/match.dart`: `maxNameLength` (16), `cleanName`, `playerNumber`; `Match.names`, `nameOf`, `withNames`, a `names:` argument (cleaned, one per player); every change keeps the names.
  - `lib/history/game_record.dart`: **version 2**: `names` (written only when someone has one), `nameOf`; version 1 reads with no names; names that aren't one per player are a `FormatException`.
  - `lib/settings/player_names_store.dart` (new edge folder): `PlayerNamesStore`, `FilePlayerNamesStore` (`player_names.json`; never throws on load; safe writes, one at a time).
  - `lib/providers.dart`: `playerNamesStoreProvider`, `playerNamesProvider` (`PlayerNamesNotifier`: two seats, blank at first, then the kept names unless set already; `set` cleans and keeps them, ignoring a failed save); `GameNotifier` names each new game and renames the game in place when the names change; New game keeps them.
- **Verified by:** `flutter test`: 729 passed (25 new), `flutter analyze`: no issues. Nothing to see on the phone until Task 2.
- **Checkpoint saved:** 2026-10-19

#### Test Report — 2026-10-19 (Task 1)
- **New:**
  - `match_test.dart` (6): Player 1 / 2 without names; trimmed, and blank is still Player N; cut to 16; one name per player; renaming keeps the scores and the turn; names stay through throws, turns, corrections and Finish game.
  - `game_record_test.dart` (6): a game keeps its names; saved and read back; none written without names; a version 1 game reads as Player 1 / 2; malformed names rejected; version 2.
  - `game_history_test.dart` (1): a version 1 history still reads, and is rewritten as version 2.
  - `keeping_games_test.dart` (3): a finished game kept with its names; renaming mid-game keeps the scores; New game keeps the names.
  - `test/settings/player_names_test.dart` (9):
    - the file store: nothing kept; kept across a reopen; a damaged file is blank, then replaced; no folder; no temporary file left;
    - the provider: blank, then the kept names; set cleans and saves; names set before loading win; a failed save doesn't stop a rename.
- **Results:** 729 passed, 0 failed.

#### Doc Update — 2026-10-19 (Task 1)
- [[Design Decisions]] → **Named Players** (new: names in the game, `cleanName` and 16 characters, the store, `GameRecord` version 2, privacy); Code Layout (`lib/settings/`); Game History (the format note).
- [[Glossary]]: the named-players components and functions; concept **Named player**.
- Left for Task 4: [[System Diagram]], [[Data Flow]], the web pages, the Instructions.

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
- **Status:** COMPLETE (2026-10-19); Nigel: "commit this and carry on" (`9802369`)
- **What changed:**
  - `lib/ui/play_setup_screen.dart`: "Name(s) (optional)", a field per player (`playName0`, `playName1`; hint "Player N"; at most 16 characters; words capitalised), filled with the kept names unless one has been typed; Start sets them.
  - `lib/ui/play_screen.dart`: `turnText`, `turnDetail` and `playerTitle` use `Match.nameOf`; the correction rows' labels come from `rowLabel`.
  - `lib/ui/two_target_play_screen.dart`: `boardMessage(player, event)`, `boardMovedMessage(player)` and `boardsStateText(states, names)` take names; the rows use `rowLabel`.
  - `lib/ui/score_corrections.dart`: `rowLabel` ("P1", "Jo", "Barth…").
  - `lib/ui/history_screen.dart`: `resultText` ("Sam wins 10–12", "Jo 27") and the players' headings use `GameRecord.nameOf`.
- **Verified by:** `flutter test`: 743 passed (14 new), `flutter analyze`: no issues. **Nigel:** Live test → Play → 2 players, type two names → Start; the turn line, totals and winner use them; then History; then Play again: the names are filled in.
- **Checkpoint saved:** 2026-10-19

#### Test Report — 2026-10-19 (Task 2)
- **New:**
  - `play_setup_screen_test.dart` (6): a field per player with the hint; names typed go to the game and the phone; kept names filled in; a cleared name is Player 1; 16 characters at most; renaming a game in progress keeps its scores.
  - `play_screen_test.dart` (5): whose turn, who's next and the totals; the winner; two targets: wait for Sam; `rowLabel`; the longest names fit Play on a 360 × 740 phone.
  - `history_screen_test.dart` (3): the result names the winner (Player N without); one named player; a game's page headings.
- **Updated:**
  - `two_target_play_screen_test.dart`: the board texts take names ("Sam: Bounced off: 0.", "Sam's board", "Jo: throw seen").
  - Three tests scroll to the setup screen's Start: it's below an 800 × 600 test screen now.
- **Results:** 743 passed, 0 failed.

#### Doc Update — 2026-10-19 (Task 2)
- [[Design Decisions]] → Named Players (what's shown where); [[Glossary]] (the functions that show names).

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
- **Status:** COMPLETE (2026-10-19), awaiting Nigel's checkpoint
- **What changed:**
  - `lib/ui/quick_draw_boards.dart`:
    - `BoardChoosing.playerNames`: the names from `playerNamesProvider`, "Player N" without. Shared with two-target Play, so it also says "Tap the centre of Jo's board".
    - `choosingInstruction` uses the names.
    - **`NamesButton`** and `editPlayerNames`: a dialog (`_NamesDialog`) with a field for each player, the same names as Play. Save keeps them; Cancel changes nothing.
  - `lib/game/quick_draw_judge.dart`: `verdictText(v, names:)`.
  - `lib/ui/live_quick_draw_screen.dart`:
    - `matchText(m, names)`, `QuickDrawResultPanel(names:)` (headline "Sam wins…", the match line "Sam leads 2–0");
    - **Names** shown whenever no round is under way.
    - The per-player lines keep "1:" / "2:", matching the board numbers drawn on the picture.
  - `lib/ui/quick_draw_screen.dart` (the recording): the result line by name; Names before Play.
  - **Bug found by the tests and fixed:** the dialog's fields were disposed while its closing animation still used them. The dialog now owns them.
- **Verified by:** `flutter test`: 748 passed (5 new), `flutter analyze`: no issues. **Nigel:** Live test → Quick draw: **Names**, type two, Save; "Tap the centre of Jo's board"; Play; the result by name.
- **Checkpoint saved:** 2026-10-19

#### Test Report — 2026-10-19 (Task 3)
- **New:**
  - `quick_draw_judge_test.dart` (1): the result line by name, Player N without.
  - `live_quick_draw_screen_test.dart` (4): the boards asked for by name; Names changes them, the same as Play's; Cancel leaves them; the panel names the winner and the match.
  - The duel test also checks that Names is hidden once Start is tapped.
- **Results:** 748 passed, 0 failed.

#### Doc Update — 2026-10-19 (Task 3)
Kept along the chain: requirement → architecture → design decisions (Docs Agent §0).
- **Files updated:**
  - **Requirements:**
    - [[Player Names]]: status ✅ built for named players (device checks to come; friends stage 3); "What Exists Today" rewritten, links to this story, [[Design Decisions]] → Named Players, [[Data Flow]], [[Glossary]].
    - [[Requirements Index]]: Player Names 🗺️ → ✅.
    - [[One Target]], [[Two Targets]], [[Round Play]], [[Game Type]], [[Game Recording]]: the names noted where players are named (and History keeps them); One Target and Two Targets now link down to [[Design Decisions]].
    - [[Scoring Rules]], [[Number of Rounds]], [[Ending Early]]: links down to the 2026-10-17/19 decisions (Score Corrections, KATTA, the Quick draw match, Finish match).
  - **Architecture:**
    - [[System Diagram]]: `PlaySetupScreen` (names); `playerNames` · `NamesButton` → `editPlayerNames` in `quick_draw_boards`; `playerNamesProvider` / `playerNamesStoreProvider`; `Match.names` / `nameOf` / `withNames` in the Play flow; `GameRecord` v2 (names); a new **SETTINGS (lib/settings)** box (`PlayerNamesStore`, `FilePlayerNamesStore`); `path_provider` serves both.
    - [[Data Flow]]: new section **Player Names: Into the Game, History and Quick Draw** (store → `set` → `GameNotifier` / `Match.withNames` → Play, History, Quick draw).
    - [[Glossary]]: Task 3 entries: `BoardChoosing.playerNames`, `NamesButton` / `editPlayerNames` (`_NamesDialog` owns its fields), `verdictText(…, names:)`, `matchText(m, names)`, `QuickDrawResultPanel(…, names:)`; **Named player** concept links up to [[Player Names]].
    - [[Accounts Roadmap]]: stage 1 marked built (Tasks 1–3, device checks to come) in the stage table, the Stage 1 section (open questions answered) and the Changes Log.
    - Web pages: `tool/web_docs/content.py` (the History lane is now "History and settings · lib/history · lib/settings"; new component **PlayerNamesStore**; new flow **Player names: into the game, History and Quick draw**, with a card; names in Screens, Providers, GameSession and Match, judgeQuickDraw, GameHistory, choosing boards, live Quick draw, `path_provider`); `tool/web_docs/build.py` (the PlayerNamesStore box on the overview, under GameHistory). `python tool/web_docs/build.py`: index + 10 flows + 26 components.
  - **Design decisions** ([[Design Decisions]]):
    - Named Players: **Requirement:** [[Player Names]] and the roadmap's Stage 1 linked; **Quick draw (Task 3)** added: no `Match`, so the shared `BoardChoosing.playerNames` getter; texts take names as an argument (`verdictText`, `matchText`, `QuickDrawResultPanel`); the per-player lines keep "1:/2:" to match the board numbers; the Names dialog (Save / Cancel, shown only when no round is under way); the disposed-controller bug, fixed by the dialog owning its fields.
    - Code Layout: `lib/history/` is format version 2 with names; `quick_draw_boards.dart` lists `playerNames`, `NamesButton` / `editPlayerNames`.
    - Single Player First ("Player 1 and Player 2 for now"), Quick Draw: Choosing the Boards, the live duel's panel: notes that players can now be named.
    - Requirement links added up from: Score Corrections ([[Scoring Rules]], [[Round Play]]), Game History ([[Game Recording]], [[Ending Early]]), KATTA ([[Scoring Rules]]), the Quick draw match updates ([[Game Type]], [[Number of Rounds]], [[Ending Early]]), one or two players ([[Game Type]], [[One Target]], [[Two Targets]]).
- **Files created:** none in the vault; `docs/web/components/player-names-store.html`, `docs/web/flows/player-names.html` (generated).
- **Chain audit (drift):**
  - Requirement pages with no design decision behind them: [[Remote Play]], [[Results Sharing]] (only the [[Accounts Roadmap]] stages 4–5), [[Rankings]], [[Competitions and Prizes]] (ideas), [[Subscriptions]] (only the roadmap's open decision and "payments deferred"); [[Game Recording]]'s video half ([[story-checkpoint-record-and-share]], paused, no decision section). Expected for 🗺️ / 💭 items: their design comes when they're planned.
  - Decision with no requirement page above it: the **in-app Instructions** updates (Rounds and Scoring → "In-app Instructions", incl. the 2026-10-19 Quick draw match update). No requirement page covers instructions or safety wording; suggest a Basic Setup/Basic Play page for "Instructions and safety", or accept as cross-cutting.
  - Unrelated drift seen: [[System Diagram]]'s rule "Plugins stay in the camera and sound layers" omits `path_provider` (history and settings); the web pages' `TargetModel` text still says "IKTHOF" (now `TargetModel.katta()`); `targetModelProvider` described as "the IKTHOF rings".
- **Left for Task 4:** `lib/ui/instructions.dart` (naming players), [[Device Test Plan]] checks, [[Mac Handoff]], the backlog.

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
- **Drift fixed after the Docs Agent's report (2026-10-19):** the web pages' `TargetModel` text now says KATTA; [[System Diagram]]'s plugin rule names `path_provider` behind `GameHistory` and `PlayerNamesStore`.
