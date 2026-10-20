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
IN PROGRESS (2026-10-19, Nigel away: "make as much progress as you can … carry on with assumptions"). Tasks 1–2 done and committed. Task 3 is committed locally, **not pushed** (waiting for the six secrets). Tasks 4–5 are written and tested, unstaged, and deploy with Task 3. Deployed: Amplify app `d1yhmpx84pdvnh` (`thrower_app`, London), `main` built OK (job 4), Cognito pool `eu-west-2_TmfChXYyo`. Nigel signed up and in on the Samsung ("sign in works").

---

## What WhereWillWeVisit Teaches (`C:\dev\flutter_projs\whereinuk\where_in_nz_v3`)
Read 2026-10-19: `amplify/auth/resource.ts`, `amplify/data/resource.ts`, `lib/main_support_utils.dart`, `lib/services/AuthService.dart`, `lib/utilities/account_deletion_flow.dart`, `docs/wherewillwevisit/Architecture/User Identity and Authorization.md`, `docs/wherewillwevisit/Troubleshooting/Known Issues.md`.

- **Amplify Gen 2** backend in the repo (`amplify/backend.ts`, `auth/resource.ts`, `data/resource.ts`), `npx ampx sandbox` locally, `ampx pipeline-deploy` in the Amplify build
  - **Where it is there:** `amplify/`, `amplify.yml`, `package.json` (`@aws-amplify/backend` 1.22)
  - **Note for Thrower:** Same layout. Thrower needs no Java lambdas to start
- **Cognito** sign-in: email, Google, **Sign in with Apple** (`defineAuth`, secrets via `secret(...)` in SSM, a custom URL scheme callback for mobile)
  - **Where it is there:** `amplify/auth/resource.ts`
  - **Note for Thrower:** Apple requires Sign in with Apple if Google is offered
- **The user ID is the Cognito `sub`**, never an email hash
  - **Where it is there:** *User Identity and Authorization* → "Known incident: Apple sign-in silently created a second account"
  - **Note for Thrower:** Start right: no migration later
- **Flutter: `Amplify.addPlugin(AmplifyAuthCognito())`, `AmplifyAPI`, `Amplify.configure(amplifyConfig)`; the Hub's `signedIn` / `signedOut` / `sessionExpired` events**
  - **Where it is there:** `lib/main_support_utils.dart`, `lib/services/AuthService.dart`
  - **Note for Thrower:** Thrower already has `AuthService` (interface) and `authServiceProvider`: an `AmplifyAuthService` implements it
- **Account deletion** inside the app, with a warning that an Apple subscription must be cancelled in Settings
  - **Where it is there:** `lib/utilities/account_deletion_flow.dart`
  - **Note for Thrower:** Required by both stores. No subscriptions yet, so a simpler warning
- **Ownership on the server**
  - **Where it is there:** Its custom resolvers take the caller's `sub` from the verified identity (CR-03)
  - **Note for Thrower:** **Simpler here:** Amplify Data **owner** rules (`allow.owner()`) on each model, so a user only ever reads and writes their own rows, with no custom resolvers. (Its models are mostly `allow.authenticated("identityPool")`, which lets any signed-in user read every row; they rely on resolvers instead)
- **Known issues**
  - **Where it is there:** *Known Issues*: **SES sandbox** blocked sign-up confirmation emails (fixed for its account in `ap-southeast-2`); the Cognito console can't delete Google-linked users (use the CLI); `amplify_outputs` conflicts across branches
  - **Note for Thrower:** If the same AWS account and region are used, SES is already out of the sandbox

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
- **Status:** COMPLETE (2026-10-19); committed `21813f1`. Deploying needed: the lock file made with npm 10 (`8953499`), the service role `amplify-thrower-app-backend-role`, and CDK bootstrap of `eu-west-2` ([[Known Issues]]).
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

- **Status:** COMPLETE (2026-10-19); Nigel: "sign in works, commit this and continue to task 3".
- **What changed:**
  - `pubspec.yaml`: `amplify_authenticator` ^2.7.3 (Amplify's ready-made sign-in screens, as WhereWillWeVisit).
  - `lib/ui/account_screen.dart` (new): `AccountScreen` (`AuthenticatedView` around `_SignedInUser`, which follows `authStateChanges`) and `AccountDetails` ("Signed in as" the email; scoring works the same either way; **Sign out**). Without accounts: "Accounts are not available in this build."
  - `lib/ui/home_screen.dart`: an **Account** icon (`homeAccount`, top right), only when `authServiceProvider` isn't null.
  - `lib/main.dart`: `ThrowerApp` wraps the app in `Authenticator` when accounts are connected.
  - **Fixed after Nigel's check:** the first build used `Authenticator.builder()`, which puts the sign-in screens **in front of the whole app** whenever no one is signed in. Nigel: "Not super happy about having to login right from the start". That contradicts the story's rule (never needed to score) and Apple's 5.1.1. Removed: the sign-in now shows only inside the Account screen's `AuthenticatedView`. Reinstalled with `adb install -r` (data kept) for Nigel to recheck.
  - **Mistake on the device:** the first install used `flutter install`, which uninstalls first and wiped the Samsung's History and names. Told Nigel; installs now use `adb install -r`.
- **Verified by:** `flutter test`: 776 passed (5 new); `flutter analyze`: no issues. **Nigel (Samsung):** sign-up, the emailed code, sign-in and sign-out work against the London pool. **To recheck:** the app opens on Home signed out, and the sign-in shows only after tapping Account.
- **Checkpoint saved:** 2026-10-19

#### Test Report — 2026-10-19 (Task 2)
- **New:** `test/ui/account_screen_test.dart` (5): no Account button without accounts (Home as before); an Account button with them; the Account screen without accounts says so; signed in, it shows the email and that scoring works either way; Sign out signs out.
- **Not unit-tested:** Amplify's own sign-in screens (checked on the Samsung).
- **Results:** 776 passed, 0 failed.

#### Safety Report — 2026-10-19 (Task 2, Review Agent)
- ✅ `amplify_authenticator` is Flutter UI only, with no new native code or permissions.
- ✅ §5: the email and password go only to Cognito (London). Nothing new is stored by the app beyond Amplify's own secure session storage.
- ⚠️→✅ **Store rule (5.1.1):** the whole-app sign-in gate is removed (above). Signing in is optional again.
- **Verdict:** OK to commit.

### Task 3: Google and Sign in with Apple (per Q1)
- **Work:**
  - secrets (`GOOGLE_CLIENT_ID`/`SECRET`, `APPLE_*`) with `npx ampx sandbox secret set`;
  - the callback URL scheme (Android intent filter, iOS URL types);
  - the Sign in with Apple capability in Xcode (on the Mac, in the foreground: `docs/dont-ask-again.md`).
- **Review Agent:** `AndroidManifest.xml`, `Info.plist`, entitlements, secrets never in git.
- **Verify:** Nigel signs in with Google on the Samsung; the brother (or Nigel on the iPhone) with Apple.
- **Status:** IN PROGRESS (2026-10-19): the code is written (unstaged, **not pushed**: a deploy fails until the secrets exist). **Waiting for Nigel's console setup** ([[Common Tasks]] → Set Up Google and Sign in with Apple: a Google OAuth client, the Apple Services ID and key, the six Amplify secrets).
- **Written so far:**
  - `amplify/auth/resource.ts`: `externalProviders.google` and `signInWithApple`, with six `secret(...)`s (as WhereWillWeVisit), `callbackUrls: ['throwerapp://callback/']` and `logoutUrls: ['throwerapp://signout/']`.
  - `amplify/backend.ts`: **each branch's sign-in domain** from the first deploy: `throwerapp` (main) and `throwerapp-dev` (dev), both checked free in London. This follows WhereWillWeVisit's lessons:
    - a hash domain shows on Google's consent screen;
    - renaming one later takes two deploys.

    The construct's ID differs in this Amplify version (`<name>UserPoolDomain`), so it's found by its ending, and the deploy fails loudly if it's missing.
  - `android/app/src/main/AndroidManifest.xml`: an intent filter for `throwerapp` on `MainActivity`, and a `queries` entry for https (opening the browser).
  - `ios/Runner/Info.plist`: the `throwerapp` URL type. **The Sign in with Apple capability (entitlements, all three build configurations) is added in Xcode on the Mac.**
  - [[Common Tasks]] → Set Up Google and Sign in with Apple: the console steps, the redirect URLs per branch, the secrets, then Claude's finishing steps (Managed Login branding by CLI, as WhereWillWeVisit needed).
- **Committed locally, not pushed** (2026-10-19): it's backend and platform config, which may be committed after review, but pushing deploys, and the deploy fails until the six secrets exist. **Thrower's app has none yet** (checked: no `/amplify/shared/d1yhmpx84pdvnh/*`). Copying WhereWillWeVisit's values across was refused by the safety check (credential handling), so Nigel sets them. Push once they exist.
- **Safety Report (Task 3, Review Agent):**
  - ✅ §1: no new permissions. Android gets an intent filter for `throwerapp` (VIEW, BROWSABLE) and a `queries` entry for https, so the sign-in browser can open (package visibility).
  - ✅ iOS gets a URL type only; the entitlement comes in Xcode.
  - ✅ §4: secrets live only in Amplify's secrets (SSM), never in git.
  - ⚠️ §8: the sign-in domains (`throwerapp`, `throwerapp-dev`) are hard to rename later (two deploys).
  - **Verdict:** OK to commit.
- **Risks noted from WhereWillWeVisit:**
  - **Apple rejected its custom Sign in with Apple button (Guideline 4).** Check that the Authenticator's Apple button meets Apple's style before any store build (Task 5's review), and swap in Apple's official button (`sign_in_with_apple`) if not.
  - Each branch's domain must be on both Google's and Apple's lists, or that sign-in fails silently.
  - The Cognito console can't delete Google-linked users; use the CLI.

### Task 4: Backup and restore of history and names
- **Work:**
  - models `GameRecord` and `PlayerNames` (owner rules) in `data/resource.ts`;
  - a sync layer behind the existing interfaces (`GameHistory`, `PlayerNamesStore`): the phone's files stay the source of truth; signed-in changes are queued and sent; on sign-in, the account's games are fetched and merged by `id`.
- **Verify:**
  - tests (merge without duplicates; offline queue; owner rules against the sandbox).
  - **Nigel:** play a game signed in; clear the app's data (or use a second phone); sign in, and History comes back.

- **Status:** CODE COMPLETE (2026-10-19), unstaged. **Deploys with Task 3's push** (`backend.ts` now has `data`), so it waits on the secrets. Not yet seen on the phone.
- **What changed:**
  - **Backend:** `amplify/data/resource.ts` (new). Two models, each **owner-only** (`allow.owner()`, no custom resolvers):
    - **`KeptGame`**: `id` = `<sub>:<gameId>`, `gameId`, `finishedAt`, and `record`, the app's own `GameRecord.toJson()` as JSON, so the app's format can grow without a schema change;
    - **`PlayerNameList`**: `id` = `<sub>`, `names`.

    `backend.ts` adds `data`; the default auth mode is the user pool.
  - `pubspec.yaml`: `amplify_api` ^2.16.0.
  - `lib/history/synced_game_history.dart` (new): `RemoteGameStore` (interface: `list`, `put`, `remove`) and **`SyncedGameHistory`**, a `GameHistory` around the phone's file:
    - add, delete and clear also reach the backup (best effort, never failing the phone);
    - `sync()` merges both ways by game `id`.

    **Known limit:** a game deleted while signed out comes back at the next sync (no tombstones).
  - `lib/auth/amplify_backup.dart` (new): `AmplifyBackup` (`RemoteGameStore` and `PlayerNamesStore` on GraphQL, `erase`):
    - `put` creates, and updates if the row exists (a corrected game re-kept);
    - a game from a newer app version is skipped, not misread.
  - `lib/auth/amplify_accounts.dart`: `hasBackup(outputs)`. The API plugin is added only when the deployed backend has a data API; otherwise accounts work without the backup.
  - `lib/providers.dart`:
    - `signedInUserProvider`, the `Backup` record, `backupFactoryProvider` (`main` sets it when there's a backup) and `backupProvider` (the signed-in user's);
    - `gameHistoryProvider` is now `SyncedGameHistory`;
    - **`BackupNotifier` / `backupStatusProvider`:** on sign-in, the names (`PlayerNamesNotifier.syncWith`: an empty phone takes the backup's, otherwise the phone's are backed up) and then the games; `BackupOff`, `BackupRunning`, `BackupDone(result)` or `BackupFailed`; `backUpNow`;
    - names set while signed in are backed up too.
  - `lib/main.dart`: keeps the backup running app-wide (`ref.listen`).
  - `lib/ui/account_screen.dart`: the backup line (`backupText`) and **Back up now**.
- **Verified by:** `flutter test`: 800 passed; `flutter analyze`: no issues; `npm run typecheck`; `flutter build apk --debug`.
- **Plan change (2026-10-19):** Task 4 was done before Task 3 deployed, because Task 3 waits for the secrets. They deploy together.

#### Test Report — 2026-10-19 (Task 4)
- **New:** `test/history/synced_game_history_test.dart` (16, plus 2 for Task 5):
  - **signed out:** the phone only; nothing to sync;
  - **signed in:** a kept game is backed up; a re-kept game replaces its backup; delete and Clear history reach the backup; no signal keeps the phone's game and the next sync backs it up;
  - **sync:** a new phone gets the backup and the phone's games go up; twice in a row does nothing; no signal fails without touching the phone;
  - **the providers:** the backup is the signed-in user's, and none signed out; signing in merges and reports; a new phone takes the backed-up names; names are backed up, and later changes too; no signal shows, and Back up now retries.
- **New:** `account_screen_test.dart` (2): the backup text; Back up now (disabled while running, retries, hidden when off).
- **Not unit-tested:** `AmplifyBackup` (Amplify's static API): checked on the device (AC5–AC7).
- **Results:** 800 passed.

#### Safety Report — 2026-10-19 (Task 4, Review Agent)
- ⚠️ **§5 Privacy (the main change):** for the first time, **user data leaves the phone**: a signed-in user's kept games (scores, modes, dates, player names) and names, to AWS London.
  - Only after the user chooses to sign in.
  - The rows are owner-only (`allow.owner()`), and travel over HTTPS signed by the user's session.
  - The Instructions say so ("Your account"), and the privacy policy draft covers it.
  - The **store privacy labels must be updated before any store build with accounts** (Task 5).
- ✅ §1–§2: no new permissions; `amplify_api` adds no native code beyond Amplify's own.
- ✅ §4: no secrets; the GraphQL endpoint is in the gitignored outputs.
- ✅ §8: the phone's file format is unchanged (still `GameRecord` version 2). The backup stores the same JSON, and the app skips any record version it can't read.
- **Verdict:** OK to commit, with the privacy follow-ups in Task 5.

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
- **Status:** CODE COMPLETE (2026-10-19), unstaged; the privacy policy is a **draft** for Nigel.
- **What changed:**
  - **Delete account** (Apple 5.1.1(v), Google Play):
    - `AuthService.deleteUser` (`AmplifyAuthService`: `Amplify.Auth.deleteUser()`); `AmplifyBackup.erase` (every game, then the names row); `deleteAccount(ref)` / `deleteAccountProvider`: the backup is erased first, then the account. **The phone's History and names stay.** On no signal it throws and the account is still there.
    - The Account screen: **Delete account** (red), asking first ("Delete your account? … The games and names on this phone stay. This cannot be undone."); a message if it fails.
    - **Not wired (decided):** the account isn't deleted when the app is deleted (as both stores expect: the account is the user's).
  - **Instructions:** a new section, **Your account** (after History): optional; what's backed up; Delete account keeps the phone's games. History's privacy line now says "…sends it nowhere unless you sign in".
  - [[Privacy Policy (Draft)]]: for Nigel to approve. It covers camera pictures (never sent), the phone's games, the optional account (email, Cognito, the backup, AWS London), no ads or analytics, deletion, a children note, and notes for the store labels. **Not published** (it needs the contact email and owner name). Once approved it goes up as `web_public/privacy.html`.
  - [[Device Test Plan]] → **Account Checks** (AC0–AC8); [[Mac Handoff]] → section 00000 (`pod install`, the settings, the Sign in with Apple capability in Xcode, before any store build).
- **Verified by:** `flutter test`: 800 passed (5 new for Task 5: 3 dialog, 2 deletion, plus the Instructions test).

#### Test Report — 2026-10-19 (Task 5)
- **New:**
  - `account_screen_test.dart` (3): Delete account asks first and Cancel deletes nothing; confirmed, it deletes; no signal says so.
  - `synced_game_history_test.dart` (2): it erases the backup and then the account, and the phone keeps its games; no signal throws and the account stays.
  - `instructions_test.dart` (1): the Your account section.
- **Updated:** the section order (Your account after History) and History's privacy line.
- **Results:** 800 passed, 0 failed.

#### Doc Update — 2026-10-19 (Tasks 2–5, Docs Agent)
- **Files updated:**
  - `Architecture/Design Decisions.md` → User Accounts Required:
    - Task 2: sign-in only in the Account screen, and why not `Authenticator.builder()`;
    - Task 3: Google and Apple, six secrets, readable per-branch domains and WhereWillWeVisit's lessons, `throwerapp://`;
    - Task 4: the offline-first backup, owner-only rows, `id` = `<sub>:<gameId>`, the record as the app's own JSON, merge by id, delete and clear reach the backup, the known limit, `hasBackup`;
    - Task 5: erase, then the account; the phone keeps its games; the privacy draft.

    Game History also gets a backup update.
  - `Architecture/System Diagram.md`, `Data Flow.md` (new "Backup: Sign-In Merge and Each Kept Game") and `Glossary.md` (the components; the concepts Backup (owner-only), Offline-first, Merge by id, Sign-in domain, Return link).
  - The web pages (new flow `backup`).
  - Requirements: Game Recording, Player Names, Instructions and Safety, Subscriptions, Remote Play, the index.
  - The Accounts Roadmap.
- **Files created:** `requirements/Accounts and Sign-In.md` (🟡).
- **Drift:** the Instructions' "sent nowhere" line, fixed in code by the orchestrator (below).

#### Traceability Report — 2026-10-19 (Traceability Agent; story not complete)
- **AC1: everything works signed out**
  - **Implementation:** `authServiceProvider` (null), `connectAccounts`, `ThrowerApp` (`Authenticator(child:)`, no `builder`), `SyncedGameHistory` with no backup
  - **Test:** `amplify_accounts_test.dart` (2); `account_screen_test.dart` (no Account button); `synced_game_history_test.dart` (signed out ×2); **`widget_test.dart` 'with accounts, signed out: the app opens on Home, not a sign-in screen'** (added after the report)
  - **Status:** ✅ Covered (device: ACC0 to recheck)
- **AC2: Home → Account: sign up, in, out (email, Google, Apple)**
  - **Implementation:** `HomeScreen` `homeAccount`, `AccountScreen`, `AccountDetails`, `AmplifyAuthService`; `auth/resource.ts`, `backend.ts` domains, the `throwerapp` link
  - **Test:** `account_screen_test.dart` (4)
  - **Status:** ✅ Email (device ACC1 ✅); ✅ Google (device ACC3 ✅, 2026-10-20). ⛔ Apple: Xcode on the Mac (ACC4)
- **AC3: backed up; kept on the phone without signal and sent later**
  - **Implementation:** `SyncedGameHistory`, `PlayerNamesNotifier.set`/`syncWith`, `BackupNotifier`, `AmplifyBackup.put`/`save`
  - **Test:** `synced_game_history_test.dart` (signed in ×5; providers)
  - **Status:** ⚠️ "Later" means at the next sign-in, app start or Back up now (no automatic retry on reconnect). Device ACC5/ACC7 after the deploy
- **AC4: a new phone restores, no duplicates**
  - **Implementation:** `SyncedGameHistory.sync` (merge by id), `syncWith`
  - **Test:** sync ×3; providers ×2
  - **Status:** ⚠️ Names: the phone's win unless the phone has none (by design; the AC said "merged"). Device ACC6
- **AC5: Delete account removes the account and backup; the phone's history stays**
  - **Implementation:** `confirmAndDeleteAccount`, `deleteAccount`, `AmplifyBackup.erase`, `AmplifyAuthService.deleteUser`
  - **Test:** `account_screen_test.dart` (3); `synced_game_history_test.dart` (2)
  - **Status:** ✅ After a fix (below); device ACC8 with the CLI check
- **AC6: users only reach their own data**
  - **Implementation:** `KeptGame`, `PlayerNameList` `allow.owner()`; row ids `<sub>:…`
  - **Test:** none (no sandbox: Task 1's plan change)
  - **Status:** ⚠️ **Replaced by device check ACC9** (two accounts, CLI check)
- **AC7: Instructions, privacy policy, store labels**
  - **Implementation:** Your account section; `Privacy Policy (Draft).md`
  - **Test:** `instructions_test.dart`
  - **Status:** ⚠️ Instructions ✅; ⛔ the policy is a draft; ⛔ the labels (Nigel)

**Fixed straight after the report (2026-10-19):**
- **Delete account could leave data behind:** `AmplifyBackup.erase` went through `list()`, which skips games it can't read (a newer version's), so those rows would have outlived the account. It now lists **row IDs** and deletes them without reading the games.
- The Instructions' names line: "They are sent nowhere, unless you sign in (see Your account)", with its test and the Design Decisions quote.
- **New tests:** `hasBackup` (3); the app opening on Home with accounts (built under `runAsync`: Amplify's Authenticator starts a repeating timer); the known limit documented by a test (a game deleted with no signal comes back at the next sync).
- **Device checks renamed ACC0–ACC9** (they clashed with AC1–AC7). Added **ACC9**, a two-account owner check, and the CLI check in ACC8.

**Decisions for Nigel (from the report):**
1. **Deletes with no signal:** keep the limit (the game comes back), or remember pending deletes (tombstones)?
2. **A shared phone:** after A signs out and B signs in, the phone's games, including A's, go up to B's account. Is that intended (the phone's games are its owner's), or should each game remember which account kept it?
3. **Retry:** also try the backup when the app comes back to the foreground, not only at sign-in, app start and Back up now?

#### Cloud config (2026-10-20)
- Nigel asked which secrets Thrower needs, and whether they're new per app. **[[Cloud Config Setup]]** (new) documents the AWS pieces, the **six sign-in secrets**:
  - `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`;
  - `APPLE_TEAM_ID`, `APPLE_CLIENT_ID`;
  - `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`.

  For each: what it is, how to source it, and whether it's new for Thrower (all six are recommended new; the team ID is `QCQ64RLD77`). It also covers the future subscription config: Apple IAP on iOS, **Stripe on Android** (Nigel's requirement, backlog #15, with the Google Play policy check).
- WhereWillWeVisit's secrets audit: added to **its** Known Issues → Backlog as a cleanup item. The redundant-looking names are `AWS_REGION`, `AMPLIFY_APP_ID`, `APPLE_APP_ID`, `SUPPORT_EMAIL_ADDRESS` and possibly `DOCS_REVIEW_SESSION_SECRET` (unstaged in that repo, on branch `whereinnz`).

#### Decision (2026-10-20): nothing shared with WhereWillWeVisit
- Nigel: every secret is **new**. Nothing is reused from WhereWillWeVisit, even as a stopgap. [[Cloud Config Setup]] and [[Common Tasks]] now describe only the new path:
  - a new Google Cloud project and client;
  - a new Services ID and key in Thrower's team `QCQ64RLD77`;
  - later, Thrower's own IAP key and Stripe account.
- It's also a settled answer in both repos' `docs/dont-ask-again.md`.

#### Deployed (2026-10-20)
- Nigel created the Apple pieces with Claude in Chrome: Sign In with Apple on the App ID `nz.nrbond.thrower`; the Services ID **`nz.nrbond.thrower.signin`** ("Thrower", primary App ID Thrower's, both Cognito domains and `idpresponse` URLs); the key "Thrower Sign in with Apple" (Nigel downloaded the `.p8`). The Google client was made by Nigel.
- All six secrets set in Amplify (names checked, not values). **Job 7 succeeded**: the pool has Google and SignInWithApple, domain `throwerapp`.
- Managed Login branding created for the app client (`50cm62sqhgdihkh4l5vf9d4f6n`). Outputs regenerated (GOOGLE, SIGN_IN_WITH_APPLE); release APK installed with `adb install -r`.
- **ACC3 ✅:** Nigel: "google sign in works".

#### Still open in Task 5 (needs Nigel or the deploy)
- Approve and publish the privacy policy; the store privacy labels.
- Device checks AC0–AC8 (AC3–AC8 after the push).
- The Apple button's style (Guideline 4) before any store build.
- The Docs Agent's alignment and the Traceability report run now; the device results get added when they come.

---

## Plan Changes Log
- **2026-10-19:** Nigel away ("make as much progress as you can … carry on with assumptions"). Task 3 is committed locally, not pushed: Thrower has no secrets yet, and copying WhereWillWeVisit's values was refused by the safety check, so Nigel sets them. Tasks 4 and 5 were written meanwhile (unstaged) and deploy with Task 3. The privacy policy is a draft for Nigel.
- **2026-10-19:** Planned while Nigel was away ("carry on till you get stuck"), from WhereWillWeVisit's accounts. Stuck at: seven questions and plan approval.

## Notes
- **Not in this story:** friends (stage 3), live sessions (stage 4), video (stage 5), the Game Centre and subscriptions (stage 6, [[Subscriptions]]).
- The `.claude/` and config commit rules apply: `amplify/` and `pubspec.yaml` are config; they're committed after the Review Agent passes.
