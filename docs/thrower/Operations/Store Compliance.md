# Store Compliance: Policies, App Privacy and Data Safety

Written 2026-10-23 ([[story-checkpoint-compliance]]). The answers and addresses to give **App Store Connect** and **Google Play Console** before a release, modelled on WhereWillWeVisit's notes (`docs/wherewillwevisit/privacy etc.md` in `where_in_nz_v3`). Not yet live: Thrower isn't released (Nigel, 2026-10-23: "we are not ready to go live").

Related: [[Website Index]], [[Privacy Policy (Draft)]] (superseded by the website), [[Mac Handoff]], [[Rankings]], [[Cloud Config Setup]].

---

## The Addresses

The website pages are written in `src/pages/` on the website branches ([[Website Index]]). They go live on knifeandaxethrower.com when `website-dev` is merged into `website`.

- **Privacy Policy:** https://knifeandaxethrower.com/privacy
- **Terms of Service:** https://knifeandaxethrower.com/terms
- **Support:** https://knifeandaxethrower.com/support
- **Delete Your Account:** https://knifeandaxethrower.com/delete-account
- **Delete Your Data:** https://knifeandaxethrower.com/delete-data
- **Support email:** kaat-support@knifeandaxethrower.com
- **Business:** Bond Consultancy Ltd, Whangaparaoa, Auckland, New Zealand (confirmed by Nigel, 2026-10-23)

**Order:** publish the pages **before** a build that links to them goes to App Review ([[Common Tasks]] → Publish the Website Pages). TestFlight testers may see "not found" until then. The app's Setup → Help and support opens them. Device checks: CP0 to CP6 ([[Device Test Plan]] → Compliance Checks).

## In the App

Setup → **Help and support** (`lib/ui/support_links.dart`):
- **Instructions.**
- **Support:** opens the mail app to the support email.
- **Help online:** the Support page.
- **Privacy Policy** and **Terms of Service**: the website pages.
- **Delete account:**
  - In a build with accounts, it opens the Account screen, which has Delete account (Apple 5.1.1(v)).
  - Without accounts, it says there's no account on the phone (sessions are kept only on it) and links Delete Your Account.

---

## App Store Connect → App Privacy

**Data used to track you:** none. No advertising, no analytics and no tracking SDKs.

**Data linked to you.** Collected only if the user creates an account, which is optional:
- **Contact Info → Email Address**
  - Purpose: App Functionality (sign-in, the backup).
  - Linked to the user: yes. Used for tracking: no.
- **Identifiers → User ID** (the Amazon Cognito sign-in ID)
  - Purpose: App Functionality.
  - Linked: yes. Tracking: no.
- **User Content → Gameplay Content** (the backed-up sessions: scores and player names)
  - Purpose: App Functionality.
  - Linked: yes. Tracking: no.

**Not collected:**
- **Photos or Videos:** the camera picture is analysed on the phone and never sent or saved.
- Location, Health, Financial Info, Contacts, Browsing History, Purchases, Diagnostics, Usage Data.

**Game Center:** a total the user chooses to post goes to Apple's Game Center. The app also shows each week's table (other players' Game Center nicknames, places and scores), loaded from Game Center when it's opened; nothing is saved on the phone. Displaying them isn't data the developer collects. Apple collects and runs that data under its own policy. The app declares **User Content → Gameplay Content** already (the step-8 note in [[Mac Handoff]] → Build 11).

**Other App Store Connect fields:**
- **Privacy Policy URL:** /privacy.
- **Support URL:** /support.
- **Marketing URL** (optional): https://knifeandaxethrower.com
- **Licence agreement:** Apple's standard EULA. Our Terms of Service are also linked in the app.
- **Sign-in for App Review:** not needed while builds have no accounts. With accounts, give a demo account.

## Google Play Console → Data Safety

**Does the app collect or share any of the required user data types?** Yes. Data is collected only with an optional account; nothing is shared.

**Is all collected data encrypted in transit?** Yes (HTTPS to AWS).

**Can users request that their data be deleted?** Yes: in the app (Delete account), or at https://knifeandaxethrower.com/delete-account.

**Data types collected:**
- **Personal info → Email address**
  - Collected; not shared.
  - Optional (only with an account).
  - Purposes: App functionality, Account management.
- **Personal info → User IDs**
  - Collected; not shared.
  - Optional.
  - Purposes: App functionality, Account management.
- **App activity → Other user-generated content** (backed-up sessions and player names)
  - Collected; not shared.
  - Optional.
  - Purpose: App functionality.

**Not collected:**
- **Photos and videos:** the camera picture is processed on the device only. Google's definition excludes data processed only on the device.
- Location, financial info, health, messages, contacts, app info and performance, device IDs.

**Other Play Console fields:**
- **Privacy policy:** /privacy.
- **Account deletion URL** (Play's "Delete account" requirement): /delete-account.
- **Data deletion URL** (optional): /delete-data.
- **Ads:** "No, my app does not contain ads".
- **Leaderboards:** not on Android yet (backlog #21). Posting to Play Games, or a website, will need this page updated.

---

## Age Rating (for Nigel to decide)

The app shows no violence. It's a scoring tool for knife and axe throwing, a sport with blades.

- **Apple's age rating questionnaire:**
  - No violence and no gambling. The app shows other players' Game Center nicknames on the leaderboard tables; Apple moderates nicknames. No other user content is shared between users.
  - Apple's newer questionnaire has a question on **weapons**. Knives and axes are thrown at targets as a sport. Answer as **"infrequent or mild"** realistic weapon references, or ask App Review.
  - **12+ is likely.** Our Terms already say under-18s use it only with a parent's permission and supervision.
- **Google Play (IARC questionnaire):** answer the weapons questions the same way. Expect a similar teen rating.

## Checklist Before a Release

1. The website pages are live and say the same as the app (the dates at the top).
2. App Store Connect:
   - App Privacy answers as above;
   - Privacy and Support URLs;
   - age rating;
   - Game Center leaderboard `ranked.3m.5x3` added to the version. The test leaderboard is never added.
3. Play Console:
   - Data safety answers;
   - privacy and account deletion URLs;
   - the IARC rating.
4. The build is from the **store** flavor and scheme: no test tools, no Live test recordings.
   - iPhone: `flutter build ios --config-only --release --flavor store`, archived from the **store** scheme and uploaded on its own. Android: `flutter build appbundle --release --flavor store` (or the store APK).
   - **Never a promoted beta or TestFlight build.** One uploaded build can be chosen for both TestFlight and the App Store, so pick only a build recorded as **store** ([[Mac Handoff]] records each build number as beta or store).
   - Before the Mac has the store scheme, no store build can be made for the iPhone. Don't submit one ([[Design Decisions]] → Build Flavors: Beta and Store; [[Known Issues]] → `--dart-define` Carries Over).
5. If accounts are in the build: Delete account works in the app (device check), and App Review has a demo account.
