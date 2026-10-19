---
tags: [requirement, across-the-app, safety]
status: built
---

# Instructions and Safety

Part of [[Requirements Index]] → Across the app. **Status:** ✅ Built (kept up to date with each story; device checks to come where noted)

## What's Wanted
- **Players are told how to set up and play**, in the app, in plain words: where the phone goes, calibrating, playing each game type, scoring, changing a score, History and Quick draw.
- **Knives and axes are dangerous, and the app sits next to the lane.** Everything it says or shows must keep people safe:
  - the phone (and tripod) out of the line of throw, never between two lanes;
  - go near the board, or the phone, only when no one is throwing;
  - the app **can't tell whether the lane is clear**, and nothing it shows means it is ("Someone is at the board", "Player 2's turn", "Collect your knives", Quick draw's go, chime and result);
  - Quick draw: separate lanes, each thrower at their own line, a starter behind the throwers, experienced throwers only, under the venue's rules;
  - changing a score means going to the phone: only when no one is throwing (two targets: both finished), leaving the phone where it is.
- **The App Store** (Nigel, 2026-10-19): he hopes the instructions and safety notes reassure Apple's review about an app for knives and axes. App Review Guideline 1.4.3 covers apps that encourage illegal or reckless use of weapons; the app should read as a scoring aid for a supervised sport, never as encouragement. An age rating is to be chosen.

## What Exists Today
- **Home → Instructions** (`InstructionsScreen`, `lib/ui/instructions.dart`; [[story-checkpoint-instructions-and-game-length]]). A switch at the top: **Real board** (the default) or **Paper target** (an A4 printout with pens in Blu Tack, placed by hand; nothing is ever thrown at it).
- **The sections** (`instructionSections`): Setting up, Calibrating the target, Playing a game, Two players on one target, Two players on two targets, Scoring, Changing a score, Resetting, History, Quick draw, Safety, Reporting problems.
  - Numbers (rounds, throws per round, ring scores, the line-touch rule, the name length) are read from the code (`GameSession`, `TargetModel`, `GameLengthNotifier.choices`, `maxNameLength`), so they can't drift.
  - Each story adds its own points: two players ([[story-checkpoint-players-and-targets]]), History ([[story-checkpoint-game-history]]), changing a score ([[story-checkpoint-score-corrections]]), the Quick draw match ([[story-checkpoint-quick-draw-match]]), and naming players and **Names** in Quick draw ([[story-checkpoint-named-players]], 2026-10-19).
- **On-screen safety lines**, besides the Instructions: "Only adjust when no one is throwing" while calibrating, and "Drag an outline to fit its rings if needed (only when no one is throwing)" while two boards can be adjusted (2026-10-19, [[story-checkpoint-adjust-boards]]); "Collect your knives when no one is throwing" at the end of a round; the next thrower is never named while the knives are still to be collected; Quick draw runs a whole duel with nobody touching the phone, and shows the result large enough to read from the throwing line.
- **Guarded by** the "Be Careful" Review Agent's §7 Physical Safety checklist (`docs/agents/review-agent/review-agent.md`), run on any change to what the user is told to do physically. Keeping the text current: [[Common Tasks#Update the In-App Instructions]]. Checked by `test/ui/instructions_test.dart`.
- **Not yet:** an age rating, a first-run safety screen, translations.

## Open Questions
- **Age rating:** 12+ or 17+ on the App Store (and the Google Play equivalent)? Adults only, or under-18s with an adult present?
- **A first-run safety screen** (read and accept before the first game), or are the Instructions enough for App Review?
- **Translations:** English only for now; which languages, if any, for European throwers?
- Should Quick draw ask the starter to confirm the lanes are separate before the first Start?

## Related
- [[Design Decisions]] → Rounds and Scoring (In-app Instructions; Safety), Adjust and Lock the Calibration (Safety), Single Player First (the two-player Safety notes), Score Corrections (Safety), Adjust Each Board (Safety), Quick Draw: the Live Duel and the Result, Named Players (Instructions)
- [[Player Names]], [[Game Type]], [[One Target]], [[Two Targets]], [[Scoring Rules]]
- [[backlog]] #6 (store-release hygiene)
