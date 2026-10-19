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
- **Quick draw:** the first knife to stick wins a round; a bounce-out or false start loses; on the same frame the higher score wins ([[story-checkpoint-quick-draw-match]]).
- **Knives only**, so far.

## Open Questions
- Other bodies' rules (WATL's lower-ring rule and killshots, IATF): not wanted for now (backlog #3, 2026-10-18).
- Axes: once knives work 100% (backlog #7).
- For rankings: are corrected scores allowed in ranked games? (See [[Rankings]].)

## Related
- [[Design Decisions]] → Throwing Sport; Score Against the Painted Rings
- [[Glossary]] → KATTA scoring, Line-touch rule
- [[backlog]] #3 (line-touch variants), #7 (axes)
