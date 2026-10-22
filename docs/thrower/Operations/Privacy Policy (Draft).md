# Privacy Policy (Draft)

**Status (2026-10-20):** superseded by the website's **`/privacy`** page (branch `website-dev`, `src/pages/privacy.md`), which expands this draft; on `dev.knifeandaxethrower.com` for Nigel to approve, then merged to `website`. This page is kept as the original draft. Earlier status: DRAFT for Nigel to approve (written 2026-10-19, accounts Task 5). Not published. Once approved, it goes on the website as `knifeandaxethrower.com/privacy` ([[Website Index]]), and its URL goes in App Store Connect and Google Play. **To fill in before publishing:** the contact email, the business or owner name, and the date.

Related: [[story-checkpoint-app-user-accounts]] (Task 5), [[Instructions and Safety]], [[Subscriptions]] (a later version must cover payments).

---

## Thrower: Privacy Policy

*Last updated: [date]*

Thrower scores knife and axe throws at a wooden target using your phone's camera. This policy says what the app keeps, where, and why.

### What stays on your phone
- **The camera picture.** The app looks at the camera picture on your phone to find the target and score throws. **Pictures and video are never sent anywhere** and are not saved, except the Live test recordings that come with the app.
- **Your games and player names.** Finished games (when, how they were played, the round scores, and the names you typed) and the names last used are kept in the app's own storage on your phone. Deleting the app deletes them.

### If you create an account (optional)
Everything works without an account. If you create one:
- **Your email address** and a password (or your Google or Apple sign-in) are used to sign you in. Sign-in is handled by Amazon Cognito. Passwords are not visible to us.
- **A backup of your games and player names** is kept with your account, so they come back on another phone.
- These are stored by Amazon Web Services in **London (UK)**. They are not shared with anyone else, not sold, and not used for advertising.
- The app has **no advertising and no analytics or tracking**.

### Game Center (iPhone, ranked games)
- At the end of a full ranked game you can choose **Post score**. Only then, the game's total is sent to Apple Game Center, where it appears on the leaderboard under your Game Center nickname for other players to see.
- Nothing is posted automatically, and no other data from the game is sent. Game Center is run by Apple under Apple's own privacy policy; you can sign out of it in the iPhone's Settings.

### Deleting your data
- **Delete account** (in the app: home screen → the person icon → Delete account) deletes your account and its backup straight away. Games on your phone stay until you delete them or the app.
- You can delete single games, or all of them, in History. While you are signed in, this deletes them from the backup too.

### Children
Thrower is for people old enough to take part in knife and axe throwing under their venue's rules. It is not directed at children.

### Contact
[contact email]

---

## Notes for Nigel (not part of the policy)
- **Store privacy labels**, from this policy:
  - **Apple:** "Contact Info: Email Address" and "User Content: Other User Content" (the games and names); linked to the user, not used for tracking. "Identifiers: User ID" (the Cognito ID).
  - **Google Play Data safety:** the same; data is encrypted in transit; users can request deletion (in the app).
- **Age rating** and an adults-only question: [[Instructions and Safety]] → Open Questions.
- **When subscriptions come** ([[Subscriptions]]): add purchases. Apple and Google handle payment details.
- **Game Center (2026-10-22, Review Agent):** App Store privacy labels: declare **User Content → Gameplay Content** (a posted ranked score), not linked to tracking. Android sends nothing new (the Play Games start-up pieces are removed from the manifest); the Play Data safety form is unchanged.
