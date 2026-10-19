---
tags: [requirement, basic-setup]
status: planned
---

# Player Names

Part of [[Requirements Index]] → Basic setup. **Status:** 🗺️ Planned, not built

## What's Wanted
Players can be named, not just "Player 1" and "Player 2" (Nigel, 2026-10-19): **each app user has an account**; they **name players**, who **just have scores** ("they could just as well be player 2"), and can **send them videos using share**. To be **fully integrated**, a person must **also have the app and link their account** to the app user as a **friend**; then their throws are **recorded on their own app**. See [[Accounts Roadmap]] → App Users, Players and Friends.
- **Named player:** a name on a seat for one game. No list, no history of their own, no app needed.
- **Friend:** another app user, linked; picked for a seat in place of a name (stage 3).

## What Exists Today
- Players are numbered: **Player 1** and **Player 2**, everywhere (Play, Quick draw, History).
- `AuthService` exists as an interface only (`lib/auth/`); no sign-in yet.

## Open Questions
- Remember recent names to pick from, rather than typing each time?
- The app user's own seat: "Me", or their name, by default?
- Up to how many players on one target?
- Names in Quick draw too?

## Related
- [[Accounts Roadmap]] → Stage 1 (named players: a name on each seat, `GameRecord` version 2) and Stage 3 (friends)
- [[backlog]] #4 Accounts, #5 Game modes (typed names)
- [[Remote Play]], [[Results Sharing]]
