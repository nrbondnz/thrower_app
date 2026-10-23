# Story Checkpoint: Compliance (Policies, Support, Delete Account)

## Story Goal
Nigel, 2026-10-23: "We are not ready to go live but we should do some of the compliance work. On wherewillwevisit.com … there is a privacy policy, terms of service and delete account. On the app itself there is a support page with delete account. Can we do all this?"

WhereWillWeVisit has these on its website (`web/privacy.html`, `terms.html`, `delete-account.html`, `delete-data.html`) and a support page in the app. Thrower should have the same, for App Store and Google Play review.

## What Exists Already (2026-10-23)
- **Website** (`website-dev` branch, commit `bb66c0c`, 2026-10-20): `/privacy`, `/terms`, `/support`, `/delete-account`, `/delete-data`, with footer links. **Not live:** the `website` branch (knifeandaxethrower.com) is still the starter page.
  - These were written before Game Center (2026-10-22), posting from History and the leaderboards, the stats, and the knife scores kept with each session (2026-10-23). The privacy policy doesn't mention Game Center.
- **App:**
  - Delete account is on the Account screen (accounts Task 5). That screen shows only in a build connected to the accounts backend, and no build is yet.
  - There's no Support page.

## Complexity Score
4 (Large): the website, the app's UI, a new plugin (`url_launcher`, native) (1), and more than 3 acceptance criteria (1).

## Status
PLANNED 2026-10-23: waiting for Nigel's approval.

## Plan

### Task 1: Bring the website pages up to date (on `website-dev`)
- **Work:**
  - **Privacy:** Game Center (only a total you choose to post, under your Game Center nickname; Apple's policy); the leaderboards; each knife's score and the stats kept on the phone; Appearance kept on the phone; nothing new leaves the phone.
  - **Terms:** leaderboard fair play: post only real throws, from the distance you say (3 m), and don't change scores; scores on Game Center can't be edited by us.
  - **Delete account:** Game Center scores are Apple's. Deleting your Thrower account doesn't remove them; how to remove them in Game Center.
  - **Support:** short answers on posting, "Can be posted" and the leaderboards; the email address.
  - Every page: "Last updated" date.
- **Verify:** Nigel reads them on dev.knifeandaxethrower.com.

### Task 2: Publish the website pages
- **Work:** merge `website-dev` into `website`, so knifeandaxethrower.com/privacy and the others go live. These are the URLs App Store Connect and Google Play ask for. **Only after Nigel approves the wording in Task 1.**
- **Verify:** the pages open on knifeandaxethrower.com.

### Task 3: A Support page in the app
- **Work:**
  - Setup → **Help and support**: Instructions (as now), **Support** (email us, and the support page), **Privacy Policy**, **Terms of Service**, and **Delete account**.
  - Delete account opens the Account screen's delete in a build with accounts. Without accounts it says there's no account on this phone (sessions are deleted in History) and links the website's Delete Your Account page.
  - Links open in the browser or the mail app with **`url_launcher`**. That's a new plugin, so the "Be Careful" Review Agent runs (Android `<queries>`, iOS).
- **Verify:** widget tests; on both phones, each link opens.

### Task 4: Store answers, docs, checks, handoff
- **Work:**
  - `docs/thrower/Operations/Store Compliance.md`: the answers for **App Store Connect → App Privacy** and **Google Play → Data safety** (like WhereWillWeVisit's notes), the URLs to enter, and the age rating notes (knives and axes).
  - Docs Agent, Traceability Agent, device checks, and the Mac Handoff.

## Questions for Nigel
- **Support email:** the pages use `kaat-support@knifeandaxethrower.com`. Does that mailbox exist?
- **Business:** the pages name **Bond Consultancy Ltd**, Whangaparaoa, Auckland, as WhereWillWeVisit does. Is that right for Thrower?

---

## Plan Changes Log
- (none yet)
