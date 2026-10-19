---
tags: [requirement, basic-play]
status: partly-built
---

# Game Recording

Part of [[Requirements Index]] → Basic play. **Status:** 🟡 Partly built

## What's Wanted
Games are recorded: the scores, and video of the throws.

## What Exists Today
- **Scores: built.** Every finished game of Play is kept **on the phone** (one JSON file in the app's private folder): when, the mode, the length, each player's round totals and, since 2026-10-19, the players' names ([[Player Names]]); Home → **History** lists them, a game opens to every round, and games can be deleted ([[story-checkpoint-game-history]]; device checks H0–H7 to come). Nothing is sent anywhere.
- Quick draw matches aren't kept yet.
- **Backup: in progress.** Stage 2 of the [[Accounts Roadmap]] ([[story-checkpoint-app-user-accounts]]): signed in, the history is backed up and comes back on a new phone (Task 4). Task 1 (2026-10-19) built the AWS Amplify backend and sign-in plumbing only; nothing is backed up yet.
- **Video: planned, paused.** [[story-checkpoint-record-and-share]] (backlog #11): both modes recorded, Play as a short clip per throw, the scoring overlays (rings, scores, times, the winner) drawn on when sharing; sound from the microphone (a new permission). Paused until the live Quick draw's device check is done.

## Open Questions
- Keep Quick draw matches in History too?
- Whose video is it? The [[Accounts Roadmap]]'s rule (proposed): the host's phone records a throw, the **thrower owns it**.
- Where video goes once there are accounts: phone to phone, or the cloud (roadmap stage 5)?
- Consent: other people in the frame (other throwers, bystanders).

## Related
- [[Results Sharing]]
- [[story-checkpoint-record-and-share]]
- [[Accounts Roadmap]] → Stage 2 (backup) and Stage 5 (video)
- [[Design Decisions]] → Game History
