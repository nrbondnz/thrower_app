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
BUILT (2026-10-20): Tasks 1–3 complete; device checks GT0–GT9 to come ([[Device Test Plan]]). Plan approved 2026-10-20 ("ok, go"); run whole, committing per task ([[dont-ask-again]]).

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
  - `GameRecord` **version 3**: `type`, written only for the new types (a Scoring game is written as version 2 wrote it); missing reads as Scoring; an unknown type is a `FormatException` (a newer app's game: in the History file it sets the whole file aside, as a newer file version does; the backup skips that one game). *Corrected after the Traceability review:* an **older** app reads a version-3 game as Scoring (it ignores `type`); see Task 3's fixes and [[Known Issues]].
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
- **Status:** COMPLETE (2026-10-20); device checks GT0–GT9 to come
- **What changed:**
  - `lib/ui/history_screen.dart`: `howText` leads with the game ("Precision · 2 players, taking turns · 7 rounds"); `historyRoundLabel` gives Precision's rounds their distance ("Round 2 (5 m)").
  - `lib/ui/instructions.dart`: a section, **Precision and Three targets** (choosing them, the distances, one knife at each target, turns, the score pad, scoring only when no one is throwing and never from the lane).
  - Docs: the Docs Agent's update below; the Traceability review and its fixes below.
- **Tests:** `history_screen_test` (+5), `instructions_test` (+2, and the section order).
- **Verified by:** `flutter test`: 857, then 861 with the fixes; `flutter analyze`: no issues. Installed on the Samsung (`adb install -r`, data kept).

#### Traceability Report — 2026-10-20 (Traceability Agent)
- **Coverage:** 7 requirements; R1 (Precision), R2 (Three targets), R3 (turns, KATTA, winner), R5 (Which game?), R7 (Instructions and safety) covered by code and tests; R4 (hand-scored) and R6 (History and backup) had gaps, fixed or recorded below. No orphan code.
- **Gaps and what was done (commit `1ddedde`):**
  1. **Bug:** Live test → **Play on two targets** didn't reset the game type, so after a Precision game the camera game was scored as Precision and kept without its recording. **Fixed:** it chooses Scoring (`live_test_screen.dart`); test "Play on two targets after a Precision game plays Scoring, on the recording".
  2. **Older app versions:** (a) the History file was written as version 3 even with only Scoring games, which an older build sets aside whole. **Fixed:** `FileGameHistory._versionFor` writes version 2 until a Precision or Three targets game is kept; two tests. (b) an older app reads a backed-up Precision or Three targets game as Scoring (it ignores `type`). **Recorded** in [[Known Issues]]; minor while there are only test builds.
  3. The add-a-throw popup said "the camera missed" on the score pad. **Fixed:** `addThrowTitle` ("Add a throw (0: missed the board)"); test.
  4. After a hand-scored game for two, the next Scoring setup shows "1 target" (the mode was `sharedTarget`). **Accepted** for now: one tap to change.
  5. Two top-level `roundLabel` functions (History's and Quick draw's). **Fixed:** History's is `historyRoundLabel`.
- **Edge cases checked, no bug:** the next distance and target as the turn passes; corrections on the pad; Finish game with uneven rounds; Live test → Play → Precision (no recording kept); a length other than 7 can't reach Precision.

### Doc Update — 2026-10-20

#### Files Updated
- `requirements/Basic Setup/Game Type.md`: what's wanted (Precision, Three targets, the marathon); what exists (the score pad, distances, History); open questions (the distances, the marathon, the camera, the real name → backlog #16–#18)
- `requirements/Basic Setup/Number of Rounds.md`: each type's lengths (Precision 7; Three targets 3, 5 or 7); the marathon
- `requirements/Basic Play/Round Play.md`: Precision and Three targets are rounds of 3, scored by hand
- `requirements/Instructions and Safety.md`: the new Instructions section and the score pad's safety line
- `requirements/Requirements Index.md`: Game Type's line names the four games
- `Architecture/Design Decisions.md`: new section **More Game Types: Precision and Three Targets (2026-10-20)** (scored by hand first; the type changes only where knives go, `Match`/`GameSession` reused; record version 3 with `type` only for the new types, and the file's header version 2 while all games are Scoring; never Live test; Live test → two targets chooses Scoring; not-chosen alternatives); Game History's format line mentions version 3
- `Architecture/System Diagram.md`: `ScorePadScreen`, "Which game?", `gameTypeProvider`, `GameType` in the scoring box, `GameRecord` v3; a paragraph on the score pad skipping the camera layers
- `Architecture/Data Flow.md`: new section **Precision and Three Targets: the Score Pad** (setup → `Match(type)` → score pad → History)
- `Architecture/Glossary.md`: components `GameType`, `ScorePadScreen` / `ScorePad`; Which game? on the setup entry; `GameRecord` version 3; `howText` / `historyRoundLabel`; concepts **Game type**, **Precision**, **Three targets**, **Score pad (hand-scored game)**
- `tool/web_docs/content.py` → `docs/web/` rebuilt (12 flows, 26 components): new flow page `flows/score-pad.html`; Screens, Providers, GameSession and Match, GameHistory updated
- `Operations/Device Test Plan.md`: **Game Type Checks** GT0–GT9 (Samsung, no board needed)
- `stories/backlog.md`: #16 Precision marathon, #17 the camera for both games, #18 confirm the distances and the name; #5 notes the story
- `CLAUDE.md`, `docs/working-with-nigel.md`: the story in the overview (built 2026-10-20, device checks to come)

#### Files Created
- `docs/web/flows/score-pad.html` (generated)

#### Drift Items (logged, not fixed)
- `lib/ui/score_pad_screen.dart`: the `ScorePadScreen` doc comment says the screen shows "From 5 m" / "At target 2"; the code shows "Round 2 of 7: from 5 m" / "Round 1 of 3: at target 2" (`padWhere`).
- **Precision's distances aren't stored in kept games:** History reads them from `precisionDistances` (`historyRoundLabel`), so confirming different distances (backlog #18) would relabel games already kept. Noted on #18.
- **Older apps and the backup:** a backup row has no version, so an older app ignores `type` and would show a Precision or Three targets game from the backup as a Scoring game (Design Decisions → More Game Types). Minor while there are only test builds.
- `Data Flow.md` → Player Names still says "GameRecord … (version 2)" and System Diagram's scoring box "3, 5 or 9 rounds": both true of Scoring, left as they were.

---

## Plan Changes Log
- (none yet)
