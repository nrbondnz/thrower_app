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
IN PROGRESS 2026-10-23: Tasks 1, 3 and 4 done. **Task 2 (publishing) waits for Nigel** to approve the wording on dev.knifeandaxethrower.com.
- Don't ship a build with the Help and support links to App Review, or enter the URLs in the store consoles, until the pages are live (Review Agent, Task 3).

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

## Questions for Nigel (answered 2026-10-23)
- **Support email:** the pages use `kaat-support@knifeandaxethrower.com`. Does that mailbox exist?
  - **Answer:** yes, it exists.
- **Business:** the pages name **Bond Consultancy Ltd**, Whangaparaoa, Auckland, as WhereWillWeVisit does. Is that right for Thrower?
  - **Answer:** yes, that's correct.

## Still for Nigel
- Approve the website wording on dev.knifeandaxethrower.com, so Task 2 can publish it.
- The age rating answers (Store Compliance → Age Rating).

---

## Task Log

### Task 1: Website pages brought up to date
- **Status:** COMPLETE (2026-10-23)
- **Where:** branch `website-dev`, worktree `C:\dev\flutter_projs\thrower_app-website`, commit `4d22597`.
- **What changed:**
  - **Privacy:** a new section 4, Leaderboards (Apple Game Center, iPhone). Later sections renumbered (5 to 12). Each knife's score, the stats, the posted flag and Appearance are kept on the phone.
  - **Terms:** a new section 5, Leaderboards (fair play). Later sections renumbered (6 to 12).
  - **Delete account:** the new path (Setup → Help and support → Delete account). Game Center scores are Apple's.
  - **Support:** answers on posting and the leaderboards.
  - **Delete data:** the History path.
  - Every page dated 23 October 2026.
- **Verify:** Nigel reads them on dev.knifeandaxethrower.com.

### Task 2: Publish the website pages
- **Status:** WAITING for Nigel to approve the wording.
- **How:** [[Common Tasks]] → Publish the Website Pages.
- **Then:** device checks CP5 and CP6 ([[Device Test Plan]]).

### Task 3: Help and support in the app
- **Status:** COMPLETE (2026-10-23), commit `5dae5c7`.
- **What changed:**
  - `lib/ui/support_links.dart` (new):
    - `SupportLinks`: the website URLs and the support email.
    - `linkOpenerProvider`: opens a link with `url_launcher`, in the browser or mail app (external application). Tests override it.
    - `HelpAndSupportCard`: Instructions, Support (email), Help online, Privacy Policy, Terms of Service, Delete account. A link that won't open shows a snack bar with the address.
    - `deleteAccountScreen({accounts})`: the Account screen in a build with accounts, else `NoAccountScreen`.
    - `NoAccountScreen`: no account on this phone; sessions are deleted in History; Game Center scores are Apple's; a button to the website's Delete Your Account page.
  - `lib/ui/setup_screen.dart`: the "Help" section is now **Help and support**.
  - `pubspec.yaml`: `url_launcher` a direct dependency (it was already there through amplify_authenticator).
  - `AndroidManifest.xml`: a `<queries>` intent for `SENDTO` `mailto`, so the mail app can be found on Android 11+.
- **Review Agent:** OK. Don't send a build with these links to App Review, or enter the URLs in the store consoles, until the pages are live.
- **Tests:** `test/ui/support_links_test.dart`; small updates in `account_screen_test`, `app_shell_test`, `live_test_screen_test`, `widget_test`.
- **Device checks:** CP0 to CP4 ([[Device Test Plan]] → Compliance Checks).

### Task 4: Store answers, docs, checks, handoff
- **Status:** COMPLETE (2026-10-23), apart from the Traceability Agent.
- **What changed:**
  - [[Store Compliance]] (new): the App Privacy and Data safety answers, the URLs, the age rating notes and a release checklist.
  - Docs Agent: see the Doc Update Log below.
  - Device checks CP0 to CP6; [[Mac Handoff]] → Build 15 has Help and support.

---

## Doc Update Log: 2026-10-23

### Files Updated
- `Architecture/Design Decisions.md`: a new section, Compliance: Policies and Help and Support (2026-10-23).
- `Architecture/Glossary.md`: `HelpAndSupportCard`, `NoAccountScreen`, `SupportLinks`, `linkOpenerProvider`.
- `website/Website Index.md`: the store pages' state (updated on `website-dev` 2026-10-23, not live).
- `Operations/Privacy Policy (Draft).md`: the status line points to the website and [[Store Compliance]].
- `Operations/Device Test Plan.md`: Compliance Checks, CP0 to CP6.
- `Operations/Mac Handoff.md`: Build 15 "Also in it" Help and support; `pod install` note; CP checks.
- `Operations/Common Tasks.md`: Publish the Website Pages.
- `requirements/Instructions and Safety.md`, `requirements/Accounts and Sign-In.md`, `requirements/Website.md`: What Exists Today.
- `tool/web_docs/content.py` and the built web pages (`docs/web/`): Setup's Help and support.
- `CLAUDE.md`, `docs/working-with-nigel.md`: the compliance story in progress.

### Notes
- The Privacy Policy draft is kept as the original; the website's `/privacy` replaces it.

---

## Plan Changes Log
- (none yet)
