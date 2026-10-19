# Story Checkpoint: App User Accounts (Accounts Stage 2)

## Story Goal
The app user can **sign in**, and their **history and player names are backed up** and come back on a new phone. Signing in is **never needed to score** (Apple's rule, and the [[Accounts Roadmap]]'s): the app asks for an account only when the user wants what it gives. The backend is **AWS Amplify** (Nigel, 2026-10-19: "stage two will always be AWS Amplify for me, use where_in_nz_v3 as a guide, as it has accounts already implemented"). Stage 2 of the [[Accounts Roadmap]]. Requirements: [[Player Names]] (names follow the user), [[Game Recording]] (history kept safe), [[Subscriptions]] (accounts come first), [[Instructions and Safety]].

## Complexity Score
9 (Large: full Story Agent protocol):
- layers: a new backend (`amplify/`), the auth edge (`lib/auth/`), sync over history and settings, and the UI (4);
- data models (user, game record, names) (1);
- native plugins and platform config (Amplify, Sign in with Apple, URL schemes) (1);
- platform, permission and secrets changes (1);
- more than 3 acceptance criteria (1);
- a stored-data change (history kept in two places) (1).

## Status
IN PROGRESS: Task 1 of 5 complete (2026-10-19), awaiting Nigel's checkpoint. Started on Nigel's "commit this and start stage 2".

---

## What WhereWillWeVisit Teaches (`C:\dev\flutter_projs\whereinuk\where_in_nz_v3`)
Read 2026-10-19: `amplify/auth/resource.ts`, `amplify/data/resource.ts`, `lib/main_support_utils.dart`, `lib/services/AuthService.dart`, `lib/utilities/account_deletion_flow.dart`, `docs/wherewillwevisit/Architecture/User Identity and Authorization.md`, `docs/wherewillwevisit/Troubleshooting/Known Issues.md`.

| Carry over | Where it is there | Note for Thrower |
|---|---|---|
| **Amplify Gen 2** backend in the repo (`amplify/backend.ts`, `auth/resource.ts`, `data/resource.ts`), `npx ampx sandbox` locally, `ampx pipeline-deploy` in the Amplify build | `amplify/`, `amplify.yml`, `package.json` (`@aws-amplify/backend` 1.22) | Same layout. Thrower needs no Java lambdas to start |
| **Cognito** sign-in: email, Google, **Sign in with Apple** (`defineAuth`, secrets via `secret(...)` in SSM, a custom URL scheme callback for mobile) | `amplify/auth/resource.ts` | Apple requires Sign in with Apple if Google is offered |
| **The user ID is the Cognito `sub`**, never an email hash | *User Identity and Authorization* → "Known incident: Apple sign-in silently created a second account" | Start right: no migration later |
| Flutter: `Amplify.addPlugin(AmplifyAuthCognito())`, `AmplifyAPI`, `Amplify.configure(amplifyConfig)`; the Hub's `signedIn` / `signedOut` / `sessionExpired` events | `lib/main_support_utils.dart`, `lib/services/AuthService.dart` | Thrower already has `AuthService` (interface) and `authServiceProvider`: an `AmplifyAuthService` implements it |
| **Account deletion** inside the app, with a warning that an Apple subscription must be cancelled in Settings | `lib/utilities/account_deletion_flow.dart` | Required by both stores. No subscriptions yet, so a simpler warning |
| **Ownership on the server** | Its custom resolvers take the caller's `sub` from the verified identity (CR-03) | **Simpler here:** Amplify Data **owner** rules (`allow.owner()`) on each model, so a user only ever reads and writes their own rows, with no custom resolvers. (Its models are mostly `allow.authenticated("identityPool")`, which lets any signed-in user read every row; they rely on resolvers instead) |
| Known issues | *Known Issues*: **SES sandbox** blocked sign-up confirmation emails (fixed for its account in `ap-southeast-2`); the Cognito console can't delete Google-linked users (use the CLI); `amplify_outputs` conflicts across branches | If the same AWS account and region are used, SES is already out of the sandbox |

---

## Answered (2026-10-19): "Stage 2 same as other project"
Read as: do it as WhereWillWeVisit does.
1. **Sign-in:** email, Google and Sign in with Apple.
2. **AWS:** the same account and region as WhereWillWeVisit (`ap-southeast-2`).
3. **Environments:** **dev and prod** Amplify branches (confirmed by Nigel, 2026-10-19). **Deployed by Amplify Hosting from GitHub:** Nigel creates the Amplify app on the repo, and Claude doesn't deploy a sandbox ("If you setup the aws amplify lambdas etc as needed I will create a git project in amplify using the git codebase which will deploy as needed").
4. **Subscriptions:** **not in this story** (confirmed 2026-10-19).
- **Region: London, `eu-west-2`** (Nigel, 2026-10-19: "I think the project will be in the london ap"; replaces Q2's region). The sign-up emails use Cognito's own email until SES gets production access in London ([[Known Issues]]).
5. **Backed up:** history and player names (WhereWillWeVisit has no equivalent; the recommendation stands).
6. **Sign-in screens:** `amplify_authenticator`, as WhereWillWeVisit.
7. **Apple and Google identifiers:** Nigel sets them up in the consoles, with Claude explaining, as for WhereWillWeVisit.

## Questions for Nigel (as asked, 2026-10-19)
1. **Sign-in methods at first:** email, Google and Sign in with Apple, as WhereWillWeVisit *(recommended: the same setup, done once)*; or **email only first**, with Google and Apple in a later task?
2. **AWS account and region:** the same account as WhereWillWeVisit, in `ap-southeast-2` *(recommended: SES is already out of the sandbox there, so confirmation emails reach real users)*; or a separate account?
3. **Environments:** one Amplify app with `main` as production and the **sandbox** for development *(recommended for now, as Thrower is `main` only)*; or dev and prod branches like WhereWillWeVisit's four?
4. **Subscriptions:** **not in this story** *(recommended: [[Subscriptions]] says don't start the 14-day clock before there's something to pay for; they come with the Game Centre)*; or in this story?
5. **What's backed up:** **history and player names** *(recommended)*; or history only?
6. **The sign-in screens:** Amplify's ready-made **`amplify_authenticator`** *(recommended: WhereWillWeVisit uses it; sign-up, confirmation code and password reset done and store-compliant)*; or custom screens?
7. **Apple and Google identifiers:** new Sign in with Apple Services ID and Google OAuth client for `nz.nrbond.thrower`. These are set up by Nigel in the Apple Developer and Google Cloud consoles, with Claude explaining (as for the Xcode work). OK?

## Acceptance Criteria (draft; settle with the answers)
1. Everything that works today works **signed out**: no sign-in prompt to score, play Quick draw or see History.
2. **Home → Account** (new): sign in or create an account (email; Google and Apple per Q1), see who's signed in, sign out.
3. Signed in, each finished game and the player names are **backed up**; with no signal they're kept and sent later (offline-first).
4. On a new phone, signing in **restores** the history and names (merged with anything already on that phone, no duplicates).
5. **Delete account** (Account screen, asks first) removes the account and everything backed up; the phone's own history stays, unless the user also clears it.
6. A user can only ever read or write **their own** data (owner rules), checked by tests against the sandbox.
7. The Instructions and a **privacy policy** say what's stored where. The store privacy labels are updated (Review Agent).

## Story Plan (draft: tasks change with the answers)

### Task 1: The Amplify backend and the app configured, nothing visible yet
- **Work:**
  - `amplify/` (Gen 2): `backend.ts`, `auth/resource.ts` (email first), `data/resource.ts` (empty or a placeholder model), `package.json`;
  - the sandbox deployed;
  - `amplify_outputs.dart` generated;
  - `pubspec.yaml`: `amplify_flutter`, `amplify_auth_cognito`, `amplify_api` (the versions WhereWillWeVisit runs: 2.7);
  - `main.dart` configures Amplify;
  - `AmplifyAuthService implements AuthService` (`currentUser`, `authStateChanges` from the Hub, `signOut`), wired into `authServiceProvider`;
  - platform minimums checked (iOS 15 already; Android `minSdk` 24 for Amplify).
- **Review Agent** (before committing): new native plugins, network access, the generated outputs file (no secrets in it), app size.
- **Verify:** tests with a fake `AuthService`; **Nigel:** the app starts on the Samsung exactly as before, and the sandbox is visible in the AWS console.
- **Plan change (2026-10-19):** no sandbox from the PC. Nigel connects the repo in the Amplify console, which deploys `amplify/` ([[Common Tasks]] → Connect the App to the Amplify Backend).
- **Status:** COMPLETE (2026-10-19), awaiting Nigel's checkpoint
- **What changed:**
  - **Backend** (`amplify/`, Gen 2, as WhereWillWeVisit):
    - `backend.ts` (`defineBackend({auth})`) and `auth/resource.ts` (`defineAuth`, email sign-in; Google and Apple in Task 3 once their secrets are set);
    - `tsconfig.json`, `package.json` (`"type": "module"`);
    - the root `package.json` (`@aws-amplify/backend` 1.22, `backend-cli` 1.8, `aws-cdk-lib`, TypeScript; `npm run typecheck`) and `package-lock.json`.
  - **`amplify.yml`:** the backend phase runs `npm ci` and then `npx ampx pipeline-deploy --branch $AWS_BRANCH --app-id $AWS_APP_ID`. The frontend serves `web_public/` (a holding page now, and the privacy policy's home from Task 5), since the app itself isn't a web app.
  - **`.gitignore`:** `node_modules/`, `.npm/`, `.amplify/`, `amplify_outputs.json`, `assets/config/amplify_outputs.json`.
  - **Flutter:**
    - `pubspec.yaml`: `amplify_flutter` and `amplify_auth_cognito` ^2.16.0 (2.7 first, then the newest 2.x), and the asset folder `assets/config/` (a README; the generated `amplify_outputs.json` goes there).
    - `lib/auth/amplify_accounts.dart`: `amplifyOutputsAsset`, `loadAmplifyOutputs(bundle)` (null without the file), `connectAccounts(outputs)` (adds `AmplifyAuthCognito` and configures Amplify; null if it can't), and **`AmplifyAuthService implements AuthService`**. `AppUser.id` is the Cognito `sub` (`userId`), never the email; the display name is the email. It follows the Hub's `signedIn`, `signedOut`, `sessionExpired` and `userDeleted` events; `signOut`.
    - `lib/providers.dart`: `authServiceProvider` is now `Provider<AuthService?>`, null unless connected (it used to throw "not chosen yet").
    - `lib/main.dart`: loads the settings, connects if present, and overrides `authServiceProvider`. Either way the app starts as before.
  - **Android:** `AndroidManifest.xml` declares `INTERNET`. Flutter only adds it to debug builds, and the Amplify plugins don't declare it, so release sign-in would have failed. `minSdk` was already 24 (Amplify's minimum); iOS is at 15.
  - **Docs:** [[Common Tasks]] → **Connect the App to the Amplify Backend** (the console steps for Nigel; generating the outputs per branch). [[Known Issues]]: Amplify applies the Kotlin Gradle Plugin (a warning now; future Flutter fails); INTERNET in release; Cognito's email limit until SES in London.
- **Verified by:**
  - `flutter test`: 771 passed (5 new); `flutter analyze`: no issues;
  - `npm run typecheck`: the backend compiles;
  - `flutter build apk --debug`: builds (after `flutter clean`) with the Kotlin warning only.
  - **Nigel:** the app runs exactly as before on the Samsung (no settings yet = signed out). Then create the Amplify app in London on the repo; the first build should deploy the Cognito pool.
- **Checkpoint saved:** 2026-10-19

#### Test Report — 2026-10-19 (Task 1)
- **New:** `test/auth/amplify_accounts_test.dart` (5): no settings in the build gives none; an empty file gives none; settings are read as they are; without settings no accounts; `authServiceProvider` is null unless main connects it.
- **Not unit-tested:** `AmplifyAuthService` itself, which wraps Amplify's static API. It's checked on the device in Task 2 (sign up, sign in and out against the deployed pool).
- **Results:** 771 passed, 0 failed.

#### Safety Report — 2026-10-19 (Task 1, Review Agent: plugins, platform config, a backend)
- **Files reviewed:** `pubspec.yaml` / `pubspec.lock`, `android/app/src/main/AndroidManifest.xml`, `amplify/**`, `amplify.yml`, `package.json`, `.gitignore`, `lib/auth/amplify_accounts.dart`, `lib/main.dart`, `web_public/index.html`.
- **§1 Permissions:**
  - ⚠️→✅ Android **INTERNET** is added. It's needed for sign-in, and it's normal and undangerous (no runtime prompt).
  - No new iOS permission strings; Cognito needs none.
  - Nothing else is added: the camera's audio and storage permissions stay removed.
- ✅ **§2 Parity:**
  - Android `minSdk` is 24 (Amplify needs 24); iOS 15 (Amplify needs 13).
  - **iOS is untested until the Mac runs `pod install`** for the new pods ([[Mac Handoff]]); on Android the debug build passes.
- ✅ **§3 Debug/release:**
  - No debug-only paths.
  - `connectAccounts` prints a failure with `debugPrint`, which carries no user data.
  - Release builds get INTERNET (above).
- ✅ **§4 Secrets:**
  - **No secrets in the repo.** `amplify_outputs.json` (pool IDs and endpoints; not secret, but per environment) is gitignored.
  - Google and Apple client secrets will live in the Amplify console's secrets (SSM) via `secret(...)` in Task 3, never in git. `node_modules/` and `.amplify/` are ignored.
- ⚠️ **§5 Privacy:**
  - **Nothing leaves the phone yet.** Without the settings file the app never contacts AWS, and even with it, only a user who signs in sends anything (their email and password to Cognito).
  - From Task 2, the store privacy labels and a privacy policy must cover the email address and account ID (Task 5).
  - `amplify_analytics_pinpoint` comes in with `amplify_flutter`, but **no analytics plugin is added**, so nothing is collected.
- ⚠️ **§6 Size:**
  - The Amplify plugins add native code: roughly a few MB on Android and iOS. Check the release size on the Mac's next archive.
  - Startup waits for `connectAccounts` only when settings exist (configure is local, no network).
- ✅ **§7 Physical:** no change to anything a thrower does.
- ✅ **§8 Rollback:**
  - The bundle and application IDs are unchanged.
  - Removing the Amplify packages rolls back cleanly; no stored data changes.
  - The Amplify app's Cognito pool lives in AWS and can be deleted from the console.
- **Verdict:** **OK to commit**, with two follow-ups: iOS `pod install` and a check on the Mac; the privacy policy and labels before any build with sign-in reaches testers (Task 5).


### Task 2: Home → Account: email sign-up, sign-in, sign-out
- **Work:** an Account screen (the `amplify_authenticator` per Q6), the signed-in state on Home, sign-out. Nothing else changes.
- **Verify:** widget tests (signed out, all of the app works; signed in, the Account screen shows the email). **Nigel:** create an account, confirm the emailed code, sign out and in.

### Task 3: Google and Sign in with Apple (per Q1)
- **Work:**
  - secrets (`GOOGLE_CLIENT_ID`/`SECRET`, `APPLE_*`) with `npx ampx sandbox secret set`;
  - the callback URL scheme (Android intent filter, iOS URL types);
  - the Sign in with Apple capability in Xcode (on the Mac, in the foreground: `docs/dont-ask-again.md`).
- **Review Agent:** `AndroidManifest.xml`, `Info.plist`, entitlements, secrets never in git.
- **Verify:** Nigel signs in with Google on the Samsung; the brother (or Nigel on the iPhone) with Apple.

### Task 4: Backup and restore of history and names
- **Work:**
  - models `GameRecord` and `PlayerNames` (owner rules) in `data/resource.ts`;
  - a sync layer behind the existing interfaces (`GameHistory`, `PlayerNamesStore`): the phone's files stay the source of truth; signed-in changes are queued and sent; on sign-in, the account's games are fetched and merged by `id`.
- **Verify:**
  - tests (merge without duplicates; offline queue; owner rules against the sandbox).
  - **Nigel:** play a game signed in; clear the app's data (or use a second phone); sign in, and History comes back.

### Task 5: Delete account, privacy, Instructions, docs, device checks, traceability
- **Work:**
  - **Delete account** (asks first): the account's rows, then `Amplify.Auth.deleteUser()`;
  - the Instructions (what an account does, that it's optional, deleting it);
  - a privacy policy page (hosted; the URL for the stores);
  - the store privacy labels;
  - docs: [[Design Decisions]], [[System Diagram]], [[Data Flow]], [[Glossary]], the web pages and the requirement pages (Docs Agent);
  - [[Device Test Plan]] → Account checks; [[Mac Handoff]] (a build with accounts);
  - the Traceability Agent.
- **Verify:** Nigel deletes a test account; it's gone from Cognito and the data table (CLI check, as WhereWillWeVisit's Common Tasks).

---

## Plan Changes Log
- **2026-10-19:** Planned while Nigel was away ("carry on till you get stuck"), from WhereWillWeVisit's accounts. Stuck at: seven questions and plan approval.

## Notes
- **Not in this story:** friends (stage 3), live sessions (stage 4), video (stage 5), the Game Centre and subscriptions (stage 6, [[Subscriptions]]).
- The `.claude/` and config commit rules apply: `amplify/` and `pubspec.yaml` are config; they're committed after the Review Agent passes.
