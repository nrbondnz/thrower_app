---
tags: [requirement, basic-setup]
status: built
---

# Player Names

Part of [[Requirements Index]] → Basic setup. **Status:** ✅ Built for named players, 2026-10-19 (device checks to come); friends are stage 3, not built

## What's Wanted
Players can be named, not just "Player 1" and "Player 2" (Nigel, 2026-10-19): **each app user has an account**; they **name players**, who **just have scores** ("they could just as well be player 2"), and can **send them videos using share**. To be **fully integrated**, a person must **also have the app and link their account** to the app user as a **friend**; then their throws are **recorded on their own app**. See [[Accounts Roadmap]] → App Users, Players and Friends.
- **Named player:** a name on a seat for one game. No list, no history of their own, no app needed.
- **Friend:** another app user, linked; picked for a seat in place of a name (stage 3).

## What Exists Today
- **Named players: built** ([[story-checkpoint-named-players]] Tasks 1–3; device checks to come in Task 4). Why and how: [[Design Decisions]] → Named Players.
  - **Play's setup screen** has a name field per player (optional, up to 16 characters). A blank seat is **Player 1** / **Player 2**, as before.
  - **The last names used are kept on the phone** (`player_names.json`, `lib/settings/`) and filled in next time, even after the app is closed. Signed out, nothing is sent anywhere (signed in: backed up, below).
  - **Play and two-target Play** use the names everywhere a player is named: whose turn, wait for, the totals, the winner, the score-correction rows, the board messages. Renaming mid-game keeps the scores; New game keeps the names.
  - **History** keeps the names each game was played with (`GameRecord` version 2); games kept before show Player 1 / Player 2.
  - **Quick draw** uses the same names (choosing the boards, the round result, the match), changeable with **Names** before Start. The per-player result lines keep "1:" / "2:", matching the board numbers on the picture.
  - **The in-app Instructions explain it** (Task 4): *Playing a game* says how to name players before Start (up to 16 letters, blank is Player 1 / Player 2) and that the last names are kept on this phone and sent nowhere; *Quick draw* says to tap **Names**. See [[Instructions and Safety]].
- **Friends** (other app users, linked accounts): not built (stage 3).
- **The app user's account** (stage 2, [[story-checkpoint-app-user-accounts]]; requirement [[Accounts and Sign-In]]): in progress. Email sign-in is deployed (Home → Account, Tasks 1–2). Why: [[Design Decisions]] → User Accounts Required.
  - **Names backed up: built, not yet deployed** (Task 4; device checks to come). Signed in, the names are saved to the user's own row (`PlayerNameList`, owner-only) as well as the phone. On sign-in (`PlayerNamesNotifier.syncWith`), a phone with no names takes the backup's (a new phone); otherwise the phone's names are backed up. Delete account erases the row; the phone keeps its names.

## Open Questions
- Answered 2026-10-19 ([[story-checkpoint-named-players]]): the last names are kept on the phone and filled in; a blank seat is Player 1 / Player 2; still 1 or 2 players (more players is its own story); Quick draw uses the same names.

## Related
- [[Accounts Roadmap]] → Stage 1 (named players: built), Stage 2 (the app user's account: in progress) and Stage 3 (friends)
- [[Accounts and Sign-In]]; [[Data Flow]] → Backup
- [[Design Decisions]] → Named Players
- [[Data Flow]] → Player Names: Into the Game, History and Quick Draw
- [[Glossary]] → Named player
- [[backlog]] #4 Accounts, #5 Game modes (typed names)
- [[Instructions and Safety]] (how the Instructions explain naming)
- [[Remote Play]], [[Results Sharing]]
