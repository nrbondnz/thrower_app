---
tags: [requirement, basic-play]
status: partly-built
---

# Game Recording

Part of [[Requirements Index]] → Basic play. **Status:** 🟡 Partly built

## What's Wanted
Games are recorded: the scores, and video of the throws.

## What Exists Today
- **Scores: built.** Every finished game of Play is kept **on the phone** (one JSON file in the app's private folder): when, the mode, the length, each player's round totals and, since 2026-10-19, the players' names ([[Player Names]]), and since 2026-10-23 **each knife's score** (`GameRecord.knives`, for the stats: [[Throwing Stats]]); the **History** tab lists them (Home → History before 2026-10-23), a game opens to every round, and games can be deleted ([[story-checkpoint-game-history]]; device checks H0–H7 to come). **Clear history** is a bin icon in History's title bar (2026-10-23). Signed out, nothing is sent anywhere.
- **Stats over the kept sessions** (2026-10-23, [[story-checkpoint-app-design]]): History shows sessions, knives, per knife, 5s, hit rate and the best ranked total (or best round) above the sessions, and Home shows the last session. Sessions kept before 2026-10-23 have no knives, so they count only towards Sessions and Best. See [[Throwing Stats]]; device checks AD8–AD9 to come.
- Quick draw matches aren't kept yet.
- **Backup: built, not yet deployed** (2026-10-19, [[story-checkpoint-app-user-accounts]] Task 4; deploys with Task 3 once the provider secrets exist; device checks AC3–AC8 to come). Stage 2 of the [[Accounts Roadmap]]; requirement [[Accounts and Sign-In]].
  - Signed in, each kept game is also backed up to the user's own rows (`KeptGame`, owner-only, AWS London). The phone stays the source of truth (offline-first): no signal, and the game is kept on the phone and backed up later.
  - Signing in merges by game `id`: on a new phone, History comes back; games only on the phone go up. Delete and Clear history reach the backup too. The Account screen shows how backing up went, with **Back up now**.
  - **Posted** (2026-10-23): a session posted on either copy is Posted on both (`SyncedGameHistory.sync`), so it can't be posted twice. Device check SF2.
  - **Delete account** erases the backup; the phone's History stays.
  - **Known limit:** a game deleted while signed out comes back at the next sign-in.
  - Why and how: [[Design Decisions]] → User Accounts Required (Task 4); [[Data Flow]] → Backup.
- **Video: planned, paused.** [[story-checkpoint-record-and-share]] (backlog #11): both modes recorded, Play as a short clip per throw, the scoring overlays (rings, scores, times, the winner) drawn on when sharing; sound from the microphone (a new permission). Paused until the live Quick draw's device check is done.

## Open Questions
- Keep Quick draw matches in History too?
- Should a game deleted while signed out stay deleted (tombstones), rather than coming back at the next sign-in?
- Whose video is it? The [[Accounts Roadmap]]'s rule (proposed): the host's phone records a throw, the **thrower owns it**.
- Where video goes once there are accounts: phone to phone, or the cloud (roadmap stage 5)?
- Consent: other people in the frame (other throwers, bystanders).

## Related
- [[Results Sharing]]
- [[story-checkpoint-record-and-share]]
- [[Accounts Roadmap]] → Stage 2 (backup) and Stage 5 (video)
- [[Accounts and Sign-In]]
- [[Design Decisions]] → Game History; App Design: Themes, Tabs and Stats
- [[Throwing Stats]]
