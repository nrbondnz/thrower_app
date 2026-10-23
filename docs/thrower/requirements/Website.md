---
tags: [requirements, website]
---

# Website

Back to [[Requirements Index]].

## What's Wanted
- A public website at **knifeandaxethrower.com** (production) and **dev.knifeandaxethrower.com** (development), each from its own branch (`website`, `website-dev`). Nigel, 2026-10-20.
- Rich content to grow over time; the stack chosen for that (Astro + TypeScript, not Flutter web).
- It hosts what the stores need: the privacy policy and a support page.

## What Exists Today
- 🟡 The domain, both branches and a starter home page, live on knifeandaxethrower.com. See [[Website Index]].
- 🟡 The store pages (Privacy, Terms, Support, Delete Your Account, Delete Your Data) on `website-dev` only, updated 2026-10-23 for Game Center and the leaderboards ([[story-checkpoint-compliance]]). Not live until Nigel approves them and `website-dev` is merged into `website`.
- The app links them from Setup → Help and support. The store answers: [[Store Compliance]].
- The decision: [[Design Decisions#Website: Astro, Orphan Branches, in the Same Amplify App (2026-10-20)]].

## Open Questions
- Which pages come first after the privacy policy and support (how to play, news, the Game Centre)?
- ~~A contact email on the domain?~~ Done: `kaat-support@knifeandaxethrower.com` exists (Nigel, 2026-10-23).
