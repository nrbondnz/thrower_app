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
  - changing a score means going to the phone: only when no one is throwing (two targets: both finished), leaving the phone where it is;
  - scoring by hand (Precision, Three targets) means going to the phone after every knife: only when no one is throwing, or someone who isn't throwing keeps score; never stand in the lane to use the phone.
- **The App Store** (Nigel, 2026-10-19): he hopes the instructions and safety notes reassure Apple's review about an app for knives and axes. App Review Guideline 1.4.3 covers apps that encourage illegal or reckless use of weapons; the app should read as a scoring aid for a supervised sport, never as encouragement. An age rating is to be chosen.

## What Exists Today
- **Home → Instructions** (`InstructionsScreen`, `lib/ui/instructions.dart`; [[story-checkpoint-instructions-and-game-length]]). A switch at the top: **Real board** (the default) or **Paper target** (an A4 printout with pens in Blu Tack, placed by hand; nothing is ever thrown at it).
- **The sections** (`instructionSections`): Setting up, Calibrating the target, Playing a game, Two players on one target, Two players on two targets, Precision and Three targets, Scoring, Changing a score, Resetting, History, Your account, Quick draw, Safety, Reporting problems.
  - Numbers (rounds, throws per round, ring scores, the line-touch rule, the name length) are read from the code (`GameSession`, `TargetModel`, `GameLengthNotifier.choices`, `maxNameLength`), so they can't drift.
  - Each story adds its own points: two players ([[story-checkpoint-players-and-targets]]), History ([[story-checkpoint-game-history]]), changing a score ([[story-checkpoint-score-corrections]]), the Quick draw match ([[story-checkpoint-quick-draw-match]]), naming players and **Names** in Quick draw ([[story-checkpoint-named-players]], 2026-10-19), and fixing a board's outline ([[story-checkpoint-adjust-boards]], 2026-10-19), and **Precision and Three targets** ([[story-checkpoint-more-game-types]], 2026-10-20: which game, Precision's distances (read from `precisionDistances`), one knife at each target, taking turns, the score pad, and the safety line below). And **Draw round the boards** in Quick draw ([[story-checkpoint-quick-draw-areas]], 2026-10-21: draw on the screen, never at the boards, only when no one is throwing; only the time decides), and **square or rectangular boards** ([[story-checkpoint-board-outlines]], 2026-10-21: a round board stays round; one drawn round a square or rectangular board gets four corners to drag into place).
  - **Your account** ([[story-checkpoint-app-user-accounts]] Task 5, 2026-10-19; [[Accounts and Sign-In]]): an account is optional and everything works without one; the person icon on Home to create one or sign in; signed in, History and the names are backed up and come back on another phone, the phone first; **Delete account** (asks first) deletes the account and its backup, and the phone's games and names stay. History's privacy line now says the app sends the history nowhere "unless you sign in". A [[Privacy Policy (Draft)]] says the same for the stores.
  - **Adjusting two boards** (*Two players on two targets*, *Quick draw*): drag an outline into place (inside to move it, a white handle to turn or stretch it), or tap Choose boards again. Two targets: if a board or the phone is knocked, **Adjust boards** when no one is throwing, drag it back, **Lock boards**; watching stops until then and the scores stay. Quick draw: **Adjust boards** between rounds, only when no one is throwing; the match carries on.
- **On-screen safety lines**, besides the Instructions: "Only adjust when no one is throwing" while calibrating, and "Drag an outline to fit its rings if needed (only when no one is throwing)" while two boards can be adjusted (2026-10-19, [[story-checkpoint-adjust-boards]]); the "only when no one is throwing" note while waiting for **Tap the board**'s tap on Calibrate, and the Instructions' Calibrating section says to tap the board only when no one is throwing (2026-10-21, [[story-checkpoint-gapped-rings]], [[Board Finding]]); "Collect your knives when no one is throwing" at the end of a round; on the score pad, "Tap each knife's score when no one is throwing, or have someone who isn't throwing keep score." (2026-10-20); the next thrower is never named while the knives are still to be collected; while drawing round Quick draw's boards, "Draw a finger round the edge of Player 1's board (round, square or rectangular). Any knife that sticks inside counts: the time wins, not the score." (2026-10-21; "round, square or rectangular" added the same day, [[story-checkpoint-board-outlines]]); Quick draw runs a whole duel with nobody touching the phone, and shows the result large enough to read from the throwing line.
- **Guarded by** the "Be Careful" Review Agent's §7 Physical Safety checklist (`docs/agents/review-agent/review-agent.md`), run on any change to what the user is told to do physically. Keeping the text current: [[Common Tasks#Update the In-App Instructions]]. Checked by `test/ui/instructions_test.dart`.
- **Not yet:** an age rating, a first-run safety screen, translations.

## Open Questions
- **Age rating:** 12+ or 17+ on the App Store (and the Google Play equivalent)? Adults only, or under-18s with an adult present?
- **A first-run safety screen** (read and accept before the first game), or are the Instructions enough for App Review?
- **Translations:** English only for now; which languages, if any, for European throwers?
- Should Quick draw ask the starter to confirm the lanes are separate before the first Start?

## Related
- [[Design Decisions]] → Rounds and Scoring (In-app Instructions; Safety), Adjust and Lock the Calibration (Safety), Single Player First (the two-player Safety notes), Score Corrections (Safety), Adjust Each Board (Safety), Quick Draw: the Live Duel and the Result, Quick Draw: Draw Round the Boards (Safety), Quick Draw: Round or Four-Cornered Boards (the screen), Named Players (Instructions), More Game Types (scored by hand first)
- [[Player Names]], [[Game Type]], [[One Target]], [[Two Targets]], [[Scoring Rules]]
- [[backlog]] #6 (store-release hygiene)
