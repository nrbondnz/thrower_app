---
tags: [requirement, across-the-app, accounts]
status: partly-built
---

# Accounts and Sign-In

Part of [[Requirements Index]] → Across the app. **Status:** 🟡 Partly built (email sign-in deployed; Google, Apple, the backup and Delete account written, waiting for the provider secrets; device checks to come)

## What's Wanted
- **Each app user has an account** (Nigel, 2026-10-04: "accounts needed"; 2026-10-19: the app user names players, and friends link their accounts). See [[Accounts Roadmap]] → App Users, Players and Friends.
- **Signing in is never needed to score.** The app asks for an account only when the user wants what it gives: backup now, then friends, live sessions and the Game Centre ([[Subscriptions]]). Apple's Guideline 5.1.1 says the same.
- **Sign in with email, Google or Apple**, as WhereWillWeVisit (Nigel, 2026-10-19). Apple requires Sign in with Apple once Google is offered.
- **Their games and player names are kept safe** and come back on a new phone ([[Game Recording]], [[Player Names]]).
- **The user can delete their account inside the app** (both stores require it), and is told what's stored where ([[Instructions and Safety]], a privacy policy).

## What Exists Today
Stage 2 of the [[Accounts Roadmap]], [[story-checkpoint-app-user-accounts]]. Why and how: [[Design Decisions]] → User Accounts Required.
- **The backend** (Task 1, deployed): AWS Amplify Gen 2 in the repo (`amplify/`), Cognito in London (`eu-west-2`), deployed by Amplify Hosting from GitHub (`main` = production, `dev` = development). A build without the backend's settings runs signed out, as before. The user's ID is the Cognito `sub`.
- **Home → Account** (Task 2, deployed; Nigel signed up and in on the Samsung): email sign-up, the emailed code, sign-in and sign-out, with Amplify's ready-made screens. They show only inside the Account screen, never in front of the app.
- **Google and Sign in with Apple** (Task 3, written, not pushed): waiting for Nigel's console setup and the six secrets ([[Common Tasks]] → Set Up Google and Sign in with Apple). Readable sign-in domains per branch (`throwerapp`, `throwerapp-dev`); the app's return link `throwerapp://`. The Sign in with Apple capability is added in Xcode ([[Mac Handoff]]).
- **The backup** (Task 4, written, deploys with Task 3): signed in, the kept games and names go to the user's own rows (owner-only) and come back on a new phone. See [[Data Flow]] → Backup.
- **Delete account** (Task 5, written): on the Account screen, asking first. The backup is erased, then the account; the phone keeps its games and names.
- **Told to the user:** the Instructions' **Your account** section ([[Instructions and Safety]]), and a [[Privacy Policy (Draft)]] for Nigel to approve.
- **Device checks:** AC0–AC8 in [[Device Test Plan]] → Account Checks.

## Open Questions
- **Age:** are accounts adults only (an age check at sign-up), or are under-18s allowed with care? ([[Accounts Roadmap]] → Open Decisions)
- **The app user's own seat:** "Me", or their name, by default, once they're signed in? ([[Accounts Roadmap]] → Stage 1)
- **The privacy policy:** approve, add the contact email and owner name, publish (`web_public/privacy.html`); then the store privacy labels.
- **The Apple button's style** (Guideline 4): check before any store build; WhereWillWeVisit's own button was rejected.
- **Deletes while signed out come back** at the next sign-in (no tombstones). Fine for now?

## Related
- [[Accounts Roadmap]] → Stage 2
- [[Design Decisions]] → User Accounts Required
- [[System Diagram]] (the BACKEND box), [[Data Flow]] → App Start: Accounts, Backup
- [[Glossary]] → Signed out, Cognito sub, Backup (owner-only), Offline-first, Sign-in domain
- [[Game Recording]], [[Player Names]], [[Subscriptions]], [[Instructions and Safety]]
