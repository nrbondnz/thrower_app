---
tags: [requirement, basic-setup]
status: built
---

# Scoring Rules

Part of [[Requirements Index]] → Basic setup. **Status:** ✅ Built (device checks to come where noted)

## What's Wanted
The app scores each throw by the rules throwers use: **KATTA**, which is prevalent in the UK (Nigel's brother, 2026-10-19).

## What Exists Today
- **KATTA scoring** (`TargetModel.katta`): 5 rings, 10 / 20 / 30 / 40 / 50 cm across on the competition face, scoring **5 / 4 / 3 / 2 / 1** from the centre; a blade on a line scores the **higher** ring; only a stuck tip scores. The same as the European and IKTHOF targets. Larger boards (Nigel's are 75–85 cm) score by proportion.
- A **bounce-out** or a miss scores 0; a knife that **falls out** before it's collected turns that throw into 0; a knife whose entry point wasn't found shows "?" and scores 0.
- **Score corrections:** any score in the game being played can be changed by hand (0–5), and a throw the camera missed can be added ([[story-checkpoint-score-corrections]]).
- **Strict mode** (Ranked games, 2026-10-22, [[story-checkpoint-game-center-scores]]; built, device checks RK0–RK9 to come): a score can only be changed to **0** (a bounce-out), and a missed throw only added as 0; no score can be raised by hand. The rules refuse anything else (`GameType.strict`, `Match.setScore` / `byHand` / `addToRound`); the popup offers only 0. Once a ranked score is posted, the game's scores are locked. Nigel: "they can only change scores to mark a bounce out but not to change scores to higher". See [[Rankings]].
- **Quick draw:** the first knife to stick wins a round; a bounce-out or false start loses; on the same frame the higher score wins ([[story-checkpoint-quick-draw-match]]).
- **Knives only**, so far.

## Open Questions
- Other bodies' rules (WATL's lower-ring rule and killshots, IATF): not wanted for now (backlog #3, 2026-10-18).
- **Choosing the scoring system** (Nigel, 2026-10-19, for the future): other systems selectable, perhaps **by location**: US players would possibly use IKTHOF. A setting, or a default from the phone's region? Rankings then compare players on the same system ([[Rankings]]). Backlog #3.
- Axes: once knives work 100% (backlog #7).
- For rankings: answered for the first ranked game (strict mode, 2026-10-22). Other ranked games later follow the same rule?

## Related
- [[Design Decisions]] → Throwing Sport (KATTA); Score Against the Painted Rings; Score Corrections; Ranked Games and Game Center (strict mode); Quick Draw: Go, False Starts and the Winner
- [[Glossary]] → KATTA scoring, Line-touch rule
- [[backlog]] #3 (line-touch variants), #7 (axes)
