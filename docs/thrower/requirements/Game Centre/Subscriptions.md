---
tags: [requirement, game-centre]
status: idea
---

# Subscriptions

Part of [[Requirements Index]] → Game Centre. **Status:** 💭 Idea, being thought through

## What's Wanted
The app is paid for by **subscription** (Nigel, 2026-10-19):
- **14 days' free use**, then the user must subscribe (Nigel corrected "weeks" to days, 2026-10-19).
- Without a subscription, the app **denies or degrades** what's available, e.g. **no uploading to the Game Centre**, **no Quick draw**.
- A free month's subscription is also a prize: [[Competitions and Prizes]].

- **Payments by platform** (Nigel, 2026-10-20): **Stripe on Android**; Apple's in-app purchase on iOS (Apple requires it for digital subscriptions). Backlogged as [[backlog]] #15. The cloud config and secrets each will need are in [[Cloud Config Setup]] → Future: Subscriptions. **To check:** Google Play's payments policy (Play Billing is normally required for in-app digital subscriptions; Stripe needs Google's alternative or user-choice billing, or a purchase outside the app).

## What Exists Today
- Nothing yet. Payments are **deferred** ([[Design Decisions]] → User Accounts Required; Backend and Payments Deferred).
- Everything is free and works on the phone alone.
- **Accounts: in progress** (stage 2 of the [[Accounts Roadmap]], [[story-checkpoint-app-user-accounts]]; [[Accounts and Sign-In]]). Email sign-in is deployed (Home → Account); Google, Sign in with Apple, the backup and **Delete account inside the app** (one of the store rules below) are written and wait for the provider secrets. Subscriptions are **not in that story**: they come with the Game Centre (stage 6). Signing in is never needed to score.
- The [[Privacy Policy (Draft)]] covers accounts only; a later version must cover payments.

## Proposed Shape (Claude's thoughts, 2026-10-19, to confirm)

**Degrade, don't deny.** Keep the core free for good, and charge for what's online, social or costly to run:

| Free, always | With a subscription (after the 14 free days) |
|---|---|
| Play: scoring games, 1 or 2 players, 1 or 2 targets, any length | **Game Centre:** uploading results, [[Rankings]], [[Competitions and Prizes]] |
| History on the phone; score corrections | **Online:** backup and sync, friends' accounts, [[Remote Play]], joining sessions |
| Quick draw: casual matches *(or premium: Nigel's call, below)* | **Video:** recording and sharing throws ([[Game Recording]], [[Results Sharing]]) |

Why this split:
- **Costs follow use:** on-phone scoring costs nothing to run, while the Game Centre, accounts and video storage cost money every month. Charging for those keeps the price tied to the costs.
- **Word of mouth:** a club night where the app just works, free, brings in the next players. An app that stops working after 14 days gets one-star reviews and is deleted. 14 days is only one or two club nights for many throwers, which is a short time to get hooked, so what stays free matters more. One that still scores but can't rank you gives people a reason to subscribe.
- **The rankings stay worth something:** if only subscribers rank, the leaderboards are smaller but more committed. It also helps with trust (see [[Rankings]]).

**Quick draw: free or premium?** It runs on the phone, so it costs nothing to run, and it's the feature that draws a crowd at a club. Options:
- **Free to play, premium to rank or record it** (recommended): free casual duels spread the app; subscribers get ranked Quick draw and the clips.
- **Premium entirely**, as Nigel suggested: a stronger reason to subscribe, but the showpiece is locked away from new players.
- **A few free matches a week** after the free days: a taste, with a reason to subscribe.

**The 14 free days:**
- **The stores do this already.**
  - **Two weeks is one of Apple's standard free-trial lengths** for subscriptions (an introductory offer), and Google Play supports the same. The store runs the clock, one trial per Apple ID / Google account, so reinstalling the app doesn't reset it, and the store handles the renewal, cancelling and reminders. That's less to build and to get wrong.
  - **The catch:** a store trial asks for **payment details up front** and then **renews automatically** unless cancelled. That converts more trials into subscriptions, but some people won't start one.
- **The alternative is a free period the app counts itself:** no payment details, and a subscription offered when it ends.
  - It needs the account (stage 2), so the clock follows the person: a clock kept on the phone resets if the app is reinstalled.
  - Check Apple's current guidelines on how a time-limited free period must be offered.
  - It's more to build.
- **Recommended: the store's 2-week trial**, on the subscription itself, with the free core (above) for anyone who doesn't start one. Check both stores' current rules at stage 2, before building.
- **No point running the clock before there's anything to pay for.** Until the Game Centre exists, everything stays free. Testers and early users get their 14 days when subscriptions start.

**Other points:**
- **The backend is AWS Amplify** (Nigel, 2026-10-19). WhereWillWeVisit (`where_in_nz_v3`) already verifies Apple purchases on the server and listens to Apple's server notifications (`verifyAppleTransaction`, `appleServerNotifications`): the pattern to reuse, plus Google Play's equivalent.
- **Monthly and yearly prices** (yearly at a discount). The stores take 15–30% (15% for small developers, and for subscriptions after the first year). Digital features must be bought through the stores' own in-app purchase.
- **Store requirements:**
  - **Restore purchases**;
  - a link to **manage or cancel** the subscription;
  - clear **terms** (price, length, renewal) on the paywall;
  - **account deletion** inside the app (needed anyway with accounts; written in accounts Task 5, without the subscription warning WhereWillWeVisit has, which comes with subscriptions).
- **Club or venue plans** (later): a venue pays once for its members or lanes. This could matter more than individual subscriptions for a sport played at clubs.
- **The weekly prize** (a free month) for someone still in their 14 free days: add the month on after the trial? (With a store trial, a free month is a **promotional offer** or **offer code**, which both stores support.)

## Open Questions
- **Deny or degrade:** degrade, with the core free (recommended above)?
- **Quick draw:** free, premium, or free to play and premium to rank or record?
- **The 14 days:** the store's 2-week trial (payment details up front, auto-renews; recommended), or a free period the app counts from sign-up?
- **Price:** monthly, yearly, both?
- **Venue or club plans?**
- **Early users:** testers and anyone using the app before subscriptions begin get their 14 days from that day?

## Related
- [[Competitions and Prizes]] (the free month as a prize)
- [[Rankings]] (subscribers only?)
- [[Accounts Roadmap]] (stage 2: accounts and the backend; payments come with them)
- [[Design Decisions]] → User Accounts Required
