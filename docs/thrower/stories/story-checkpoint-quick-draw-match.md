# Story Checkpoint: Quick Draw Match (KATTA Rules)

## Story Goal
Quick draw follows the rules Nigel's brother plays to (Nigel, 2026-10-19): **"The quick draw is always three rounds, first to stick in target wins, bounce outs lose, if the times are the same then score is the decider if possible, if the same score the round is a draw."** It also names the scoring the app already uses as **KATTA** ("scoring method is KATTA which is prevalent in the UK"). Follows [[story-checkpoint-live-quick-draw]] (one duel at a time, Next duel) and [[story-checkpoint-quick-draw]] (archived). It comes before [[Accounts Roadmap]] stage 1 (Nigel, 2026-10-19).

## Complexity Score
4 (Large): rules (pure Dart) → the live Quick draw screen → instructions (3 layers), and branches: the score tie-break, extra rounds, finishing early (1).

## Status
PLANNED (2026-10-19): waiting for Nigel's approval of the plan. No code yet.

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

### Task 2: The live Quick draw as a three-round match
- **Setup:** Task 1.
- **Work:** `LiveQuickDrawScreen` keeps a `QuickDrawMatch`.
  - The result panel shows the round's result and the match score: "Round 1 of 3: Player 2 wins (stuck 4, 0.82 s)" and "Player 2 leads 1–0".
  - **Next round** replaces Next duel, then **Extra round** when level after three. **Finish match** sits beside it (with a confirm, as Finish game has).
  - At the end, the **match result** is in large type ("Player 2 wins the match 2–1" / "A draw"), with the chime, followed by **New match**.
  - The recorded Quick draw shows the round rule's result (its single round).
- **Verify:** widget tests: three rounds to a winner; an extra round when level; Finish match. **Nigel:** Live test → Quick draw shows the new round result. The live match needs the camera: device checks for Nigel's brother (Task 3).
- **Next:** Task 3.

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

---

## Plan Changes Log
- **2026-10-19:** Planned from the brother's feedback (via Nigel); three questions answered (all three rounds with Finish match; extra rounds when level; this story before accounts).

## Notes
- Duel Cup sources: https://www.eurothrowers.org/duel-cup, https://www.eurothrowers.org/european-knife-and-axe-throwing-rules; KATTA UK: https://www.knifethrowing.co.uk/ (target guide: ebthrowers.co.uk club files, "Katta Guide to different Targets").
