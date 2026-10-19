# Story Checkpoint: Quick Draw Match (KATTA Rules)

## Story Goal
Quick draw follows the rules Nigel's brother plays to (Nigel, 2026-10-19): **"The quick draw is always three rounds, first to stick in target wins, bounce outs lose, if the times are the same then score is the decider if possible, if the same score the round is a draw."** It also names the scoring the app already uses as **KATTA** ("scoring method is KATTA which is prevalent in the UK"). Follows [[story-checkpoint-live-quick-draw]] (one duel at a time, Next duel) and [[story-checkpoint-quick-draw]] (archived). It comes before [[Accounts Roadmap]] stage 1 (Nigel, 2026-10-19).

## Complexity Score
4 (Large): rules (pure Dart) → the live Quick draw screen → instructions (3 layers), and branches: the score tie-break, extra rounds, finishing early (1).

## Status
BUILT: all 3 tasks complete (2026-10-19); Tasks 1–2 committed (`d6809c0`, `0c25782`). **Waiting for the device checks** ([[Device Test Plan]] → Quick Draw Match Checks, QM0–QM6: Nigel's brother, on TestFlight 1.0.0 (9); [[Mac Handoff]] section 0000). Archive the story once they pass.

## Research (2026-10-19)
- **KATTA UK** (knifethrowing.co.uk; its *Guide to different Targets*, from the club files on ebthrowers.co.uk) uses the **European target face**: a 50 cm circle of 5 concentric rings, **10 / 20 / 30 / 40 / 50 cm** across, scoring **5 / 4 / 3 / 2 / 1**. The guide says it is "practically the same" as the IKTHOF target (octagons of the same sizes, about 1% larger). The European rules (eurothrowers.org) say "The best ring that is cut will be counted", which is the **higher** score on a line. A throw counts only if the tip **sticks**.
  - **So scoring doesn't change:** `TargetModel.ikthof()` already has these rings and `LineTouchRule.higher`. Nigel's 75–85 cm boards are larger, but scoring works on proportions (`TargetMapping`), so that doesn't matter. This story only renames IKTHOF to KATTA in the code, the Instructions and the docs.
- **The European Duel Cup** (eurothrowers.org/duel-cup) matches the brother's rule:
  - "A duel consists of 3 runs. He who wins the most runs wins the duel."
  - "The winner of the run is the thrower whose knife sticks in the target first. If the two knives hit at the same time, the thrower whose knife sticks closer to the target centre is the winner." The same time means within 10 ms.
  - A 1:1 tie in runs: "there will be more runs until one thrower wins a run".
  - A first false start gets a warning; a second loses the run.

## Answered (2026-10-19)
1. **Three rounds,** "all three but with the option to finish early". All three are thrown by default, so each player gets the same throws even at 2–0. A **Finish match** button ends the match early, as Finish game does for Play.
2. **Level after three rounds:** **extra rounds until one is won**, as in the Duel Cup. A match played to the end always has a winner.
3. **Order:** this story first, then Accounts stage 1.

## Decisions Taken Without Asking (say if wrong)
- **"The same time" is the same camera frame** (about 17 ms at 60 fps), as today. That's the finest the camera can tell apart; the Duel Cup's 10 ms needs a timing device.
- **Score tie-break "if possible":** if both knives stuck on the same frame, the higher score wins the round. If the scores are equal, **or either score is unknown** (entry not found, shown as "?"), the round is drawn.
- **Bounce-outs:** a bounce-out loses the round to a knife that sticks. Both bouncing, or no throws, is a drawn round (no one stuck first).
- **False start:** still loses the round, as now. The Duel Cup gives a warning first; that can be added if wanted.
- **Finish match:** available once at least one round is judged, and decided on the rounds won so far. **Level when finished early is a draw:** the players chose to stop, so no extra rounds are forced.
- **The recorded Quick draw** (Live test → Quick draw) has one duel in its clip, so it stays a single round, judged with the new round rule (the score tie-break). The match is for the live Quick draw.

## Acceptance Criteria
1. A round: the first knife to stick wins; a bounce-out or false start loses; both stuck on the same frame → the higher score wins; the same score, or an unknown score → a drawn round; neither stuck → a drawn round.
2. The live Quick draw is a **match of three rounds**. Each round's result is shown, along with the match score (e.g. "Round 2 of 3 · Player 1 leads 1–0"), and **Next round** keeps the boards.
3. After three rounds the player who won more rounds wins the match. If level, **extra rounds** are played ("Extra round"), one at a time, until one is won.
4. **Finish match** ends the match after any round. It's decided on rounds won so far, and level is a draw. **New match** starts again with the same boards.
5. The match result is in **large type, readable from the throwing line**, with the chime (Review Agent, 2026-10-15). Nobody needs to walk to the phone to read it.
6. The scoring is named **KATTA** in the app (`TargetModel.katta`, the Instructions) and the docs; the scores themselves are unchanged.
7. The Instructions explain the match: three rounds, the round rule with the tie-break, extra rounds, Finish match. The safety points stay (the phone behind the throwers, collect the knives together between rounds).

## Story Plan

### Task 1: The rules: a round's tie-break, the match, KATTA
- **Setup:** `judgeQuickDraw` (`lib/game/quick_draw_judge.dart`) judges one duel; a same-frame finish is a draw.
- **Work:**
  - `judgeQuickDraw`: both stuck on the same frame → the higher score wins; equal or unknown → drawn. The verdict says why (`byScore`), for the result text.
  - A pure-Dart **`QuickDrawMatch`** (in `lib/scoring/`, beside `Match`):
    - `rounds` (each round's verdict), `add(verdict)`, `roundsWon`, `roundNumber`, `isExtraRound`;
    - `isOver` (3 rounds played and not level, or an extra round won, or finished), `finish()`;
    - `winner` / `draw`.
  - `TargetModel.ikthof()` renamed **`TargetModel.katta()`**, with a doc comment that it's the same as the IKTHOF and European faces.
- **Verify:** tests: a table of round cases (stick vs bounce, same frame with higher, equal or unknown scores, false starts, no throws); matches (2–1; 2–0 then the third thrown; 1–1 with a drawn round → an extra round; drawn extra rounds go on; finished early level → draw; finished early 1–0 → winner). `flutter test` all pass. Nothing new on the phone yet, except the result text naming a score win.
- **Next:** Task 2.
- **Status:** COMPLETE (2026-10-19); Nigel: "commit this and continue to task 2" (`d6809c0`)
- **What changed:**
  - `lib/game/quick_draw_judge.dart`: on the same frame the higher score wins (`QuickDrawVerdict.byScore`); the same score or a score not found (`null`) is a draw. `verdictText`: "Player 2 wins on score: …"; a draw now says "…on the same frame with the same score."
  - `lib/scoring/quick_draw_match.dart` (new): `QuickDrawMatch` (`rounds` = 3, `results`: each round's winner or null; `add`, `finish`; `wins`, `leader`, `roundNumber`, `isExtraRound`, `isOver`, `winner`, `draw`, `scoreText`). Pure Dart: it takes a round's winner, not the `QuickDrawVerdict`, so `lib/scoring/` doesn't depend on `lib/game/`.
  - `TargetModel.ikthof()` → **`TargetModel.katta()`** (`lib/providers.dart`, the tests, `tool/locate_target.dart`, `tool/printable_target.dart`, `tool/reference_board.dart`); doc comments name KATTA, the same rings as IKTHOF. Scores unchanged.
- **Verified by:** `flutter test`: 689 passed (22 new), `flutter analyze`: no issues. Nothing new on the phone: the recorded clip has no same-frame finish, so its result is unchanged. The match appears in Task 2.
- **Checkpoint saved:** 2026-10-19

#### Test Report — 2026-10-19 (Task 1)
- **New:** `test/scoring/quick_draw_match_test.dart` (17: a table of 9 matches (2–1; 2–0 not over, the third thrown; 3–0; 1–1 plus a drawn round, level; three drawn rounds; an extra round won; a drawn extra round goes on; 1–0 and two draws); the round number and extra rounds; nothing added once over; wins, score and leader; finishing early (ahead wins; level is a draw; level in extra rounds; not before the first round; nothing added after)). `quick_draw_judge_test.dart` (5: the same frame, the higher score wins, either player; one score not found, a draw; a bounce-out on the same frame still loses; "wins on score" in the result line).
- **Updated:** the judge's same-frame draw cases and the live screen's draw test now use equal scores; `TargetModel.katta` everywhere.
- **Results:** 689 passed, 0 failed.

#### Doc Update — 2026-10-19 (Task 1)
- [[Design Decisions]] → Quick Draw: Go, False Starts and the Winner (an update: the score tie-break, the three-round match, extra rounds, finishing early, the Duel Cup); → Throwing Sport (KATTA UK in the table; the rename).
- [[Glossary]]: `QuickDrawMatch`; `QuickDrawVerdict.byScore`.
- [[Common Tasks]] and the web pages (`tool/web_docs/content.py`, rebuilt): `TargetModel.katta()`.
- The rest (Instructions, the Quick draw concept, flows, device checks) comes in Task 3.

### Task 2: The live Quick draw as a three-round match
- **Setup:** Task 1.
- **Work:** `LiveQuickDrawScreen` keeps a `QuickDrawMatch`.
  - The result panel shows the round's result and the match score: "Round 1 of 3: Player 2 wins (stuck 4, 0.82 s)" and "Player 2 leads 1–0".
  - **Next round** replaces Next duel, then **Extra round** when level after three. **Finish match** sits beside it (with a confirm, as Finish game has).
  - At the end, the **match result** is in large type ("Player 2 wins the match 2–1" / "A draw"), with the chime, followed by **New match**.
  - The recorded Quick draw shows the round rule's result (its single round).
- **Verify:** widget tests: three rounds to a winner; an extra round when level; Finish match. **Nigel:** Live test → Quick draw shows the new round result. The live match needs the camera: device checks for Nigel's brother (Task 3).
- **Next:** Task 3.
- **Status:** COMPLETE (2026-10-19); Nigel: "commit this and continue to task 3" (`0c25782`)
- **What changed:**
  - `lib/ui/live_quick_draw_screen.dart`: the screen keeps a `QuickDrawMatch` (`_match`); each result adds the round's winner (a round ended with Stop doesn't count).
    - **Buttons:** after a round, **Next round**, or **Extra round** when level after three (`quickDrawNextRound`), plus **Finish match** (`quickDrawFinishMatch`; also between rounds, never before the first). `confirmFinishMatch` asks: "Finish the match now? It ends on the rounds won so far; if they are level, it is a draw." At the end, **New match** (`quickDrawNewMatch`): no rounds won, boards kept. Start is hidden once the match is over.
    - **The line between rounds:** "Round 2 of 3 (Player 1 leads 1–0). Throwers ready? Tap Start: …"; "Extra round (Level 1–1). …".
    - **`QuickDrawResultPanel(verdict, match)`:**
      - "Round 2 of 3" / "Extra round" (`roundLabel`, 24 pt);
      - the headline (52 pt; "Player 2 wins on score");
      - each player's line (34 pt);
      - the match (`matchText`, 34 pt): "Player 2 leads 1–0" / "Level 1–1"; at the end, "Player 2 wins the match 2–1" / "Match drawn 1–1", green at 44 pt (the leader's wins first).
      - With no verdict (finished between rounds), only the match result.
      - It wraps to the screen's width and scales down if still too tall: the longest panel overflowed by 138 px on an upright phone before this.
    - **Choose boards again** keeps the match; leaving ends it.
  - `lib/ui/instructions.dart`: "…then tap Next round." (the button's new name; the full match text is Task 3).
- **Verified by:** `flutter test`: 701 passed (12 new), `flutter analyze`: no issues. **Not seen on a phone:** the live screen needs two boards and the live camera. Live test → Quick draw (the recording) is unchanged: one duel, judged by the new round rule.
- **Checkpoint saved:** 2026-10-19

#### Test Report — 2026-10-19 (Task 2)
- **New** (`test/ui/live_quick_draw_screen_test.dart`, through the screen with rounds of no throws):
  - the result names the round (Round 1 of 3) and the match (Level 0–0), with Next round;
  - Next round shows Start and the line "Round 2 of 3 (Level 0–0)…";
  - level after three rounds → Extra round, and the line "Extra round (Level 0–0)…";
  - Finish match: not before the first round; asks; "Match drawn 0–0", no Next round or Start; New match starts again;
  - Finish match between rounds shows only the match result;
  - Cancel keeps the match going.
- **New** (the panel): "wins on score"; the match so far (Round 2 of 3, Level 1–1); the leader's wins first; the match result green at ≥ 40 pt; an extra round; fits a phone upright (390 × 844) and sideways (844 × 390) with the longest lines.
- **Updated:** Next duel → Next round; the panel takes the match; `instructions_test.dart` ("then tap Next round.").
- **Results:** 701 passed, 0 failed.

#### Doc Update — 2026-10-19 (Task 2)
- [[Design Decisions]] → Quick Draw: the Live Duel (an update: the match, the panel, the buttons, fitting any way up, Choose boards again keeps the match).
- [[Glossary]] → `LiveQuickDrawScreen` (`_match`, `_nextRound`, `confirmFinishMatch`, `roundLabel`, `matchText`, `QuickDrawResultPanel`).
- [[Data Flow]] → the live Quick draw (the match after the result).
- Web pages: the live Quick draw flow (rebuilt).
- **Left for Task 3:** the Instructions' match text; [[Device Test Plan]] Q6 (still says Next duel) and new match checks; [[Common Tasks]]' button list; [[Mac Handoff]]. **Drift:** [[Data Flow]] still calls the panel `_Result`; it's `QuickDrawResultPanel`.

### Task 3: Instructions, docs, device checks, traceability
- **Setup:** Task 2.
- **Work:**
  - `lib/ui/instructions.dart`: the Quick draw section describes the match (three rounds, the round rule and the tie-break, extra rounds, Finish match, collect the knives together between rounds); Scoring names KATTA.
  - Docs:
    - [[Design Decisions]] → Throwing Sport (KATTA and the research), Quick Draw (the match rules)
    - [[Glossary]] (`QuickDrawMatch`, concepts: round, extra round)
    - web pages: the Quick draw flows, `TargetModel`
    - [[Device Test Plan]]: new Quick draw match checks
    - [[Mac Handoff]] section 000 (build 8 carries the match, if it's not built yet)
    - backlog #9
  - The Review Agent (§7: more rounds means more trips to collect knives; the instructions still say collect together, when both have thrown).
  - The Traceability Agent's report.
- **Verify:** Nigel reads the Instructions; `flutter test`; the checks are ready for the brother.
- **Status:** COMPLETE (2026-10-19), awaiting Nigel's checkpoint
- **What changed:**
  - `lib/ui/instructions.dart`:
    - **Quick draw:** "A match is three rounds…" (the round rule with the score tie-break); "All three rounds are thrown, even when one thrower has already won two… extra rounds… until one is won"; "To end a match early, the starter taps Finish match…"; the result "with the match so far… No one needs to go to the phone during a round"; "Between rounds, collect your knives together; then the starter taps Next round."
    - **Scoring:** "This is KATTA scoring (the UK's Knife Axe and Tomahawk Throwing Association), the same as on the European and IKTHOF competition targets."
  - Docs:
    - [[Device Test Plan]] → **Quick Draw Match Checks** (QM0–QM6), and Q6 (Next round from build 9)
    - [[Mac Handoff]] → section **0000** (build 1.0.0 (9): what's in it, add it to External testers)
    - [[Glossary]] (concepts **Quick draw match**, **KATTA scoring**; Line-touch rule names KATTA)
    - [[Design Decisions]] (Instructions update)
    - [[Common Tasks]] (button names)
    - web pages: the `judgeQuickDraw and QuickDrawMatch` component, both Quick draw flows (rebuilt)
    - backlog #9; `CLAUDE.md` and `working-with-nigel.md` (project overview, and the Accounts Roadmap)
- **Verified by:** `flutter test`: 704 passed (3 new), `flutter analyze`: no issues.
- **Checkpoint saved:** 2026-10-19

#### Test Report — 2026-10-19 (Task 3)
- **New:** `instructions_test.dart` (3: the match and the round rule with the tie-break; all three thrown, extra rounds, Finish match by the starter; KATTA named).
- **Updated:** the Quick draw rule and result wording; "then the starter taps Next round."
- **Results:** 704 passed, 0 failed.
- **Note:** `dart format` (the installed formatter's style) reflows untouched code around an edit. Tasks 1–2 committed some of that reflow in `quick_draw_judge.dart`, `target_model.dart`, `live_quick_draw_screen.dart` and their tests (layout only, no behaviour). In Task 3 it was undone, so `instructions.dart` and its test change only where edited.

#### Safety Report — 2026-10-19 (whole story, Review Agent)
- **Files reviewed:** `lib/ui/live_quick_draw_screen.dart`, `lib/ui/instructions.dart`, `lib/game/quick_draw_judge.dart`, `lib/scoring/quick_draw_match.dart`. `pubspec.yaml`, `AndroidManifest.xml` and `Info.plist` are unchanged.
- ✅ §1–§2: no permission, plugin or platform change; Dart only, both platforms alike.
- ✅ §3: no debug-only paths added (the debug watch line is unchanged).
- ✅ §4–§5: nothing stored or sent; the match lives only on the screen.
- ✅ §6: no new processing: one judgement a round, as before.
- ⚠️→✅ **§7 Physical safety:**
  - **More rounds mean more trips to the boards.** The Instructions say: collect the knives **together** between rounds, then **the starter** taps Next round.
  - The existing points stay: go never means the lanes are clear, nobody goes forward until both have finished and agree, and throwers be at their line before Start.
  - **Nothing on screen calls anyone forward:** Next round only readies Start; Start still needs the starter.
  - **Next round and Finish match are tapped by the starter, who already stands at the phone behind the throwers,** so no one walks to the phone during a round. The Instructions name the starter for both.
  - **Readability:** at the end of a round, the panel now carries the round, the winner, both lines and the match. On an upright phone it may scale down to fit, so it could be less readable from 4 m. QM5 asks him. If it is, the fix is to show the match line in place of the per-player lines, not to send anyone to the phone.
  - **Residual:** extra rounds can lengthen a session (heat: Q7 already asks).
- ✅ §8: no stored data or identity change; rolls back cleanly.
- **Verdict:** OK to commit. QM5 is the open question.

#### Traceability Report — 2026-10-19 (story complete, device checks to come)

| Requirement | Design Reference | Implementation | Test | Status |
|---|---|---|---|---|
| AC1: a round's rule: first to stick; bounce-out and false start lose; same frame → higher score; same or unknown score → drawn; none stuck → drawn | Design Decisions → Quick Draw: Go, False Starts and the Winner (update 2026-10-19) | `judgeQuickDraw` (`byScore`), `verdictText`, `QuickDrawResultPanel.headline` | `quick_draw_judge_test.dart` (table, incl. 4 same-frame cases; "wins on score"); `live_quick_draw_screen_test.dart` ('a win on score says so', 'a draw') | ✅ Covered (device: QM0, QM6) |
| AC2: the live Quick draw is a three-round match; the round and match score shown; Next round keeps the boards | Quick Draw: the Live Duel (update 2026-10-19) | `QuickDrawMatch`, `LiveQuickDrawScreen._match` / `_nextRound`, `roundLabel`, `matchText`, `_line` | `quick_draw_match_test.dart`; `live_quick_draw_screen_test.dart` (the round and match; Next round's line) | ✅ Covered (device: QM0–QM1) |
| AC3: more rounds won wins; level after three → extra rounds until one is won; all three thrown at 2–0 | as AC2 | `QuickDrawMatch.isOver` / `isExtraRound` / `winner`; the Extra round button | `quick_draw_match_test.dart` (2–0 not over; drawn extra rounds go on); `live_quick_draw_screen_test.dart` ('level after three rounds: an extra round') | ✅ Covered (device: QM2–QM3) |
| AC4: Finish match after any round, asking; decided on rounds so far, level a draw; New match | as AC2 | `QuickDrawMatch.finish`, `confirmFinishMatch`, `_finishMatch`, `_newMatch` | `quick_draw_match_test.dart` (finishing early ×5); `live_quick_draw_screen_test.dart` (Finish asks; between rounds; Cancel; New match) | ✅ Covered (device: QM4) |
| AC5: the match result in large type, readable from the throwing line, with the chime | Quick Draw: the Live Duel; Review Agent 2026-10-15 | `QuickDrawResultPanel` (44 pt green match line; fits by scaling); `SignalSounds.result` on each round | `live_quick_draw_screen_test.dart` ('the match result, large and green' ≥ 40 pt; fits upright and sideways; the chime on a result) | ✅ Covered (device: QM5, the open question) |
| AC6: KATTA named; scores unchanged | Design Decisions → Throwing Sport (update 2026-10-19) | `TargetModel.katta`; Instructions → Scoring | `target_model_test.dart` (unchanged cases, renamed); `instructions_test.dart` ('names KATTA scoring') | ✅ Covered |
| AC7: the Instructions explain the match; safety points kept | Design Decisions → In-app Instructions (update) | `instructionSections` → Quick draw | `instructions_test.dart` (3 new; the earlier safety tests still pass) | ✅ Covered (and the Safety Report) |

- **Coverage:** 7 of 7 have design, code and tests; device checks QM0–QM6 are to come.
- **Backward:** every new symbol traces to an AC. `QuickDrawMatch.leader` and `scoreText` serve `matchText` (AC2). `byScore` serves AC1's wording.
- **Decisions taken without asking** (listed under the plan) are covered by tests. Nigel hasn't questioned them; they stay open to change.
- **Stale links:** the recorded Quick draw (`QuickDrawScreen`) is one round, by design (one duel in the clip); its Q1 result is unchanged. [[Data Flow]] still calls the panel `_Result` (drift, logged in Task 2).

---

## Plan Changes Log
- **2026-10-19:** Planned from the brother's feedback (via Nigel); three questions answered (all three rounds with Finish match; extra rounds when level; this story before accounts).
- **2026-10-19:** All 3 tasks done; story BUILT, waiting for QM0–QM6 in build 9. Task 2 found the longest result panel overflowed an upright phone; it now wraps and scales to fit.

## Notes
- Duel Cup sources: https://www.eurothrowers.org/duel-cup, https://www.eurothrowers.org/european-knife-and-axe-throwing-rules; KATTA UK: https://www.knifethrowing.co.uk/ (target guide: ebthrowers.co.uk club files, "Katta Guide to different Targets").
