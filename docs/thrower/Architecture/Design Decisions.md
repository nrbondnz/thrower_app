# Design Decisions

Each entry: **Decision**, **Rationale**, **Trade-off**, and the date Nigel confirmed it.

## Why Flutter?

**Decision:** Thrower App is a single Flutter codebase (`thrower_app`).

**Rationale:**
- Same stack as WhereWillWeVisit, so patterns, agents and know-how carry over
- One codebase for mobile, web and desktop

**Trade-off:** Platform-specific code needs conditional handling.

**Confirmed:** 2026-10-04 (project created with `flutter create`).

## What the App Does

**Decision:** The user sets up a phone on a **static** mount pointed at a wooden target and throws **knives or axes** at it. The app finds the target, detects where each throw lands, and records the score. (See Throwing Sport below.)

**Target model (initial, to be refined):**
- Circular, with 5 concentric rings in alternating colours so they can be told apart.
- Scores run from **5** for the innermost ring (bull) to **1** for the outermost ring.
- The camera will usually be off-centre, so the circle appears as an **ellipse** in the image and the app has to locate it rather than assume where it is.

**Confirmed:** 2026-10-04.

## Why iOS and Android Only?

**Decision:** Target platforms are iOS and Android.

**Rationale:** The app is camera-first and is used standing near a physical target, so it belongs on a phone.

**Done:** the `web/`, `windows/`, `macos/` and `linux/` folders and their `.metadata` entries were removed on 2026-10-04 at Nigel's request. To bring a platform back later: `flutter create --platforms=<name> .`

**Confirmed:** 2026-10-04.

## User Accounts Required; Backend and Payments Deferred

**Decision:** The app needs user accounts. The backend and payments are decided later.

**Rationale:** Nigel's call: get the core (vision and scoring) working first.

**Consequence:** Accounts depend on an auth provider, which is a backend choice. Until that's chosen, account and session handling sit behind an app-side interface (`AuthService`) so the provider can be plugged in later without touching the UI or scoring code.

**Backend decided (Nigel, 2026-10-19): AWS Amplify, always** (`docs/dont-ask-again.md`). Amplify Gen 2, following WhereWillWeVisit (`where_in_nz_v3`), which already has accounts: Cognito sign-in (email, Google, Sign in with Apple), the app's user ID is the Cognito `sub`, AppSync resolvers check the caller owns the data, and Apple purchases are verified server-side. It comes in at stage 2 of the [[Accounts Roadmap]]; `AuthService` stays the app's interface to it.

**How accounts grow** (2026-10-18): in stages, from friends kept on the phone with no sign-in (stage 1, next) to friends who sign in, join a session the host's phone runs, and own their throws and videos. See [[Accounts Roadmap]]. The backend comes in at stage 2.

**Built (Task 1, 2026-10-19; [[story-checkpoint-app-user-accounts]]):** the backend is in the repo and the app can connect to it. Tasks 2–5 follow below the Task 1 list: the Account screen (deployed), then Google and Apple, the backup and Delete account (written, waiting for the provider secrets before they deploy).

**Requirement:** [[Accounts and Sign-In]] (signing in, optional), [[Player Names]] (names follow the user), [[Game Recording]] (history kept safe), [[Subscriptions]] (accounts come before payments), [[Instructions and Safety]] (the Instructions say what's stored where). **Plan:** [[Accounts Roadmap]] → Stage 2.

- **The backend: Amplify Gen 2 in the repo.** `amplify/backend.ts` (`defineBackend({auth})`) and `amplify/auth/resource.ts` (`defineAuth`: a Cognito user pool, **email sign-in** for now). Laid out as WhereWillWeVisit's. Data models (history, names, owner rules) come in Task 4.
- **Deployed by Amplify Hosting from GitHub**, not from the PC (Nigel, 2026-10-19). Nigel connects the repo in the Amplify console; `amplify.yml` runs `npx ampx pipeline-deploy` for the branch being built. No local sandbox. *Why:* the deploy is the same every time, and nothing on the PC holds AWS credentials for it.
- **Two environments: `main` = production, `dev` = development** (Nigel, 2026-10-19), as WhereWillWeVisit (which has four). *Why:* sign-in and data changes can be tried on `dev` without touching real users' accounts.
- **Region: London, `eu-west-2`** (Nigel, 2026-10-19), in place of WhereWillWeVisit's `ap-southeast-2`.
- **Sign-up emails: Cognito's own email until SES** has production access in London. Cognito's sender has a low daily limit, enough for testing ([[Known Issues]]).
- **Email first; Google and Sign in with Apple in Task 3.** Their client secrets must be set in the Amplify console (`secret(...)`, kept in SSM, never in git) before the backend names them, or the deploy fails. Apple requires Sign in with Apple once Google is offered.
- **The settings ship as an optional asset**: `assets/config/amplify_outputs.json`, generated per branch and **gitignored** ([[Common Tasks]] → Connect the App to the Amplify Backend). `loadAmplifyOutputs` reads it; null if the build has none. *Why not WhereWillWeVisit's way:* there, the settings are a generated Dart file (`lib/amplify_outputs.dart`) the code imports, so a fresh clone doesn't compile until it's generated. As an asset, any clone builds and runs, signed out. One file per branch also avoids WhereWillWeVisit's `amplify_outputs` conflicts across branches.
- **`authServiceProvider` is `Provider<AuthService?>`: null means no accounts.** `main` calls `connectAccounts` and overrides the provider only when Amplify is configured. Null is never a gate: everything that works today works signed out (scoring, Quick draw, History). It used to throw "not chosen yet".
- **The user ID is the Cognito `sub`** (`AppUser.id` = Amplify's `userId`), never the email or a hash of it. *Why:* WhereWillWeVisit's "known incident": Sign in with Apple's relay email isn't stable, and a second account was created silently. Starting with the `sub` avoids a migration later. The display name is the email.
- **`AmplifyAuthService implements AuthService`** (`lib/auth/amplify_accounts.dart`): it follows the Hub's `signedIn`, `signedOut`, `sessionExpired` and `userDeleted` events. The rest of the app still sees only `AuthService`.
- **`web_public/` is the hosting frontend.** The app is a phone app, so Amplify Hosting serves only a small public site: a holding page. (The **privacy policy** the stores need was planned here; since 2026-10-20 it goes on the website instead: [[#Website: Astro, Orphan Branches in the Same Amplify App (2026-10-20)]].)
- **Android declares `INTERNET`.** Flutter adds it to debug builds only, and the Amplify plugins don't, so a release build couldn't sign in without it ([[Known Issues]]).

**Task 2 (2026-10-19, deployed; Nigel signed up and in on the Samsung): Home → Account.** Requirement: [[Accounts and Sign-In]].
- **Amplify's ready-made sign-in screens** (`amplify_authenticator`), as WhereWillWeVisit: sign-up, the emailed code and password reset, already store-compliant. *Not chosen:* our own screens (more to build and get wrong).
- **Sign-in shows only inside the Account screen** (`AccountScreen`: `AuthenticatedView` around the signed-in details). `ThrowerApp` wraps the app in a plain `Authenticator` (the state the view needs), never `Authenticator.builder()`. *Why:* the first build used `Authenticator.builder()`, which puts the sign-in screens in front of the **whole app** whenever no one is signed in. Nigel saw it on the Samsung ("Not super happy about having to login right from the start"). It broke the rule that signing in is never needed to score, and Apple's 5.1.1.
- **The Account button** (`homeAccount`, top right of Home) shows only when the build has accounts (`authServiceProvider` not null).

**Task 3 (2026-10-19, committed, not pushed: waiting for the six secrets): Google and Sign in with Apple.** Requirement: [[Accounts and Sign-In]].
- **Google and Apple together** (`amplify/auth/resource.ts`: `externalProviders.google`, `signInWithApple`). Apple requires Sign in with Apple once Google is offered. The client IDs, keys and secrets are six Amplify secrets (`secret(...)`), set by Nigel in the console, never in git. The deploy fails until all six exist, so Task 3 isn't pushed yet.
- **The return link is `throwerapp://`** (`callbackUrls: throwerapp://callback/`, `logoutUrls: throwerapp://signout/`): an Android intent filter on `MainActivity` (with a `queries` entry for https, so the browser can open) and an iOS URL type. The Sign in with Apple capability is added in Xcode on the Mac ([[Mac Handoff]]).
- **Readable sign-in domains, per branch, from the first deploy** (`amplify/backend.ts`): `throwerapp` (`main`) and `throwerapp-dev` (`dev`), in London. The domain construct is found by its ID's ending (`UserPoolDomain`), and the deploy fails if it's missing, rather than quietly keeping a hash domain. *Why (WhereWillWeVisit's lessons):*
  - Amplify's default hash domain shows on Google's consent screen ("to continue to 4642c8c2…");
  - Cognito allows one domain per pool, so renaming one later takes two deploys;
  - each branch's domain must be on both Google's and Apple's redirect lists (`https://<domain>/oauth2/idpresponse`), or that branch's sign-in fails silently;
  - the managed sign-in page's branding is a manual step after the first deploy ([[Common Tasks]] → Set Up Google and Sign in with Apple).
- **To check before any store build:** Apple rejected WhereWillWeVisit's own Sign in with Apple button (Guideline 4). If the Authenticator's button doesn't meet Apple's style, swap in Apple's official one.

**Task 4 (2026-10-19, written, deploys with Task 3): the backup of kept games and player names.** Requirement: [[Game Recording]], [[Player Names]].
- **The phone stays the source of truth (offline-first).** Venues often have poor signal. Every game is kept on the phone first; the backup follows. `SyncedGameHistory` (`lib/history/synced_game_history.dart`) is a `GameHistory` around the phone's `FileGameHistory`: add, delete and clear also reach the backup, without waiting and never failing the phone's own change. A backup that fails is caught up by the next `sync`. *Not chosen:* the backend as the history (nothing to show offline), or a queue of pending changes kept on the phone (more to build; the merge below catches up the same way).
- **Merge by `id` on sign-in.** `SyncedGameHistory.sync` brings games only in the backup to the phone (a new phone) and backs up games only on the phone. Running it twice does nothing. The names: an empty phone takes the backup's (`PlayerNamesNotifier.syncWith`); otherwise the phone's are backed up. `BackupNotifier` (`backupStatusProvider`) runs both on sign-in and shows how it went on the Account screen (`BackupOff`, `BackupRunning`, `BackupDone`, `BackupFailed`), with **Back up now** to retry.
- **Delete and Clear history reach the backup too.** Otherwise the next sign-in would bring every game back.
- **Known limit: a game deleted while signed out (or with no signal) comes back** at the next sync, as there are no tombstones (records of deletions). Accepted for now: deleting is rare, and History can delete it again.
- **Owner-only rows, no custom resolvers** (`amplify/data/resource.ts`: `allow.owner()`; the default auth mode is the user pool). A user can only ever read or write their own rows. *Why not WhereWillWeVisit's way:* its models are open to any signed-in user and rely on custom resolvers to check the owner (its CR-03); owner rules do the same with nothing to write.
- **Two models:**
  - **`KeptGame`**: `id` = `<sub>:<gameId>`, `gameId`, `finishedAt`, `record`. The `id` includes the Cognito `sub`, so two users' games that finished in the same microsecond can't collide.
  - **`PlayerNameList`**: `id` = the `sub` (one row each), `names`.
- **The record is the app's own JSON** (`GameRecord.toJson()`, its `version` inside), stored as `a.json()`. *Why:* the app's format can grow (as version 2 did for names) without a schema change. `AmplifyBackup` skips a record it can't read (from a newer app), leaving it in the backup.
- **`AmplifyBackup`** (`lib/auth/amplify_backup.dart`) is both the `RemoteGameStore` and the names' `PlayerNamesStore`, on GraphQL (`amplify_api`). `put` creates, and updates if the row exists (a corrected game kept again). Not unit-tested (Amplify's static API); the sync is tested with fakes.
- **The API plugin is added only when the deployed backend has a data API** (`hasBackup(outputs)`). *Why:* configuring `AmplifyAPI` against outputs with no `data` fails, and with it the whole of accounts. A build from before Task 4 deploys still signs in.
- **Wiring:** `signedInUserProvider` (who's signed in); `backupFactoryProvider` (set by `main` when there's a backup); `backupProvider` (the signed-in user's `Backup`: games, names, `erase`; null signed out); `gameHistoryProvider` is a `SyncedGameHistory`. `ThrowerApp` listens to `backupStatusProvider`, so the backup runs app-wide, not only on the Account screen.

**Task 5 (2026-10-19, written, deploys with Task 3): Delete account, privacy, Instructions.** Requirement: [[Accounts and Sign-In]], [[Instructions and Safety]].
- **Delete account inside the app** (both stores require it; Apple 5.1.1(v)). The Account screen's **Delete account** asks first (`confirmAndDeleteAccount`). `deleteAccount` erases the backup first (`AmplifyBackup.erase`: every game, then the names row), then the account (`AuthService.deleteUser` → `Amplify.Auth.deleteUser()`). *Why that order:* the rows are owner-only, so once the account is gone nobody could erase them. With no signal it fails, says so, and the account is still there to try again.
- **The phone keeps its games and names.** They were the user's before any account; deleting the app or Clear history removes them.
- **The account isn't deleted with the app** (as both stores expect: the account is the user's).
- **Instructions:** a new section, **Your account** (after History): optional, what's backed up, Delete account keeps the phone's games. History's privacy line: "…sends it nowhere unless you sign in".
- **A privacy policy draft** ([[Privacy Policy (Draft)]]): camera pictures never sent; the phone's games; the optional account (email, Cognito, the backup, AWS London); no ads or analytics; deletion. For Nigel to approve, then published on the website, `knifeandaxethrower.com/privacy` ([[Website Index]]), for the stores. The store privacy labels follow from it.

**Confirmed:** 2026-10-04 (accounts needed); 2026-10-19 (AWS Amplify, and Task 1's choices above; Task 2 checked by Nigel on the Samsung). Tasks 3–5 are written on the story's assumptions while Nigel was away; device checks AC0–AC8 in [[Device Test Plan]].

## Source Control: GitHub

**Decision:** The project is hosted on GitHub.

**Repo:** `thrower_app`, **private**.

**Branch model:** `main` only for now. Add a dev/prod split when there's a backend or release pipeline that needs one. **Update (2026-10-19):** the backend exists (AWS Amplify, above), so `main` is production and a `dev` branch is for development. `dev` is created when Nigel connects the Amplify app; it doesn't exist yet. **Update (2026-10-20):** two orphan branches for the website, `website` and `website-dev` (next section).

**Confirmed:** 2026-10-04.

## Website: Astro, Orphan Branches in the Same Amplify App (2026-10-20)

Requirement: [[Website]]. Details and setup: [[Website Index]].

**Decision (Nigel, 2026-10-20):** a public website at `knifeandaxethrower.com` (branch `website`) and `dev.knifeandaxethrower.com` (branch `website-dev`).
- **Astro + TypeScript, a static site.** *Why:* fast pages with little JavaScript, read well by search engines, content in Markdown or components, and room for interactive parts and the app's backend later (the Game Centre). *Not chosen:*
  - **Flutter web:** a multi-megabyte engine before the first page, poor for search, awkward for text-heavy pages;
  - **Next.js:** more than a mostly-content site needs, with server rendering to run and maintain.
- **Orphan branches** in the same repo: they hold only the site, never the Flutter app or `amplify/`. Never merged with `main`. On the PC the site has its own git worktree (`..	hrower_app-website`).
- **Branches of the existing `thrower_app` Amplify app**, next to `main` (Nigel: "in addition to main there would be website and website-dev"). Their `amplify.yml` is frontend only, so a website build never deploys or changes the app's backend. *Considered:* a separate Amplify app for the site (keeps the app's settings and secrets list apart); Nigel preferred one app with all the branches.
- **The privacy policy moves to the website** (`/privacy`), instead of `web_public/privacy.html` on the backend app's default domain: the stores get a stable URL on the app's own domain. `web_public/` stays as the backend app's holding page.

**Confirmed:** 2026-10-20.

## Vision and Timing Pipeline: On-Device, Separate from Scoring

**Decision:** Split the work into three layers that don't know about each other's internals:
1. **Camera**: streams frames.
2. **Vision**: finds the target (ellipse plus a rectifying homography to a top-down view) and detects impacts (when, and where in target coordinates).
3. **Scoring domain**: pure Dart. Maps a point in normalised target coordinates (centre 0,0, outer edge radius 1) to a ring score, and tracks throws, rounds and players.

**Rationale:**
- **On-device**, because impact timing needs low latency and it should work without signal. Cloud AI can still be added for analysis or calibration later.
- **The scoring domain is testable with no camera.** Vision outputs a point; scoring never sees pixels.
- **The vision approach can be swapped** (classical OpenCV-style ellipse fitting and frame differencing first, a trained ML model later) without touching scoring or UI.

**Trade-off:** More structure up front than a single camera screen. This is the "architectural purity" option.

**Confirmed:** 2026-10-04 (plan approved).

## State Management: Riverpod

**Decision:** Use `flutter_riverpod` (3.x). Layers are wired up in `lib/providers.dart`.

**Rationale:**
- Each layer (camera, vision, scoring, auth) is reached through a provider, so tests and debug screens can swap in a fake: recorded frames instead of the live camera, a fake `AuthService`.
- Handles streams (camera frames, throw events) well.
- Errors are caught at compile time, not looked up at runtime.

**Trade-off:** More concepts to learn than `Provider`/`ChangeNotifier`. Code generation isn't used yet, to keep the build simple.

**Confirmed:** 2026-10-05 (Nigel chose it over Bloc and Provider).

## Code Layout: One Folder per Layer

**Decision:**

- **`lib/scoring/`**
  - **Layer:** Scoring domain
  - **Rule:** **Pure Dart**: no Flutter imports, no pixels. `TargetModel`, `TargetPoint`, `Ring`, `LineTouchRule`.
- **`lib/auth/`**
  - **Layer:** Accounts
  - **Rule:** `AuthService` interface and `AppUser`. `amplify_accounts.dart`: `loadAmplifyOutputs` (the `assets/config/amplify_outputs.json` settings, or null), `connectAccounts` (configures Amplify; null if it can't) and `AmplifyAuthService` (Cognito sign-in; `AppUser.id` is the Cognito `sub`). An edge folder like `lib/camera/`: the rest of the app depends on the interface. `authServiceProvider` is null when the build isn't connected (signed out). Since 2026-10-19 ([[story-checkpoint-app-user-accounts]]). The backend itself is in `amplify/` (TypeScript, outside `lib/`).
- **`lib/camera/`**
  - **Layer:** Camera
  - **Rule:** `CameraFrame` (plugin-independent pixels + timestamp), `CameraSource` (interface: `frames()`), `TargetCamera` (a `CameraSource` the screens use: upright rotation, zoom, `minChange`, `now`: the clock its frames are stamped with), with two implementations: `LiveCamera` (the `camera` plugin's back camera; `open(fps:)`) and `RecordedCamera` (a Live test recording, `FramePack`, with an optional `RecordingSound`; `Recording.go`). `RecordingAnalysisFeed` (every frame of a recording, in order, timed by its place in the clip, for analysis; Quick draw). `CroppedCamera` (a part of another camera's picture as a camera of its own, cut in the sensor's layout; Quick draw, one per board; `compactFrame`). `QueuedCamera` (every frame of a crop, kept and handed on in order, falling behind rather than skipping; 75 MB cap; the live Quick draw). `AssetRecordingSound` plays a recording's sound track (`audioplayers` plugin). `FrameRateMeter`. Vision depends on `CameraSource`/`CameraFrame` only, never on the plugin.
- **`lib/vision/`**
  - **Layer:** Target finding, throw detection
  - **Rule:** **Pure Dart, no Flutter imports.** `RgbImage`, `LumaImage`, `Ellipse`/`fitEllipse`/`fitEllipseRansac`, `TargetLocator` → `ColourRingLocator` (via `buildTargetLocator`), `TargetCalibration`, `zoomToFit`, `MotionDetector`, `classifyThrow`, entry points (`GeometricEntryEstimator`, `faceOnEntry`), `image_difference.dart`, `SyntheticTarget` (test scenes with known answers), `decodeToRgb`, `locateTargetAt` / `locateTappedInFrame` (find the board at a tap, Quick draw; the tap is a fraction of the upright picture).
- **`lib/game/`**
  - **Layer:** Watching a game
  - **Rule:** Joins camera and vision: `ThrowWatcher` (frames → `ThrowEvent`s), `ThrowTracker` (knives in the board, visit cool-down), `findTarget` (Find target with zoom), `WatchDebugLog`, `QuickDrawTargets` (Quick draw's boards, in tap order; `locateAtTap`, `boardAt`), `QuickDrawWatcher` (a crop and a `ThrowWatcher` per board, with a `QueuedCamera` between for the live camera (`queue`); `states`, `queues`; `QuickDrawThrow`), `judgeQuickDraw` (Quick draw's winner rule; `QuickDrawVerdict`), `StartSignal` (Quick draw's start signal: `StartSchedule`, `startPauses`, `StartPhase`; go on the camera's clock).
- **`lib/sound/`**
  - **Layer:** Sound
  - **Rule:** `SignalSounds` (interface: Quick draw's `beep`, `go`, `result`) and `AssetSignalSounds` (the bundled `assets/sounds/` WAVs, made by `tool/make_signal_sounds.dart`, on the `audioplayers` plugin). An edge folder like `lib/camera/`: `lib/game/` depends on the interface; tests use a fake.
- **`lib/history/`**
  - **Layer:** Game history
  - **Rule:** `GameRecord` (a finished game: when, mode, rounds, each player's round totals, the names (since version 2), the Live test recording if any; JSON, `version` 2) and `GameHistory` (interface: `load`, `add`, `delete`, `clear`) with `FileGameHistory` (one JSON file, `game_history.json`, in the app's support folder via `path_provider`). An edge folder like `lib/camera/`: the rest of the app depends on the interface; tests use a temporary folder. Since 2026-10-16 ([[story-checkpoint-game-history]]).
- **`lib/settings/`**
  - **Layer:** Settings kept on the phone
  - **Rule:** `PlayerNamesStore` (interface: `load`, `save`) with `FilePlayerNamesStore` (`player_names.json` in the app's support folder): the player names last used. An edge folder like `lib/history/`. Since 2026-10-19 ([[story-checkpoint-named-players]]).
- **`lib/ui/`**
  - **Layer:** Screens and painters
  - **Rule:** Depends on the layers through providers. `HistoryScreen` and `GameRecordScreen` show the kept games. `RoundMarks` holds the Play screen's marks for the round. `CameraView` takes the camera to show as a `camera:` provider (default `cameraProvider`). `quick_draw_boards.dart` holds what both Quick draw screens share: `BoardChoosing` (with `playerNames`), `BoardsOverlay`, `BoardsPainter`, `boardLines`, `quickDrawLine`, `NamesButton` / `editPlayerNames`. `LiveQuickDrawScreen` runs the live duel (start signal, result panel).
- **`lib/providers.dart`**
  - **Layer:** Wiring
  - **Rule:** One place to see and override every layer.

Folders are created when their first code arrives, never empty "just in case". Navigation is plain `Navigator` until there are enough screens to justify a router.

**Confirmed:** 2026-10-05.

## Named Players (2026-10-19)

**Decision (Nigel, 2026-10-19; [[story-checkpoint-named-players]], stage 1 of the [[Accounts Roadmap]]):** players can be given names in place of "Player 1" and "Player 2". A name is **a label on a seat** for a game: named players "just have scores (they could just as well be player 2)". There's no player list, no history of their own and no ID. Friends, with their own accounts, come in stage 3.

**Requirement:** [[Player Names]] (Basic setup). **Plan:** [[Accounts Roadmap]] → Stage 1.
- **Names are part of the game:** `Match.names` (a name or null per player), `nameOf(i)` (the name, or "Player i+1": `playerNumber`), `withNames` (the same game, renamed). Every screen and the history record read names from the game, so they can't disagree. Renaming during a game doesn't restart it (`GameNotifier` listens to `playerNamesProvider` and calls `withNames`); **New game** keeps the names. *Not chosen:* names in the UI only, passed to every text function, which would have left the history record to be told separately.
- **`cleanName`:** trimmed; blank is none; at most **16 characters** (`maxNameLength`), so Play's large "Mark's turn", read from the throwing line, still fits. Two seats with the same name are allowed.
- **The last names used are kept on the phone** (Nigel's answer): `PlayerNamesStore` / `FilePlayerNamesStore` (`lib/settings/`, `player_names.json` beside the history, safe writes), loaded by `playerNamesProvider` at start (two seats; names set before the file loads win) and saved on each change.
  - A file that can't be read gives no names, and the next save replaces it. A save that fails is ignored. They're a convenience, so nothing else depends on them.
- **History:** `GameRecord` **version 2** adds `names` (written only when someone has a name). Version 1 files read as before (no names: Player 1 / Player 2), and the next save writes version 2. An older app (a TestFlight build before this) would set a version 2 history aside (renamed, not deleted), as it does for any newer version.
- **Privacy:** names stay on the phone, in the app's private folder, and are deleted with the app. Nothing is sent.
- **Shown (Task 2):**
  - **The setup screen:** "Name(s) (optional)", a field per player (hint "Player N", 16 characters at most, words capitalised), filled with the kept names (unless something's already typed). Start sets them (`playerNamesProvider.set`), which renames a game in progress rather than restarting it.
  - **Play and two-target Play:** `turnText` ("Jo's turn", "Wait for Sam", "Jo wins"), `turnDetail`, `playerTitle`; the board texts take the player's name (`boardMessage(player, …)`, `boardMovedMessage(player)`, `boardsStateText(states, names)`).
  - **Score-correction rows:** labelled by `rowLabel`: "P1" without a name, a name of up to 6 letters, or its first 5 and "…", so the row's slots keep their size.
  - **History:** `resultText` ("Sam wins 10–12"; one named player "Jo 27"), and each player's heading on a game's page.
  - The setup screen is now longer than a small landscape view: Start may need a scroll (tests scroll to it).
- **Quick draw (Task 3):** the same names as Play (Nigel's answer), changed on its screen before Start.
  - **No `Match` in Quick draw**, so the screens read the names straight from `playerNamesProvider`, through one getter on the shared mixin: `BoardChoosing.playerNames` ("Player N" for a blank seat). Two-target Play uses the same mixin, so its board choosing also says "Tap the centre of Jo's board". `choosingInstruction` uses it.
  - **The texts take names as an argument**, "Player N" without: `verdictText(v, names:)` (the recording's result line; `lib/game/` stays free of providers), `matchText(m, names)` ("Sam leads 2–0", "Sam wins the match 2–1"), `QuickDrawResultPanel(names:)` (`headline`: "Sam wins", "Sam wins on score"). `QuickDrawMatch` (pure Dart) still keeps rounds by seat number.
  - **The per-player lines keep "1:" / "2:"** (`judgedText`, `boardLines`): they match the numbers drawn in a disc above each board on the picture, and stay short at 34 pt.
  - **Names** (`NamesButton` → `editPlayerNames`): a dialog with a field per player (16 characters, words capitalised), filled with the current names. **Save** → `playerNamesProvider.set` (kept on the phone, as from the setup screen); **Cancel** changes nothing. Shown on both Quick draw screens whenever no round is under way (live: hidden once Start is tapped; the recording: before Play), so nobody goes to the phone mid-duel to rename. *Not chosen:* name fields always on screen (they'd cover the picture the boards are tapped on).
  - **A bug the tests found:** the dialog's text controllers were made and disposed by the caller, but the dialog's closing animation still used them after `showDialog` returned. The dialog (`_NamesDialog`, a `StatefulWidget`) now owns its fields and disposes them itself.
- **Instructions (Task 4):** *Playing a game* explains naming before Start and that the names are kept on the phone and sent nowhere; *Quick draw* points to **Names**. Details: Rounds and Scoring → In-app Instructions. Requirement: [[Instructions and Safety]].

## Game History: One File on the Phone, Behind an Interface (2026-10-16)

**Requirement:** [[Game Recording]] (scores kept); Finish game: [[Ending Early]].

**Decision** ([[story-checkpoint-game-history]], Nigel: "yes to all"):
- Finished games of Play are kept **on the phone**, in **one JSON file** (`game_history.json`) in the app's own **support folder** (`getApplicationSupportDirectory`: private to the app, not shown in the Files app; planned as the documents folder, changed because that one is meant for the user's own files). Behind the `GameHistory` interface, so a backend can keep them instead once there are accounts (backlog #4).
- **Why a file:** small, readable, testable with a temporary folder, no new native code. `path_provider` was already in the app through `audioplayers`; it's now listed in `pubspec.yaml` at the same version (2.1.6), so the lock file changes only from "transitive" to "direct main". *Not chosen:* `shared_preferences` (for settings, a new plugin), a database (`sqflite` / `drift`: a new native plugin, far more than a list of games needs).
- **The format:** `{"version": 1, "games": [...]}` (version 2 since 2026-10-19 adds each player's `names`: Named Players; version 3 since 2026-10-20 adds the game's `type`: More Game Types); each game has `id` (when it finished, in microseconds), `finishedAt` (UTC), `mode`, `rounds`, `players` (each player's round totals) and, for a Live test game, `recording`. Totals and the winner are worked out from the rounds, never stored, so they can't disagree.
- **Safe writes:** each save goes to `game_history.json.tmp`, then replaces the file; saves wait for each other. A file that can't be read (damaged, or from a newer version of the app) is **renamed** (`….damaged-<time>`), never deleted, and the history starts afresh; `GameHistoryException(setAside: true)` says so.
- **Kept:** finished games only, Live test games included (marked with the recording's name), all of them (each is well under 1 KB).
- **Privacy:** nothing is sent anywhere by the app. The file is part of the app's data, so it's in the phone's own backups (iCloud / Google, as the user has set them) and is deleted with the app.
- **Update (2026-10-19, [[story-checkpoint-app-user-accounts]] Task 4):** signed in, the kept games are also backed up to the user's account (`SyncedGameHistory` around `FileGameHistory`; the phone stays the source of truth). Signed out, nothing changes: nothing is sent. See User Accounts Required → Task 4.

- **When a game is kept** (Task 2): `GameNotifier` adds the `GameRecord` as soon as an event leaves the match over, without waiting for the save. It's kept **once**, under the time it finished (`clockProvider`), which is also its `id`; a last-round knife **falling out after the end** saves the same record again with the new score, replacing it. A reset or a game left half-way keeps nothing. A save that fails doesn't stop play: `historySaveErrorProvider` holds the reason and both Play screens show "Couldn't save this game to History."
- **The History screen** (Task 3): Home → **History** (`HistoryScreen`, `lib/ui/history_screen.dart`) loads the history each time it opens: newest first, one line per game ("16 Oct, 14:32", then "2 players, 1 target · 5 rounds · Player 1 wins 61–58"; "Live test: Target 1" for a recording). A game (`GameRecordScreen`): the result, each player's total and every round; **Delete** (the bin) removes it without asking (one game, reached on purpose); **Clear history** asks first. "No games yet"; "Couldn't load the history" with the reason and **Try again**. Dates are formatted by hand ("16 Oct, 14:32", 24-hour), so no `intl` dependency.
- The in-app Instructions have a **History** section (Task 4). Requirement: [[Instructions and Safety]].
- **Finish game** (Tasks 5–6, Nigel 2026-10-17: "There needs to be a button 'finish game' so games can finish after fewer rounds"): both Play screens have **Finish game** beside Reset game (greyed before the first throw, gone once over; asks first). `GameSession.finish()` / `Match.finish()` end the game now: a round in progress **counts**, with the throws made so far, as collecting early does. **Two players are judged on equal rounds:** `Match.countedRounds` is the fewest rounds any player has played, and the winner is on `countedTotals`; a round only one has played is shown "(not counted)" (so finishing straight after your own turn can't win the game). Chosen over totals as played (unfair) and allowing Finish only between rounds (on two targets, one player could have to wait). Play says "Game over after 2 of 9 rounds!", and with two players "Finished early: judged on 1 of 9 rounds." The game is kept in History like any other; History shows "2 of 9 rounds" and marks the uncounted round. **No file format change:** each player's list of rounds already shows how many were played, and `GameRecord.countedTotals` judges the same way.

**Built:** 2026-10-17, all 6 tasks ([[story-checkpoint-game-history]]); device checks H0–H7 in [[Device Test Plan]].

## Score Corrections: Tap a Score, Pause, Then Check the Phone (2026-10-17)

**Requirement:** [[Scoring Rules]] (score corrections), [[Round Play]].

**Decision** ([[story-checkpoint-score-corrections]], Nigel: "there could be times when a thrower misses the target alltogether, and possibly where they dispute the scoring so each score should be able to be pressed on giving a popup of 0-5 possible (hopefully without jogging the camera)"; three questions answered as recommended):
- **Any throw of the game being played can be changed**, and a throw the camera didn't see **added**. On Play, under the totals, the round in progress shows as three big slots per player (`ScoreCorrections`, `lib/ui/score_corrections.dart`); tapping a score opens a **0–5 popup** (0 and the `TargetModel`'s ring scores, as 64 px buttons, Cancel). The first empty slot (–) adds a throw, when it's that player's throw (`Match.nextThrowerAt`): **0 records a miss** (`ThrowResult.missed`; a knife that misses the board altogether usually gives the camera nothing to see), 1–5 a stuck knife the camera didn't register. **Rounds** opens an earlier round (to change a throw, or add one to a round collected early). Not in History: it keeps only round totals.
- **The rule** (`GameSession` / `Match`: `setScore`, `byHand`, `addToRound`): a changed throw keeps what the camera saw (`result`, `point`) with the new score, `ThrowRecord.corrected`; it shows light blue with ✎, on the slot and on the picture. A throw added by hand counts like a detected one: toward the round and, on one target, the turn; the last one ends the game. A correction after the end re-saves the kept game (same record, same time). A corrected knife that later falls out still scores 0.
- **The picture's marks remember which throw they are** (`RoundMarks` holds `ThrowSlot`s), and the painter reads the score from the `Match`, so a correction shows on the picture at once and the marks can't disagree with the scores.
- **Without jogging the camera:** the controls are **below the picture, never on it**, and big enough to tap lightly. **Watching pauses** while any popup is open (`ThrowWatcher.pause` / `resume`; on resume the motion detector starts afresh, `MotionDetector.restart`, keeping the knives it knows), so a hand at the phone is never a throw; a throw made meanwhile isn't scored (the instructions say so). **Then the app checks the phone didn't move:** 0.5 s after the popup closes, on a still frame, `cameraShift` finds the shift that best lines the picture up with the one from before the popup; **2 px or more** (at the watchers' ~320 px) is a move, and Play says "The phone may have moved. If the green rings no longer line up with the board, calibrate again when no one is throwing." (two targets: the board, and "choose the boards again"). 2 px because, measured: still Live test footage shifts by up to 1 px, Nigel's sofa-arm nudge of 2026-10-09 by 1.4 px, a knife or a person added by 0; and on boards of 40–65 px radius 2 px is a sixth to a quarter of a ring. The app doesn't re-find the rings itself: the user decides, as for "the view changed".
- **Safety (Review Agent §7):** this is the first control that invites someone to the phone mid-game. The Instructions say: only when no one is throwing (two targets: both finished), tap lightly, leave the phone where it is and never move it closer to reach it. Requirement: [[Instructions and Safety]].

## More Game Types: Precision and Three Targets (2026-10-20)

**Requirement:** [[Game Type]], [[Number of Rounds]]. **Story:** [[story-checkpoint-more-game-types]].

**Decision (Nigel, 2026-10-20; "We can worry about the camera later"):** two more games on Play, chosen under **Which game?** on the setup screen, beside **Scoring** (Play as it was):
- **Precision:** 7 rounds of 3 knives, each round from its own distance, `precisionDistances` = **3, 5, 7, 3, 4, 5, 7 m**. Nigel listed eight distances (3, 5, 7, 3, 4, 5, 6, 7) for seven rounds; these seven are his guess ("lets guess at 3,5,7,3,4,5,7"), to confirm. In competition the set is thrown 4 times (a marathon, 84 knives): backlogged, not built.
- **Three targets** (Nigel's name, in place of "Multi"): three 5-ring boards; each round one knife at each target, 1, 2 then 3; 3, 5 or 7 rounds.
- **Both:** 1 or 2 players, **taking turns** (`PlayMode.sharedTarget`: Player 1 throws 3 and collects, then Player 2); KATTA scoring (5 to 1, 0 a miss); the highest total wins.

### Scored by hand first, on a score pad
- **`ScorePadScreen`** (`lib/ui/score_pad_screen.dart`) has no camera: each knife's score is tapped on **`ScorePad`** (5, 4, 3, 2, 1 from the target model's rings, and **Miss**), which calls `GameNotifier.addThrow`.
- **Readable from the throwing line:** `padHeadline` in large type ("Mark's turn", "Collect your knives", "Mark wins"), and `padWhere` under it ("Round 2 of 7: from 5 m", "Round 1 of 3: at target 2").
- Each player's total and rounds (`padPlayerDetail`; Precision's with distances, "3 m: 12, 5 m: 9"), and Play's `ScoreCorrections` rows: tap a slot to change it. **Finish game** (asks first) and **New game** as on Play.
- **Why:** Precision moves the thrower between distances (the camera would need to follow one board from several throwing lines), and Three targets needs three boards watched at once. Both are new vision work; the games are useful now without it. *Not chosen:* waiting for the camera before offering them.
- **Safety (Review Agent §7):** scoring by hand brings someone to the phone after every knife. The screen and the Instructions say: score when no one is throwing, or have someone who isn't throwing keep score; never stand in the lane to use the phone.

### The type changes only where knives are thrown from, or at
- **`GameType`** (`lib/scoring/game_type.dart`, pure Dart): `scoring`, `precision`, `threeTargets`, each with its `label`, `roundChoices` ([3, 5, 9], [7], [3, 5, 7]), `defaultRounds` (the longest), `handScored` (all but Scoring; since 2026-10-22 Precision and Three targets only, as Ranked uses the camera: Ranked Games and Game Center), `distanceOf(round)` (Precision) and `targetOf(index)` (Three targets).
- **`Match.type`** is kept through every change (`withNames`, `finish`, each throw); `Match.nextDistance` and `Match.nextTarget` say where whoever throws next (`nextThrowerAt`) throws from or at.
- **The rules are reused unchanged:** `GameSession` (rounds of 3, finishing early, corrections) and `Match` (turns, counted rounds, winner, draw). *Not chosen:* a separate game class per type, which would have duplicated the turn and scoring rules and the history.
- **Wiring:** `gameTypeProvider` (`GameTypeNotifier`, Scoring unless chosen, kept for the session like `playModeProvider`). `GameNotifier` builds the match with the type and a length the type offers (else its `defaultRounds`); a change of type starts a new game; **New game** keeps the type.
- **The setup screen:** Precision and Three targets hide the target choice (two players always take turns) and show their own lengths (Precision "7 rounds", fixed); `typeDescription` explains them; **Start** opens the score pad.

### History: record version 3, `type` written only for the new types
- **`GameRecord` version 3** adds `type`. It's **written only for Precision and Three targets**, so a Scoring game is written exactly as version 2 wrote it. A missing `type` reads as Scoring, so version 1 and 2 files read as before.
- **An unknown type is a `FormatException`:** a game from a newer app. The History file and the backup already set such games aside (renamed, never deleted).
- **History shows the game:** `howText` leads with it ("Precision · 2 players, taking turns · 7 rounds"); `historyRoundLabel` adds Precision's distance ("Round 2 (5 m)").
- **The backup** carries the same JSON, so it needs no change.
- **The file's header says the oldest version that holds its games** (`FileGameHistory._versionFor`): **version 2** while every game is Scoring, so an older app (a TestFlight build before this one) still reads it; **version 3** once a Precision or Three targets game is kept, and an older app then sets the file aside (renamed, never deleted), as for any newer version. The backup's rows carry no version of their own, so there a Scoring game stays exactly as an older app expects. **Known limit:** an older app reading a Precision or Three targets game from the backup ignores `type` and shows it as a Scoring game.
- *Not chosen:* writing `type` on every record: it changes every Scoring game's JSON for no gain.

### Hand-scored games are never Live test games
- `GameNotifier._keep` leaves `recording` empty for a hand-scored game, even if a Live test recording is chosen: nothing was played on the recording, so History mustn't mark it "Live test".
- **Live test → Play on two targets** chooses Scoring again (a camera game), even if Precision or Three targets was played last.
- On the score pad, adding a throw in an empty slot asks "Add a throw (0: missed the board)" (`addThrowTitle`), not "A throw the camera missed".

**Instructions:** a section, *Precision and Three targets* (which game, the distances, one knife at each target, taking turns, the score pad, the safety line). Requirement: [[Instructions and Safety]].

**Built:** 2026-10-20 (Tasks 1–3); device checks GT0–GT9 in [[Device Test Plan]].

## Ranked Games and Game Center (2026-10-22)

**Requirement:** [[Rankings]] (first step), [[Scoring Rules]] (strict mode), [[Game Type]] (Ranked), [[Instructions and Safety]]. **Story:** [[story-checkpoint-game-center-scores]].

**Nigel, 2026-10-22:** "How can I set up Game Center to be able to store scores? There would be a best 3 meter score table refreshed each month, previous month results table etc. But to start I would just like to allow users to post scores for particular games, lets say 5 sets of 3 knives at 3 meters."

### Decided after the traceability check (Nigel, 2026-10-22)
- **Posting is the thrower's choice at the end of the game** ("The user should choose to post at the end of the game if they want to share their score"). Post score shows once the game is over, as built. **A posted score is final:** from the moment posting starts (`GameNotifier.markFinal`), a knife falling out no longer changes the game, so Play and History keep matching the leaderboard; if the post fails, falling out counts again. Before posting, a knife falling out still scores 0, and that lower total is what gets posted.
- **"5 sets of 3": every round needs its 3 throws** (`Match.postable`). A round collected early (fewer than 3 knives) leaves the game over but not postable until the missing knives are added as 0 (strict mode allows 0).
- **A "?" throw stays at 0** (a knife the camera saw stick but couldn't place): strict means no score is raised by hand, so a camera miss costs the thrower; the Instructions say so.
- **Update (2026-10-23):** a ranked round moves on after its 3rd throw, with no collecting: [[#Rounds Move On: Round Done (2026-10-23)]].
- Also fixed then: no Ranked on a Live test recording (and no posting from one); a post still going when New game is tapped doesn't touch the new game; a ranked game is always solo (`GameNotifier.build`); corrections are locked while posting too; View leaderboard signs in first and says if it can't open.

### Decision: one ranked game, Ranked: 5 × 3 at 3 m
- **`GameType.ranked`** ("Ranked: 5 × 3 at 3 m", `roundChoices` [5]): 5 rounds of 3 knives (0–75), **one player**, one target, **scored by the camera** (not the score pad: `handScored` is now Precision and Three targets only).
- **One player:** Game Center posts for whoever is signed in to Game Center on that iPhone, so a two-player game would have no one to post the second score for. `Match.postable` requires one player.
- **3 m is the thrower's word:** `rankedDistance` = 3; Play's setup asks **I'm throwing from 3 m** (`playRankedDistance`), and Start waits until it's ticked. The app can't measure the distance, as with Precision's distances. Play's title says "Ranked · 3 m" (`playTitle`).
- **Kept in History** like any game (`GameRecord` version 3, `type` "ranked"), and backed up when signed in. As for Precision, a file holding a Ranked game is version 3, so an app older than More Game Types sets it aside (renamed, never deleted).
- **Not on a Live test recording** (Task 5 fix, 2026-10-22): Play's setup leaves Ranked out while a recording is chosen, and Post score never shows for one: a recording's score isn't the thrower's.
- *Not chosen:* several ranked games (3, 5 and 9 rounds) at once: one leaderboard first; more later (backlog #22).

### Decision: strict mode (only 0 by hand)
- **Nigel:** "if they are posting to game centre they would have to go into a strict mode where they can only change scores to mark a bounce out but not to change scores to higher".
- **The rule, in pure Dart:** `GameType.strict` (Ranked only). `Match.setScore`, `byHand` and `addToRound` refuse any score but 0 in a strict game (`_refused`: the match comes back unchanged), so a raise is impossible whatever the screen does.
- **The screen:** the correction popup offers only **0**, with `strictNote` ("Ranked game: a score can only be changed to 0 (a bounce-out, or a miss)."), for a score, an empty slot and an earlier round.
- **Why 0 is still allowed:** a knife that bounced out or fell out after the camera scored it, or a knife the camera didn't see, must still be put right, and lowering a score can only hurt the thrower's own total.
- Elsewhere (Scoring, Precision, Three targets) corrections are unchanged (0–5).

### Decision: full games only
- **`Match.postable`:** `type == ranked`, one player, `isOver`, not `finishedEarly`. **Finish game** ends a Ranked game early, and it can no longer be posted (Nigel: full games only).
- **Why:** a leaderboard of totals only compares like with like if every game is 15 knives.

### Decision: posting behind `LeaderboardService`
- **`LeaderboardService`** (`lib/leaderboard/leaderboard_service.dart`), like `AuthService`: `signIn`, `submit(leaderboard, score)`, `show(leaderboard)`. `Leaderboard.ranked3m` carries the App Store Connect ID `ranked.3m.5x3`.
- **`leaderboardServiceProvider`** is null where the build can't post; `main` overrides it with **`GameCenterLeaderboardService`** only when `Platform.isIOS`. With no service, **`PostScorePanel`** shows nothing (Android).
- **`ScorePostNotifier`** (`ScorePost`: ready, posting, posted, signedOut, failed): signs in to Game Center first, then submits the total; a failure can be tried again; back to ready when a new game starts.
- **Why an interface:** the UI and the game never see Game Center, so tests use a fake, and the leaderboard can later be swapped for (or joined by) the app's own leaderboard on Amplify, shown on the website, ranking iPhone and Android together (backlog #21), without touching Play.

### Decision: a recurring monthly Game Center leaderboard
- Set up by Nigel in App Store Connect ([[Mac Handoff]] → Game Center setup): **recurring**, restarts each month, integer, high to low, range 0–75, best score.
- **Why:** Nigel's "best 3 meter score table refreshed each month". Apple restarts it and keeps each month's results, so "last month's results" (backlog #22) needs no backend.
- **View leaderboard** opens Apple's own leaderboard screen (`showLeaderboards`); no table of our own yet.

### Decision: post once; corrections locked after posting
- **Posted once:** `ScorePostNotifier.post` does nothing once `posted` (or while posting), and the button goes.
- **Locked after posting** (a plan change in Task 3): once posted, `ScoreCorrections` opens no slot, adds nothing and hides **Rounds**.
- **Why:** otherwise a correction to 0 after posting would leave the leaderboard higher than what Play and History show. A posted score is final.

### Decision: the plugin, `games_services` 5.3.0
- **Chosen:** `games_services` (published 2026-08-02; iOS 14+ pod, the app targets iOS 15): sign-in, `submitScore` and `showLeaderboards` on Game Center, used only inside `GameCenterLeaderboardService`.
- **Why:** a maintained, widely used plugin covers the three calls we need; behind our interface it can be replaced without touching the app.
- *Not chosen:* our own GameKit platform channel (Swift): more code to write and keep up on the iPhone, for the same three calls.

### Decision: the Android manifest removes Play Games' start-up pieces
- `games_services` also brings Google Play Games for Android, which would start at every Android launch (`PlayGamesInitProvider`) and wants an `APP_ID` the app doesn't have.
- **Review Agent fix (2026-10-22):** `AndroidManifest.xml` removes `PlayGamesInitProvider`, `GamesResolutionActivity` and the exported `PlayGamesAppShortcutsActivity` (`tools:node="remove"`). Checked: none left in the merged manifest; the app starts with no Play Games warning.
- **Why:** Android can't post yet (backlog #21), so Play Games would only cost start-up time and show warnings, and an exported activity is surface for nothing. Put them back when Android posting is built.

### Privacy
- Nothing goes to Game Center unless the player taps **Post score**: then only the game's total, shown publicly under their **Game Center nickname** (Apple's alias, not their name or email). Game Center is Apple's, under Apple's privacy policy.
- App Store privacy labels: **User Content → Gameplay Content** ([[Privacy Policy (Draft)]] → Game Center). Android sends nothing new.

**Instructions:** a section, *Ranked games* (the game, the 3 m confirmation, strict mode, full games only; and, added in Task 5, Post score and View leaderboard on an iPhone, signed in to Game Center, the total public under the Game Center nickname, the monthly restart, scores locked once posted, not on Android or a Live test recording).

**Built:** 2026-10-22 (Tasks 1–3, Task 4's PC side); waiting for the Mac and App Store Connect; device checks RK0–RK9 in [[Device Test Plan]].

## Camera: `camera` Plugin, Back Camera, No Audio

**Decision:** Use the official `camera` plugin (0.12) with the back camera at `ResolutionPreset.high`. Frames come as BGRA on iOS and YUV420 on Android. Audio is off. The live Quick draw asks for 60 fps (`LiveCamera.open(fps: 60)`; see Quick Draw: the Live Camera — 60 fps, Crops and a Queue); the rest take the phone's default rate.

**Permissions:**
- **iOS:** `NSCameraUsageDescription` ("Thrower App watches your target to score each throw."). No microphone string, because the app records no audio.
- **Android:** `CAMERA` only. The plugin also declares `RECORD_AUDIO` and `WRITE_EXTERNAL_STORAGE` (which implies `READ_EXTERNAL_STORAGE`); our manifest removes all three with `tools:node="remove"`. `ACCESS_NETWORK_STATE` (from `androidx.media3`, a no-prompt background permission) remains. `INTERNET` is debug-only.

**Lifecycle:**
- `cameraProvider` (was `liveCameraProvider`) is `autoDispose`: the camera is released when the screen closes or the app goes to the **background** (`paused`). It isn't released on `inactive`, because the permission prompt itself makes the app inactive.
- Coming back to the foreground re-opens the camera, which also picks up access granted in Settings.
- **No automatic retry** (Riverpod 3 retries failed providers by default; on Android that would re-show the permission prompt after "Don't allow"). The user retries from the error view.

**Denied access:** each `CameraFailure` gets a plain message. "Try again" is offered only where asking again can work (`denied`, `unknown`). Permanent denial points to Settings. No `permission_handler` package yet; add it if a direct "Open Settings" button is wanted.

**Confirmed:** 2026-10-05 (Task 4).

## Target Locating: Pure-Dart Two-Colour Rings

**Decision (Nigel, 2026-10-05):** Process images in **pure Dart** (no OpenCV, no ML model yet), behind the `TargetLocator` interface so either can replace it later.

**Rings can be any two colours (Nigel, 2026-10-05).** Boards are painted in any pair of alternating colours (red/wood, black/white, blue/yellow, …), so the locator **learns the two colours from the image** instead of using fixed thresholds. Nigel chose this over asking the user to pick the colours. The first version (Task 1) was hard-coded to red paint on bare wood.

**How `ColourRingLocator` works:**
1. Downscale to 600 px on the long side.
2. **Find candidate centres.** Reduce the image to an 8-colour palette (seeded k-means, so the result is repeatable). Merge palette colours closer than 45 RGB units, so one flat colour with sensor noise isn't split into speckles. The centres of the 12 largest single-colour regions (each at least 0.1% of the image) are the candidates. On a target, the bull's region and each ring's region are all centred on the target.
3. **Learn the colours per candidate.** Cast 72 probe rays. Colour **A** (the bull) is the median colour inside the first edge, where the colour changes by more than `edgeContrast` = 60 RGB units. Colour **B** is the median colour of the band where the next ring should be. Ratios along a ray through the centre survive an affine view, so that band sits at a fixed multiple of the bull's edge. The candidate is rejected if A and B differ by less than 60. The probes also give a rough target size.
4. Cast 180 rays from the centre. Along each ray:
   - Each sample is A, B or **neither** (more than 0.55 × the A–B distance from both). Blends along a sprayed edge always count as A or B. **"Neither" samples (handles, shadows, slots, bark, background) are gaps and are skipped.**
   - A majority filter puts sprayed, fuzzy edges at their midpoint.
   - The A/B runs (bull = A, then B, A, B, A) give the boundaries in order (0.2, 0.4, 0.6, 0.8).
   - A boundary hidden inside a wide gap (under a handle) is dropped for that ray.
5. Fit an ellipse per boundary with **RANSAC** (Halíř–Flusser direct fit), so bad rays are outvoted. Re-centre and repeat (3 passes).
6. Sanity-check each candidate's result (shared centre, growing outwards, roughly in proportion within 35%) and score it with a **confidence** (the share of ray samples on the fitted ellipses). The best plausible candidate wins; the search stops early once one passes 0.85.

**Known weakness:** a handle whose colour is close to one ring colour (dark handles on a black or dark-green board) counts as that colour rather than as a gap. RANSAC outvotes most of these rays. On the synthetic green-bull scene with handles, the fit stays within 3%.

**Measured boundaries, not ideal ones:** hand-painted boards aren't exact. On the reference photo the bull's edge is about 0.28 of the 0.8 edge rather than 0.25. The proportion check is therefore loose, and **scoring (Task 4) should use the measured boundaries**, not the ideal IKTHOF radii.

**The outer ring's outer edge isn't fitted.** On a log board the outer red often runs on to the bark, so `TargetFound.outer` is *extrapolated* (the 0.8 boundary × 1.25). **Open question for Nigel:** on his board, does ring 1 end at a painted line or at the board's edge? This decides how the outermost ring is scored.

**From camera frame to rings (Task 2):** `locateInFrame` (top-level, run with `compute`) does `frameToRgb` → `ColourRingLocator`.
- `frameToRgb` converts BGRA (iOS) or YUV420 (Android, U/V pixel stride 1 or 2) to RGB, downscales to 600 px on the long side (fractional step, sampled) and rotates upright in one pass.
- **Upright rotation** = `(sensorOrientation − deviceOrientation + 360) % 360` (`frameRotation`, `LiveCamera.uprightRotation`). This assumes stream frames arrive in sensor orientation on **both** platforms. Android is the usual case; **iOS is unverified until Nigel's device check**.
- **Overlay alignment:** the outline is drawn as `CameraPreview`'s `child`, which the plugin sizes and places exactly over the preview, scaled by preview width ÷ upright image width. This assumes the image stream and the preview share a field of view (same `ResolutionPreset`); checked by eye on the device.

**Performance:** about 270 ms on a PC for a 600 × 800 photo (130 ms when it was red-only; trying several candidate centres costs the extra). It runs in a background isolate on the phone; the device timing is still to be measured. That's fine for a one-off calibration; throw detection may need a smaller region of interest.

**Confirmed:** 2026-10-05 (plain-Dart image processing chosen by Nigel; algorithm from Task 1).

## Find Roughly, Then Look Closely (Coarse-to-Fine)

**Decision (Nigel, 2026-10-08, option 1 of 2):** All ring finding goes through `buildTargetLocator` = `CoarseToFineLocator(ColourRingLocator)`:
1. A rough pass on the whole (downscaled to 600 px) image. Its rejected attempt is enough to say where the board is. **If it returns nothing at all, it's retried once at 1200 px** (on the uncompressed 1× render with no knives, the 600 px pass found nothing, while the 1200 px pass gave a position that the close-up then found at 92%).
2. A crop of 1.8 × the target radius each side, from the **full-resolution** image.
3. A second pass on the crop, moved back into whole-image coordinates. If the close-up fails, the rough result stands.

The camera path keeps frames at full camera resolution for this (`frameToRgb(maxSide: 1920)`; 1280 × 720 at `ResolutionPreset.high`).

**Why:** from beside the throwing line (2 m to the side, 2 m out) the board fills only about 1/6 of the main camera's width. Once shrunk to the finder's 600 px, the bull was about 10 px across and knife handles swamped the rings. With knives in the board, the finder **failed on both 1× views** (rendered tests). Coarse-to-fine finds all six rendered views (78–93% confidence). The rejected alternative, telling users to use 2× zoom, depends on the phone and on the user. (Since 2026-10-11, the app zooms the camera in on the board itself after the first find; see Zoom the Camera onto the Target.)

**Dim or flat light (2026-10-08):** each pass is wrapped in `ContrastNormalisingLocator`. The image is tried as it is; **only if that fails**, it's retried with brightness stretched (1st/99th percentile → 0/255, the same map on all channels, so hues are kept). Found from Nigel's first real Android frame (A4 printout, indoors): the frame itself worked (97%), but at half brightness or half contrast it wasn't found, because the ring colours fell under `edgeContrast`. Stretched: 93% / 97% (30% brightness: 94%). It's a fallback, not the default: stretching also boosts white paper against a grey wall, which made the finder pick the paper when the target was cut off by the frame edge.

**Cost:** two passes, about 0.4–0.6 s on a PC for a 1600 × 1200 image (a third, larger pass only when the first finds nothing).

**Confirmed:** 2026-10-08.

## Adjust and Lock the Calibration

**Decision (Task 3):** after "Find target", the rings become a `TargetCalibration` (the ring ellipses + the upright image size) that the user can correct and then **lock for the session** (`calibrationProvider`, not auto-disposed; "Re-calibrate" unlocks). It's in memory only: a new app session calibrates again, since the phone may have been moved.
- **Adjustments act on all rings together**, driven by the outer ring: drag inside to move; drag the long-axis handle to turn and stretch; drag the short-axis handle to stretch the short axis. The rings stay in proportion and keep their perspective offsets.
- **A rejected attempt can be adjusted and locked too**, so a near miss can be fixed by hand rather than retried forever.
- **Safety (Review Agent §7):** whenever the outline can be adjusted, the screen shows *"Only adjust when no one is throwing."* The phone sits beside the board, so adjusting means standing near the throwing lane. Requirement: [[Instructions and Safety]].
- **Updated 2026-10-19 (the shared grab rule):** what a touch picks up is now `grabAt` (`lib/ui/calibration_editor.dart`), shared with the two-board editor (see Adjust Each Board). One change for the single target too: a handle wins only when the finger is **nearer the handle than the target's centre**. On a small target the handles' 32 px touch zones (`CalibrationEditor.handleReach`) reached its middle, so touching the middle grabbed a handle instead of moving the target.

## Zoom the Camera onto the Target (2026-10-11)

**Decision (Nigel, 2026-10-11):** *"on find it zooms to the target using camera zoom"*, using the camera's own zoom, **not** a crop of the picture. Built as Task 4 of [[story-checkpoint-live-test]], before throw detection, so knife detection is tuned on zoomed pictures.

**Why camera zoom:** frames reach the app at 1280 × 720 (`ResolutionPreset.high`) whatever the zoom. The phone zooms by cropping the sensor *before* that scale-down, or by switching to a telephoto lens, so a zoomed board gets several times more **real** pixels. A software crop would only enlarge the 720p pixels the app already has. The knives seen so far are small blobs (Live test footage) and the minimum-knife-size rule is marginal at small scales, so more pixels on the board helps every later step.

**How (`findTarget`, `lib/game/find_target.dart`):**
1. Zoom back to 1× (so **Find again** always starts from the whole picture) and find the rings.
2. `zoomToFit` (`lib/vision/zoom_to_fit.dart`) picks the zoom. The camera zooms about the **centre of the picture**, so the zoom is the smallest of:
   - the zoom at which the board fills **70%** of the picture's shorter side (`fill`), which leaves room for knife handles sticking out and for small nudges, which zoom makes bigger
   - the zoom at which the board, plus **0.3 × its radius** around it (`margin`), still fits in the picture: a board far from the centre limits the zoom (`offCentre`)
   - the camera's maximum (`TargetCamera.maxZoom`)

   A gain under **1.2×** (`minGain`) isn't worth searching again, so it gives 1×.
3. Zoom (`TargetCamera.setZoom`), wait **500 ms** for the frames to catch up, and find the rings again in the closer view.
4. If they aren't found zoomed in (or the camera refuses to zoom), go back to 1× and keep the first result.

**Off-centre board (Nigel's choice):** zoom as far as keeps the board in shot, and the status adds *"Centre the board in the picture for a closer view."* The status also says how far it zoomed ("zoomed in 2.4×").

**The zoom belongs to the calibration.** `CalibrationState.zoom` is kept through adjusting, locking and Re-calibrate. `cameraProvider` re-applies it whenever the camera reopens (for example, going from Calibrate to Play), because rings found zoomed in only line up at that zoom.

**Recordings can't zoom** (`RecordedCamera.maxZoom` = 1): their pixels are all there is, so the Live test is unchanged.

**Unverified until a device check:** that the camera plugin's `setZoomLevel` zooms the **image stream** as well as the preview, on both iOS and Android, and that 500 ms is long enough for it to show.

**Confirmed:** 2026-10-11 (placement and off-centre behaviour chosen by Nigel).

## Motion and Settle (Throw Detection, Task 2)

**Decision:** `MotionDetector` (pure Dart) works on **brightness only**, downscaled to ~320 px (`frameToLuma`: the Y plane on Android, converted BGRA on iOS), inside a `WatchRegion` = the locked outer ring's bounding box × 1.5 (room for handles). It runs about 15 times a second (`ThrowWatcher.interval`: a frame at most every 60 ms; Quick draw sets it to zero and looks at every frame).
- A pixel has **changed** if it differs from the previous frame by more than 6 × the estimated sensor noise, at least `TargetCamera.minChange` levels (12 for the live camera, 20 for a recording). The noise is learned while the board is still. **Each pair of frames also sets its own floor:** 5 × its robust noise (1.4826 × the median difference), so compressed video's whole-picture jumps don't count (2026-10-11; see Throw Detection on Real Footage).
- States: **watching → motion** (the **largest connected changed shape** ≥ 0.1% of the region) **→ settling** (< 0.05%) **→ settled** after 0.3 s still, reporting a `MotionEpisode`. Until 2026-10-11 this was the total share that changed (0.2% / 0.08%); one compact shape tells a knife from scattered compression blocks.
- **"Still" isn't "clear":** the rendered retrieval showed a person standing still at the board reads as settled. So the detector keeps a **reference** frame of the last settled board, and only settles when **< 8%** of the region differs from it; otherwise it's **blocked** (something in the way). After 5 s still but different, the view is accepted as the new normal (flagged), e.g. lights switched on.
- Each episode reports its **peak change** (a person: ~25%; a throw: ~0.6–1.5%) and its **change from before** (a stuck knife: ~0.6–0.7%; a bounce-out: 0.0%; knives removed: ~1.2%), the basis for telling stick from bounce-out (Task 3) and retrieval (Task 5).
- The knife's flight is effectively invisible (one faint blurred frame): **episodes start at the impact.** True side-on; not seen from behind the thrower (Quick draw), where the knife is over the board's face all the way in. So each episode also reports its **impact** (`MotionEpisode.impact` / `impactFrame`: the frame with the largest moving shape on the target); see Quick Draw: Timing and Scoring Each Board.

## Stuck or Bounced Off (Throw Detection, Task 3)

**Decision:** `classifyThrow(episode, calibration)` decides what a settled episode was:
1. Accepted as a new view → **scene changed** (not a throw; maybe re-calibrate).
2. Someone stood at the board (`wasBlocked`), ≥ 10% of the region changed at once, or one person-sized shape moved (`peakArea` ≥ 3% of the region, `visitArea`; see Throw Detection on Real Footage) → **board visit** (not a throw).
   - **Except a knife placed by hand** (decided 2026-10-09, so Nigel can test with a pen on the A4 printout): if the visit left a knife-sized new shape that **appeared** (`appeared`: the shape stands out from the board around it in the *after* picture, not the *before*), isn't one of the known knives and no known knife was taken out, it's a **stuck** knife and scores like a throw. A visit that removes knives the app never saw stays a board visit, because that shape disappeared.
3. Otherwise, pixels differing from the before frame by more than the episode's threshold are grouped into connected shapes (8-connected) within 1.5 × the outer ring. The largest one that touches the target (outer × 1.05) and covers ≥ **0.25%** and ≤ **6%** of the target's area (min 4 px) → **stuck**, with the shape kept for the entry point (Task 4). Otherwise → **bounce-out** (0), if a knife-sized shape was seen moving (`peakShape` ≥ 0.22% of the region), or else **nothing** (a flicker; ignored).

**Margins on the renders (320 × 180 frames, target ~46 × 33 px):** stuck knives make shapes of **84 / 68 px** against a 12 px minimum; the bounce-out **0 px**. Noise (σ 4) and a shape away from the target don't count.

**Falling out (Task 5):** a knife falling out on its own leaves a "new shape" where it was. `classifyThrow(knownKnives:)` compares the shape with the knives already in the board (kept by `ThrowTracker` until someone collects them). Overlapping one by ≥ 50% means **fell out**, not stuck, unless the shape **appeared** (head-on knives thrown side by side overlap; 2026-10-11).

## Throw Detection on Real Footage (Live Test, 2026-10-11; Full Resolution 2026-10-12)

**Goal:** the two Live test recordings give exactly the throws, bounce-outs and collections in Nigel's answer key (`reference/live-camera/truth.json`), checked by `test/game/live_replay_test.dart`, which replays every frame through `MotionDetector` and `ThrowTracker`. Before these changes, nearly every second was a false bounce-out, and board 2 was "blocked" for 49 s. Now both boards match (Task 5 of [[story-checkpoint-live-test]]).

**What the footage needed, and the rule each led to (all measured on the recordings):**
- **Compression jumps:** about once a second the encoder re-encodes the picture and every pixel shifts by a few levels (median difference 3–9 instead of ~0). → **Per-pair threshold** (`MotionDetector.pairNoise`): 5 × that pair's robust noise.
- **Re-encoded blocks:** when anything moves elsewhere in the video (board 2 being hit), board 1's picture gets mid-grey blocky changes: up to 12 px shapes at a 20-level floor, while every real throw made 20+ px. → **Motion = largest connected shape**, and a **minimum change of 20** for recordings (`RecordedCamera.minChange`). The live camera keeps 12: at 20, the rendered ring-3 knife (low contrast on paint) was missed.
- **Refocusing and people at the picture's edge:** soft, spread-out changes with nothing left behind. Real bounce-outs moved a 42+ px shape (0.26% of the region), the false ones 27 px or less. → A bounce-out needs `peakShape` ≥ **0.22%**; smaller is **nothing**. A person walking up moves 686 px (4.3%), and no knife more than 132 px. → `peakShape` ≥ **2%** is a **visit** (now judged by area, 3%: see below).
- **People walking back after collecting:** false events 0.6–1.6 s after a visit; the next real throw comes 6+ s after it. → `ThrowTracker.visitCooldown` **3 s**: anything but a stuck knife within it is part of the visit.
- **Small head-on knives:** before and after straddle a compression jump, so at 5 × noise (thresholds 30–44) three knives showed as only 9–12 px against the 12.6 px minimum. → The before/after comparison uses **3.5 × noise** (`settledNoiseFactor`); no bounce-out left anything behind even then. After a **visit** it stays at 5 × (`MotionEpisode.visitThreshold`), so marks left by collecting don't look like a placed knife; knives being **taken out** are still checked at the sensitive threshold.
- **The board re-exposing** made an 860 px "knife". → A knife covers at most **6%** of the target's area (the largest real one: 1.9%).
- **Knives side by side:** board 1's 140.5 s knife overlapped the 133 s one and was read as it falling out. → Fell out only if the shape **disappeared** (`appeared` is false).

- **Someone passing close to the camera** (board 2 at 97 s: a body filled the picture for 2.6 s) ended a round with one knife thrown. → A "visit" under **3 s** (`minVisit`) in which no one stood still and no known knife was taken is **nothing**. The shortest real collection took 3.9 s.

**Where a face-on knife went in (Task 6):** the side-view estimator decides which end is the handle from the board's tilt, which is noise on a face-on board (both recordings' rings are 0.95–0.97 as tall as wide), and it re-finds the knife by colour without the compression handling. On a **face-on** board (`isFaceOn`: short axis ≥ 0.9 × long axis), `faceOnEntry` takes the classifier's knife shape and uses its pixels **nearest the bull**. A camera in front of the board sees a handle lean away from the point it looks along (roughly the bull), and it's also the line rule (touching a line scores the higher ring).
- Against Nigel's scores (19 knives): **11 exact**, off by 12 rings in all. Alternatives: the shape's middle 11 exact (off by 13); the end along its axis nearer the bull 10; the side-view estimator 5–9.
- All but two are within a ring. The two are board 1 at 40.5 s and 43.2 s, where the changed shape isn't where Nigel places the knife (dark knives in the dark bull barely change the picture).
- At 140 px the rings are ~8 px apart and Nigel's own reading "is not always clear", so the replay test sets a floor (5 of 10 and 6 of 9), not a match.

**Confirmed:** 2026-10-11 (rules derived from the recordings; Nigel's device check pending).


**The original video (2026-10-12).** Re-cut at full resolution (boards ~245 px instead of 106), the recordings needed four more changes. Both now give every throw, bounce-out and round in the answer key:
- **Sizes in board length, not area.** A knife is a thin streak, so its pixel count grows with the board's size, not its area. Motion starts when the largest changed shape's pixels ÷ the watched region's side reach **0.12** (`startSize`; still below `stillSize` 0.06). That's 16 px on the copy, 33 px at full resolution, about 18 px on a phone. At 0.1% of the area, board 1's bounce-out at 177 s (a 39 px streak at 15 fps) fell short of the 77 px needed.
- **People are judged by area** (`MotionEpisode.peakArea` ≥ **3%** of the region; `visitArea`; it was 2% until 2026-10-14). On both versions people are 4%+ and knives at most ~1.1%, even when the board jolts on impact (800+ px at full resolution). Raised to 3% for the Quick draw clip, where a knife flying in close to the camera moved 2.2% (see Quick Draw: Timing and Scoring Each Board).
- **Bounce-out evidence must be on the target** (`MotionEpisode.peakShape`: the largest changed shape **touching the outer ring**, ≥ **0.12**; `bounceShape`). At full resolution, people moving at the edge of board 2's picture made shapes of up to 214 px but touched the target by 3 px at most. Every real throw's shape (138–852 px) touches it. `WatchRegion.target` carries the outer ring for this.
- **Ring finding: concentric refit.** On a face-on board, or when a fit is rejected because the ring centres disagree, a boundary whose centre strays more than 5% of its size from the others is refitted from only its points within ±12% of where the steadiest other boundary puts it. Board 2's hook and stand dragged its outer boundary 10 px off. Tilted boards keep their small perspective offsets.
- **Results:** rings found right every 10 s at 17 of 19 times (board 1) and 10 of 19 (board 2), against 13 and 8 on the copy. Knives scored exactly as Nigel did: **12 of 19** (11 on the copy). Nearest-the-bull is still the best entry rule (the middle of the shape: 9; the axis end: 7). Nigel's key was read from the copy, so some of the 7 differences may be the key's.
- **2026-10-13: the key re-scored from the original.** Nigel re-scored every stuck knife ("as close as I can get"), then reviewed the app's misses: three were his (now changed in the key), three are the app's. Now **16 of 19** exact (Target 1: 9 of 10; Target 2: 7 of 9; the replay test floors are 9 and 7). All three misses score too high: `faceOnEntry` takes the pixels nearest the bull, and a shadow pulls that in (board 1 at 2:17 and board 2 at 1:10 followed the shadow; board 2 at 1:46 put the tip in red where the board below it is white).
- **How Nigel scores a knife (the rule the app should follow):** "find the solid shape of the knife; score where the blade goes into the wood; a shadow comes from the knife, on the side away from the light". And: *"we need the app to focus on finding the entry point. If it's obscured, it's likely the score that you can see, as the knife has gone in directly in line with the camera."* Planned in [[story-checkpoint-entry-point]]; the misses and his reasons are in the Live Camera README → Answer Key.
## Rounds and Scoring (Throw Detection, Task 5)

**Decision:**
- **Single player, rounds of 3 throws** (Nigel). `GameSession` (pure Dart, immutable):
  - a throw is stuck (scored at its entry), a bounce-out (0) or fell out (0);
  - a stuck knife whose entry wasn't found counts as a throw, **unscored ("?")**;
  - a **board visit** (someone collecting the knives) closes the round;
  - throwing on after a full round starts the next round without waiting.
- **Assumed rule, to confirm with Nigel: a knife that sticks and then falls out (before being collected) scores 0.**
- Pieces:
  - `ThrowTracker` (pure): classification + the knives in the board.
  - `ThrowWatcher`: camera → detector → tracker → full-resolution entry, off the UI thread; emits `ThrowEvent`s.
  - `GameNotifier` (`gameProvider`): events → `GameSession`, scoring entries with `TargetMapping` + `TargetModel`.
  - **Play screen:** live picture, locked rings, round and game totals, and the round's marks (`RoundMarks`, since 2026-10-11): a yellow circle with its score where each knife went in, and a "0" beside the board for each bounce-out (or a stuck knife whose entry wasn't found, or one that fell out). Cleared when the knives are collected or the next round starts.
- **Safety:** at the end of a round the screen says *"Collect your knives when no one is throwing"*. It never says the lane is clear. Requirement: [[Instructions and Safety]].

**Update (2026-10-09, [[story-checkpoint-instructions-and-game-length]]):**
- **A game is a fixed 9 rounds** (`GameSession.maxRounds`, default 9). `isOver` = round 9 complete (3 throws, or closed early by collecting). Later throws are ignored: `GameSession` returns itself, and `GameNotifier` doesn't remember a post-game knife, so it falling out can't zero a real throw. A round-9 knife falling out after game over still scores 0. Play shows "Round N of 9"; at game over "Game over! Final total" with every round, plus a **New game** button.
- **Reset asks first:** the Play app-bar button is **Reset game** (disabled before the first throw) with "Reset this game? Scores will be lost." Chosen over an instant reset so a stray tap mid-game can't wipe the scores. *New game* at game over doesn't ask.
- **Update (2026-10-19, [[story-checkpoint-quick-draw-match]] Task 3):** the Quick draw section describes the **match** (three rounds, the round rule with the score tie-break, all three thrown, extra rounds when level, Finish match by the starter, knives collected together between rounds, then the starter taps Next round); Scoring names **KATTA**. Requirement: [[Instructions and Safety]].
- **In-app Instructions** (`lib/ui/instructions.dart`, *Instructions* on Home): **Requirement:** [[Instructions and Safety]]. Dart content, no Markdown package. Game length, throws per round, ring scores and the line-touch rule are read from `GameSession` / `TargetModel`, so the text follows the rules. Chosen over a Markdown asset (easier prose editing, but a new dependency and hand-typed numbers that drift). Keeping it current: [[Common Tasks#Update the In-App Instructions]]. Since 2026-10-15 it has a **Quick draw** section (how to choose the boards and play, the winning rule, and the safety points from the Review Agent's Quick draw Safety Report: "go" never means the lanes are clear, separate lanes, the phone out of both lines of throw); the paper version says Quick draw isn't played on paper. Rewritten for the live game (Task 5 of [[story-checkpoint-live-quick-draw]]): Home → Quick draw (Live test → Quick draw plays the recording); the phone on its stand **behind the throwers**, out of both lines of throw and not between the lanes; Start tapped from behind them; the start signal (five beeps with a light each, a pause that changes, the long beep is go); the result in large type with a chime, read from where you stand, nobody going to the phone during a duel; collect the knives together, then **Next duel**.
- **Two versions** (Nigel, 2026-10-09): **Real board** (default; the main one: 75–85 cm board, phone 2 m away out of the line of throw, lane safety) and **Paper target** (A4 printout at 100%, phone 50 cm away, pens in Blu Tack placed by hand, hand-wave = bounce-out, never throw at the paper). One page with a switch at the top (`InstructionTarget`), not two screens: calibrating, scoring, resetting and reporting are shared, so they can't diverge.
- **Update (2026-10-19, [[story-checkpoint-named-players]] Task 4):** Requirement: [[Instructions and Safety]], [[Player Names]]. *Playing a game* adds naming the players before Start (up to `maxNameLength` letters, read from the code; blank is "Player 1" / "Player 2"; the screens and History use the names, and Quick draw uses the same ones) and "The last names used are kept on this phone and filled in next time. They are sent nowhere, unless you sign in (see Your account)." (the last clause since accounts Task 4) *Quick draw* adds "Tap Names to change the throwers' names (the same names as Play).", next to choosing the boards, before anyone throws. The paper version gets the naming points too (they're shared); its Quick draw section is unchanged.
- **Update (2026-10-19, [[story-checkpoint-adjust-boards]] Task 2):** Requirement: [[Instructions and Safety]], [[Two Targets]]. *Two players on two targets* and *Quick draw* add "If an outline doesn't fit its rings, drag it into place (inside to move it, a white handle to turn or stretch it), or tap Choose boards again." Two targets adds "If a board or the phone is knocked during a game, tap Adjust boards when no one is throwing, drag the outline back, then Lock boards. Watching stops until you lock again; the scores stay." Quick draw adds "Between rounds, Adjust boards unlocks them to fix an outline (only when no one is throwing); the match carries on."

**Update (2026-10-16, [[backlog]] #5): the game length is chosen.** Nigel: "start on game lengths, then history". The Play setup screen (`PlaySetupScreen`) asks **How many rounds? 3 / 5 / 9** (`GameLengthNotifier.choices`), 9 unless chosen, kept for the session in `gameLengthProvider`. `GameNotifier` builds the `Match` with `GameSession(maxRounds: …)` for every player, and starts a new game when the length changes (like the mode); **New game** keeps the mode and length. Throws per round stay 3. Everything that shows the length reads it from the game (Play's "Round N of 5", game over, the Instructions' "A game is 5 rounds…"), so nothing else changed. Chosen over free entry or a slider: three lengths cover a quick game, a medium one and the full 9, and are big targets on a phone.

**Update (2026-10-15, [[backlog]] #12): the next round shows as soon as the knives are collected.** Play used to keep showing the collected round until the next round's first throw, because a round's record is only made by its first throw. `GameSession` now says where the game is:
- `awaitingNextRound`: the current round is closed (the knives were collected) and the game isn't over;
- `roundNumber`: the round being played, 1-based; the next one as soon as the knives are collected;
- `finishedRounds`: the rounds already collected (all of them once the game is over).

Play's `roundText` then shows the new round, empty ("Round 2 of 9: – · – · –  (0)"), and `gameText` drops "Round complete…" and lists the collected round under "Rounds:" straight away. No empty round is stored: the session's rounds are as before. Checked by `game_session_test.dart` and `game_notifier_test.dart`.

## Rounds Move On: Round Done (2026-10-23)

**Requirement:** [[Round Play]], [[Rankings]], [[One Target]], [[Two Targets]]. **Story:** follow-up to [[story-checkpoint-game-center-scores]].

**Nigel, 2026-10-23 (on the iPhone):** "3 scores should either move on automatically (in ranked) or offer a 'round done' for others."

**The problem:** a round only moved on when the camera saw someone at the board (a board visit), or when the next knife landed. Three bounce-outs leave nothing to collect, so Play stayed on "Round complete…".

### Decision: a ranked round moves on by itself
- **`GameType.movesOnByItself`** (Ranked only). In `Match._throw` (via `_movedOn`), a ranked round's 3rd throw closes the round (`GameSession.boardVisited`), so the next round shows straight away.
- 15 throws with no collecting is still a full game, and can be posted.
- The Instructions tell the thrower to collect the knives before throwing again.

### Decision: Round done for the other games
- **`Match.canEndRound`** and **`Match.endRound()`**; on the screen **`RoundDoneButton`** (key `roundDone`), on Play and two-target Play, under the score rows.
- It shows once the round has all its throws and hasn't been collected. It doesn't show once the game is over.
- **One target, two players:** it shows when the turn is complete, and passes the turn.
- **Two targets:** it shows only when every player still playing has finished the round (they collect together).
- **`GameNotifier.endRound()`:** the knives still on the board are remembered (a real board visit forgets them), so one that falls out later still scores 0.
- The score pad already moved on by itself, so it's unchanged.

### Why
- The camera can't see a collection that never happens. A button is the plain fix for a bounce-out round, or a visit the camera missed.
- Ranked moves on by itself because it is one player and always 3 knives a round (`Match.postable` needs them); a button there would be one more trip to the phone.
- *Not chosen:* moving on by itself in every game. With two players, or a thrower who collects early, the app can't tell whether the knives are still to be collected.

## Blade Entry Point (Throw Detection, Task 4)

**Decision (D1 option A, geometry):** `GeometricEntryEstimator` (behind `EntryPointEstimator`, so a trained model can replace it) works on **full-resolution** upright before/after pictures (the calibration's own size):
1. **Colour** change (largest channel difference > 20) near the target → the largest new shape touching it. **Not brightness:** shaded steel on red paint has almost the paint's brightness (the rendered ring-3 knife's blade vanished that way: 6.4 px off and the wrong score), but a very different colour.
2. Keep the **steel** pixels (saturation < 0.3). A knife's shadow is new too and starts at the entry point, but keeps the board's hue. If too little is grey, fall back to the whole shape.
3. The steel pixels' **principal axis** is the knife's line; its ends are the 2nd / 98th percentile along it.
4. **Which end is the entry:** the knife sticks out towards the thrower. In the image "out of the board" points from the outer ring's ellipse centre towards the bull's centre (a tilted circle's centre appears shifted towards the far side). The handle is that way; the entry is the other end, taken as the centre of the knife pixels within 2 px of it.

**On the phone (`WatchStatus`):** while still, a full-resolution "before" is kept (refreshed every second, off the UI thread). When an episode is classed **stuck**, the next frame is the "after"; the entry is found in the background, scored through `TargetMapping` and shown as a yellow circle with its score. **Face on** (`isFaceOn`), the entry comes straight from the classifier's knife shape instead (`faceOnEntry`; see Throw Detection on Real Footage). The after then becomes the next before.

**Accuracy on 6 rendered throws** (2 sequences at 1280 × 720, 4 camera views at 1600 × 1200, 1× and 2×): **0.7–1.7% of the target radius (about 3–6 mm on an 80 cm board); every score correct**, including the ring-3 knife next to the 3/2 line.

**Assumes** something sticking out of the board that's mostly grey steel. A flat or coloured object (a pen taped to paper) won't give the right end.

## The Knives

**Nigel's knives (2026-10-08, photo):** all-steel throwing knives: one flat piece of brushed stainless steel; spear-point blade **~10 cm**; flat handle **~10 cm** with a row of **see-through holes** (three small, one larger at the end). No separate dark handle.

**What it means for detection:**
- A stuck knife shows as **bright grey steel**, not a dark bar. It takes on the light: dark grey when its face is turned from the sun, bright with highlights when facing it, tinted by sky or grass. It can't be found by "dark object on the board".
- The board **shows through the handle's holes**, so a stuck knife isn't one solid region in a before/after difference.
- About **2.5 cm** of blade is in the wood when stuck, so ~7.5 cm of blade plus the 10 cm handle stick out.
- The renderer models all of this (`SyntheticScene._bladeAndHandle`: tapered blade profile, holes).

## Board Size

**Nigel's boards are about 75–85 cm across** (2026-10-08; answers open question Q2). The rendered test views use **80 cm**, with the rings in the reference photo's proportions: the outer scoring ring is about 74 cm across, larger than IKTHOF's 50 cm. **Camera about 2 m from the board, off to the side at about 45°** (Nigel, 2026-10-08); the renders use this. **Throwing distance 4 m; 3 throws per round; knives first, axes later** (Nigel, 2026-10-08).

## Score Against the Painted Rings, Not Ideal Ones

Measured on the reference board, the painted edges are at **0.219, 0.395, 0.620** (relative to the 0.8 edge), not 0.2 / 0.4 / 0.6. A knife near a line can score differently depending on which you use. So scoring must use the **fitted** ring ellipses. The rendered test views' answers (`truth.json`) already do.

**How (Task 4, `TargetMapping`):** along the line from the bull's centre through an image point, find the painted edges either side of it (each its own fitted ellipse, so perspective is handled) and interpolate between their **ideal** radii. A point on a painted edge maps to exactly that edge's ideal radius, so `TargetModel` (ideal radii, line-touch rule) scores the board as painted. Inside the bull: proportional. Beyond the outer edge: continues at the outer ring's rate. The approach was chosen over a single affine or homography fit because those assume the paint is at the ideal radii.

**Accuracy on the rendered views:** every knife scores correctly; entry radii are within 0.01 of the target radius (about 4 mm on an 80 cm board).

## Rendered Camera Views (Test Data)

`lib/vision/synthetic_scene.dart` ray-traces the setup:
- A log board on a three-legged stand, on grass.
- A phone camera with perspective, at any position and field of view.
- Knives (steel blade + dark handle) at any entry point, pitch and yaw.
- Sun shadows.

`PhotoBoardTexture` paints the **real reference photo** onto the board (Nigel: "target-example is the core for all the pictures"). It traces the photo's bark outline, removes the photo's own knives (refilling from the same ring further round) and uses the photo's measured ring sizes.

Each render comes with its answers: each blade's entry point (board and pixel), its score, and the ring edges in the image. That makes these test data for ring finding now and for throw detection later. They're not a substitute for real photos: lighting, lens and blur are simplified.

## Throwing Sport: Knives and Axes into a Wooden Board

**Decision (Nigel, 2026-10-04):** Users throw **knives or axes** (not darts) at a **wooden board with 5 painted circles**. The **camera is static** (fixed in place, not handheld).

**What the reference photo shows** (`docs/thrower/reference/target-example.png`, a stand-in until Nigel's own photos arrive):
- A round slice of log on a three-legged stand. Its outer edge is **irregular, with bark**, so the board's outline is **not** the target. Detection must use the **painted rings**.
- 5 scoring zones, alternating **red paint and bare wood**: red bull, wood, red, wood, red outer ring. (Other boards use other colour pairs; the locator handles any two. See Target Locating.) The paint is sprayed on, so the ring edges are soft, not crisp lines.
- The surface is **full of old cuts and slots** from earlier throws, so "the board looks different" doesn't on its own mean a new throw.
- The knife handles **stick out towards the camera** and cover part of the rings. Viewed from an angle, the handle appears well away from where the blade went in.

**How the sport scores (research, 2026-10-04):**

- **KATTA UK** (knife, axe & tomahawk; the European face)
  - **Rings / points:** 5 rings at 10 / 20 / 30 / 40 / 50 cm diameter, scoring **5 / 4 / 3 / 2 / 1**
  - **A blade touching a line:** **Higher** score ("the best ring that is cut will be counted")
  - **Did not stick:** 0
- **IKTHOF** (knife & axe)
  - **Rings / points:** 5 octagons at 10 / 20 / 30 / 40 / 50 cm, scoring **5 / 4 / 3 / 2 / 1**
  - **A blade touching a line:** **Higher** score
  - **Did not stick:** 0
- **WATL (axe)**
  - **Rings / points:** Bull 6, rings 5 to 1, killshot 8
  - **A blade touching a line:** **Lower** score
  - **Did not stick:** 0
- **IATF (axe)**
  - **Rings / points:** 5 / 3 / 1, clutch 7
  - **A blade touching a line:** Where the **majority of the blade** is
  - **Did not stick:** 0

Nigel's 5-to-1 five-ring target matches the **IKTHOF** layout. Scoring is decided by **where the blade meets the target surface**, not by where the handle is. A throw only scores if it **sticks**.

**Update (Nigel's brother, via Nigel, 2026-10-19): the scoring is KATTA**, "which is prevalent in the UK". Requirement: [[Scoring Rules]]. KATTA UK (knifethrowing.co.uk; its *Guide to different Targets*) uses the European face: the same ring sizes and scores as IKTHOF ("practically the same", IKTHOF's octagons about 1% larger), and a blade cutting a line takes the higher ring. So nothing changed in scoring: `TargetModel.ikthof()` was renamed **`TargetModel.katta()`** ([[story-checkpoint-quick-draw-match]] Task 1). Nigel's 75–85 cm boards are larger than the 50 cm face; scoring works on proportions (`TargetMapping`), so that doesn't matter.

**Backlog (Nigel, 2026-10-04):** refine scoring by hit point, meaning which line-touch rule applies and any per-sport variants. For now: IKTHOF ring values, a touching blade scores the higher ring, and a throw that doesn't stick scores 0. The line-touch rule is a setting on `TargetModel` (`LineTouchRule.higher` / `.lower`), not hard-coded. **Implemented in Task 3:** `TargetModel.scoreAt(point, bladeHalfWidth:)` treats a blade as touching a line when it comes within `bladeHalfWidth` of it; a point exactly on a line counts as touching. IATF's majority-of-blade rule needs the blade's extent and stays on the backlog.

Sources: [IKTHOF tournament rules](https://ikthof.com/tournament-rules/), [WATL rules](https://worldaxethrowingleague.com/axe-throwing-rules/), [IATF standard scoring](https://internationalaxethrowingfederation.com/standard-scoring/), [knife-throwing rules archive](https://thrower-archive.knifethrowing.info/rules.html).

## Single Player First

**Decision:** The first version supports one player. Multiple players and rounds come later.

**Consequence:** The game model (`Session` → `Throw`) should leave room for a `Player` without building multi-player now.

**Confirmed:** 2026-10-04.

**Update (2026-10-16, [[story-checkpoint-players-and-targets]]): one or two players.** Requirement: [[Game Type]], [[One Target]], [[Two Targets]]. Nigel: "there should be a second screen that says how many players 1 or 2. Also, 1 target(so alternating) or 2 at the same time". Home → Play (and Live test → Play) opens `PlaySetupScreen`: **Players 1 / 2**; with 2, **Targets 1 / 2**; then **Start**. The choice is a `PlayMode` (`solo`, `sharedTarget`, `twoTargets`) in `playModeProvider`, kept for the session; changing it starts a new game, the same choice keeps the game in progress.
- `Match` (`lib/scoring/match.dart`, pure Dart, immutable) holds a `GameSession` per player, so one player's rules (rounds of 3, collecting, falling out, game over) are unchanged and shared. `GameNotifier`'s state is now a `Match`; its `onEvent` takes the **board** the event came from (0 on one target). Knives are remembered by (board, knife id), since each board's watcher numbers its own knives.
- **One target, taking turns** (Nigel, 2026-10-16, "yes to all"): a player throws their 3 knives, they're collected, then the other player. The turn passes on a **board visit** (also early, with fewer knives), or, if the next knife comes without collecting, once the turn already has its 3 throws (that knife is the next player's). **Player 1 starts every round.** Chosen over alternating every knife: the app can't tell whose knife is whose, so a knife falling out couldn't be given to the right player. A knife falling out zeroes the throw of the player who threw it.
- **Two targets, throwing together:** board N's throws, collections and falling-out knives belong to player N only; each player's game ends on its own, and a player whose game is over can't throw on.
- **Over** once every player's game is over; the higher total wins, equal totals are a **draw** (`Match.winner`, `Match.draw`).
- Players are **"Player 1" and "Player 2"** for now; typed names may come with accounts. *(Since 2026-10-19 players can be named: Named Players; a blank seat is still "Player N".)* Other game lengths and history are not in this story.
- Built so far (Task 1): the rules and the setup screen; only 1 player can be started. Two players on one target comes in Task 2, on two targets in Task 3.
- **Task 2: two players on one target, playable.** Play's panel (`_PlayersPanel`) shows, in place of one player's round lines:
  - **whose turn it is in large type** (`turnText`, 32 pt; Review Agent: readable from the throwing line, as for Quick draw): "Player 1's turn"; once the turn has all its throws, **"Collect your knives"** with a smaller line, "When no one is throwing. Then Player 2's turn." (`turnDetail`); the headline is kept short so the camera view keeps its room;
  - each player's total (`playerTitle`, "Player 1: 23") and round in progress (`playerDetail`, the one-player `roundText`), the thrower's in white, the other's dimmed;
  - at the end, **"Player 2 wins" or "A draw"** (44 pt, green), every round of each player, "Collect your knives when no one is throwing." (`matchFooter`) and **New game**.
  - The board's marks clear at each new turn (`Match.nextThrowStartsRound`), as they did at each new round.
  - **Safety (Review Agent §7, 2026-10-16, Task 2):** the screen never names the next thrower while the knives are still to be collected; "Player 2's turn" shows only after the collection (a board visit ends once the board's region has settled, so the person has left the board). The Instructions add: throw only on your turn, once the other player has collected their knives **and stepped back**. Requirement: [[Instructions and Safety]].
- **Task 3: two players on two targets, playable.** `TwoTargetPlayScreen` (Setup → 2 players, 2 targets → Start):
  - **Choosing the boards** is Quick draw's: tap Player 1's board, then Player 2's, **Lock boards** (`BoardChoosing`, now with an `addBoard` hook; `BoardsOverlay`). Play's boards are its own, `playTargetsProvider` (`PlayTargetsNotifier`): kept for the session like the calibration, so leaving Play and coming back keeps them, and started afresh when the camera changes; Quick draw's stay separate and are dropped when Quick draw closes. **Choose boards again** keeps the scores.
  - **The camera is set to 1×** on this screen: a zoom kept from calibrating one target could cut a board off.
  - **Watching:** `PlayBoardsWatcher` (`lib/game/play_boards_watcher.dart`): a `ThrowWatcher` per board, at Play's usual pace, on its own crop. The cropping is now one function, `cropToBoard` (`lib/game/board_crop.dart`), shared with `QuickDrawWatcher`. Events go to `GameNotifier.onEvent(board:)`. Each board's marks are drawn at its crop's offset (`BoardMarksPainter`, `paintRoundMarks`).
  - **What the panel says** (`turnText` / `turnDetail` for two targets): nothing extra while both are throwing; **"Wait for Player 2"** / "Then collect your knives together." once only one round is complete; **"Collect your knives"** / "Together, when no one is throwing." once both are; at the end the winner. Each board's state in one line (`boardsStateText`, "Player 1: ready · Player 2: throw seen") and the last event with its player (`boardMessage`).
  - **Live test → Play on two targets** plays the Quick draw recording (both boards) in this mode.
  - **Safety (Review Agent §7, Task 3):** the same set-up as Quick draw (two people throwing at once, separate lanes, the phone behind the throwers out of both lines of throw), with the Instructions saying so; the app never prompts one thrower to collect while the other is still throwing ("Wait for Player 2"). Requirement: [[Instructions and Safety]].

## Throw Detection: Before/After Comparison from a Static Camera

**Decision (approach; details are refined in the throw-detection story):**
1. **Calibrate once.** The camera is static, so find the rings' ellipse when the session starts (with optional manual confirmation or a drag-to-adjust overlay) and then lock it. No re-detection every frame.
2. **Keep a reference frame** of the settled board.
3. **Spot a throw** from a burst of motion (and, later, possibly the sound of the impact).
4. **Once the scene is still**, compare it with the reference. If a new object has appeared, it's a **stick**. If there was a burst of motion but nothing new, it's a **bounce-out** (0 points).
5. **Find the blade's entry point.** Take the end of the new object where it meets the board, i.e. the blade and the slot in the wood, **not** the handle. This is the step most likely to need a trained model.
6. Convert the entry point to normalised target coordinates, score it, and make this frame the new reference.
7. **Someone walking up to the board** (to pull out blades) appears as a large occlusion followed by blades removed. That ends the round and resets the reference.

**Rationale:**
- Thrown blades stay put, so the score can be read from a still frame. "Timing" means telling throw, stick, bounce-out and retrieval apart, not catching the blade in flight.
- With a static camera, calibration is a one-off and frame-to-frame comparison is stable.

**Known hard parts (for the throw-detection story):**
- Finding the entry point beneath a handle that sticks out towards the camera and covers it. Axes are worse: a longer handle and a wide blade.
- A board already scarred with old cuts, which must not be mistaken for new hits.
- A knife that sticks and then **falls out** later.
- Outdoor light and shadows changing between throws.
- **Safety:** the phone has to sit outside the line of throw, so viewing from an angle is the normal case, not an edge case. Requirement: [[Instructions and Safety]].

**Confirmed:** 2026-10-04 (plan approved).

---

*Further decisions are recorded here as they're made in [[story-checkpoint-setting-up-throwing-app]].*

## Live Test: A Recording in Place of the Camera (2026-10-11)

**Decision:** the Live test plays a recording of a real board **as a camera**, through the same calibrate → Play screens and the same vision and game code. It's analysed live on every run; the app holds no answers ([[story-checkpoint-live-test]]).

- **`TargetCamera`** (`lib/camera/target_camera.dart`): what the screens and `ThrowWatcher` need from a camera: `frames()`, `uprightRotation` and `dispose()`. There are two implementations:
  - `LiveCamera`, the phone's back camera
  - `RecordedCamera`, a recording
- **`cameraProvider`** opens one of them, depending on `recordingChoiceProvider` (null means the live camera). `calibrationProvider` and `gameProvider` watch that choice: a calibration and a game belong to the camera they were made with, so switching starts both afresh. Leaving the Live test screen switches back to the live camera.
- **`RecordedCamera`** behaves like a camera:
  - It delivers a frame every 1/fps seconds to whoever listens: BGRA, already upright, stamped with a monotonic clock.
  - It **opens paused on the first frame**, so the board can be calibrated before anything happens.
  - Play calls `restart()`; playback stops on the last frame.
  - **Leaving Play calls `rewind()`** (2026-10-13): playback stops and waits on the first frame again, so a recording plays only while Play is open. Re-calibrating afterwards sees the empty board, and the calibrate screen's throw watcher sees a still picture (see [[Known Issues]] → Re-calibrating After Play in the Live Test).
  - **Frames are decoded asynchronously, one at a time** (2026-10-13). If decoding falls behind, it skips to the newest frame wanted rather than queueing, as a slow live camera drops frames. Until a new frame is ready, ticks keep delivering the last one.
- **Recording format:** `FramePack` (`.tfrm`, `lib/camera/frame_pack.dart`) is JPEG frames at a fixed rate in one asset. That means no video plugin, so no native code or permissions.
  - **Decoding:** the app uses `decodeFrameNatively`, Flutter's own image codec (native, off the UI thread). It gives a `ui.Image` for `RecordedPreview` (which keeps a `clone()`) and BGRA bytes for the watcher (`toByteData` RGBA, with red and blue swapped by `rgbaToBgra`). Tests inject `decodeFramePureDart` (`package:image`), which needs no engine. Until 2026-10-13 the app decoded in pure Dart on the UI thread: 15–27 ms per 322 px frame on a PC, which made playback jump and freeze on Nigel's Samsung SM A065F (see [[Known Issues]]).
  - Made with `tool/pack_recording.dart` (needs ffmpeg).
  - Target 1 and Target 2: cut from Nigel's **original** video (since 2026-10-12): 322 × 322 px (boards ~245 px across), 15 fps, 2,848 frames, JPEG q12, **25.9 MB each** (Nigel's choice of size: same frame rate as the phone's analysis, quality that looks the same as q5 at half the size). Until 2026-10-12 they were 140 × 140 crops of a compressed copy, 10.4 MB each.
  - **In TestFlight builds too** (Nigel, 2026-10-11), so his brother can run them.
  - Recordings keep `minChange` 20 (the live camera 12): even from the original, JPEG and video blocks gave false bounce-outs at 12.
- **Rejected:** a video plugin for decoding (native code, and no frame-pixel access in `video_player`); pre-computed results (not a test of the pipeline).
- **Quick draw clip** (2026-10-14, Task 1 of [[story-checkpoint-quick-draw]]): both boards in one picture, for the two-thrower race.
  - `quickDrawRecording` (`lib/camera/recorded_camera.dart`): `assets/live/quickdraw.tfrm`, cut from the original at 158.5–166.0 s. The **full frame** scaled to 720 × 1280 (boards ~163 px across), **60 fps**, JPEG q20: 449 frames, **34.2 MB**. 60 fps because the two knives land about 33 ms apart (frames 217 and 219): 2 frames at 60 fps, but under one at 15 fps.
  - **Why q20** (Nigel, 2026-10-14): q12 was 53.1 MB; q31 was 23.0 MB but visibly blocky on the boards. The grass makes full frames compress poorly, so this is well over the story's 15–20 MB estimate.
  - Not in `liveTestRecordings`: it has its own `quickDrawCameraProvider` (`lib/providers.dart`), separate from the single-target `cameraProvider`, and released when Quick draw closes.
  - Answer key: `reference/live-camera/quickdraw.json` (see the Live Camera README).
- **Sound** (2026-10-14): a `Recording` can carry an `audio` asset, the same length and starting with the first frame. The Quick draw clip has one (`assets/live/quickdraw.m4a`, mono AAC 96 kb/s, 93 KB): the footage's quiet countdown and the knives' impact.
  - `RecordedCamera.sound` (a `RecordingSound`): `restart()` plays it from the start, `rewind()` stops it, and it's disposed with the camera.
  - **Sound is a nice-to-have:** if it fails, the error is reported (`FlutterError.reportError`) and the frames play on.
  - `AssetRecordingSound` uses the **`audioplayers`** plugin (^6.8.1), loaded once and kept ready (`ReleaseMode.stop`), so a replay doesn't reload. It's a native plugin, for playback only; the app still records no audio. Tests inject a fake `RecordingSound`.
  - Played separately rather than packed into the `.tfrm`, so `FramePack` stays frames only.
  - **Audio context** (Nigel, 2026-10-14): `AssetRecordingSound.audioContext` **ducks other apps** (music is turned down while it plays, not stopped) and **ignores the silent switch** (`respectSilence: false`), so a countdown is always heard. The plugin's default stopped other apps' audio. Built for the platform it runs on.
- **`QuickDrawScreen`** (`lib/ui/quick_draw_screen.dart`), reached from **Live test → Quick draw**: the clip full screen on black, with the system bars hidden (`immersiveSticky`, back to `edgeToEdge` on leaving). A back button, and a **Play** button (**Play again** once played) that's hidden while it plays. Debug builds show the frame rate. Before playing, the user chooses the boards by tapping (see Quick Draw: Choosing the Boards by Tapping below). Played with the boards locked, **GO!** flashes at the footage's go, every frame is analysed (see Quick Draw: Analysing Every Frame, Reporting Late), each board shows its knife's time after go and its result, and the bottom line gives the winner (see Quick Draw: Go, False Starts and the Winner). The live camera version is **Home → Quick draw** (see Quick Draw: the Live Screen).

## Quick Draw: Choosing the Boards by Tapping (2026-10-14)

**Decision:** on Quick draw the user **taps the centre of Player 1's board, then Player 2's** (by name since 2026-10-19: "Tap the centre of Jo's board"; Named Players) (Task 2 of [[story-checkpoint-quick-draw]]). There may be more boards in the picture than players, so the app doesn't guess. Nigel: *"selecting the two targets by touching the camera is the way to go ... assume the centre of the boards is selected in order, 1 then 2"*.

**Why not automatic:** finding one board in the whole picture, then searching beside it, found the right-hand (green and red) board on only **8 of 16** still frames, one of them the wrong ring; the whole-picture pass also failed on 3 of 8 frames for the left board. The ring finder learns the two ring colours from what it's shown, and boards side by side can be painted differently.

**How (`locateTargetAt`, `lib/vision/tapped_target_locator.dart`):**
1. A square **window** around the tap, **0.45 ×** the picture's shorter side (kept inside the picture).
2. The window is **enlarged 3×** (`workingSize` and `minWorkingSize` both 3 × the window, at least 420 px) before the rings are traced: small boards trace far more reliably enlarged.
3. `ColourRingLocator.seed`: the tap, in the window's coordinates, is tried **first** as the board's centre. Then the centres of the colour regions **under and just around the tap** (`_regionCentresNear`: the tap and 4 points 1% of the picture's side away; a region over a quarter of the picture is background and skipped). A tap rarely lands on the exact centre, but the bull, or the ring it lands in, is centred on the board. Then the usual candidates (largest regions first).
4. The result is moved back into the whole picture's coordinates (`CoarseToFineLocator.moved`).

`locateTappedInFrame` does this for each tap on one camera frame (upright, at most 1920 px), and runs in a background isolate (`compute`, via `locateAtTap` in `lib/game/quick_draw_targets.dart`) so the preview doesn't stall: about 1–1.5 s per board on the PC.

**Taps are fractions of the picture** (2026-10-15, Task 1 of [[story-checkpoint-live-quick-draw]]). `BoardsOverlay` divides the tap by the picture's size on screen, so a tap is 0–1 each way (`TapLocator`). `locateTappedInFrame` turns it into pixels only after `frameToRgb` has turned the frame upright, when the upright picture's size is known. Until then taps were upright image pixels, worked out on screen from the recording's width. That only works for frames that are already upright: a live Android frame arrives sideways, so the same pixels would land somewhere else. Checked by `tapped_target_locator_test.dart` (a sideways, 90° frame with fraction taps finds the board where measured).

**Measured** on the clip's 16 still frames, taps at the measured centres (boards found, of 16):

| Approach | Player 1 (red on wood) | Player 2 (green and red) |
|---|---|---|
| Window at the tap, 1.3× (the finder's usual) | 15 | 10 |
| Window at the tap, **3×** | **16** | **15–16** |
| 3×, tap 10 px off centre, with region snapping | 16 | 15 |
| 3×, tap 15–30 px off centre | 15–16 | 10–12 |

The misses aren't resolution or compression: the right board fails as often on the uncompressed original at full size. So **tap the bull** (see [[Known Issues]] → Quick Draw: a Board Isn't Found, or the Wrong Outline).

**State:** `QuickDrawTargets` (`lib/game/quick_draw_targets.dart`): the boards as `TargetCalibration`s in tap order, two players, `locked`. `quickDrawTargetsProvider` adds the next player's board, `clear`s ("Choose boards again") and `lock`s (only once both are found); it's auto-disposed, so leaving Quick draw starts over. `tapLocatorProvider` is the tap search (tests replace it).

**Screen:** an instruction line ("Tap the centre of Player 1's board.", "No board found there.", "Both boards found: lock them, or choose boards again."), `BoardsPainter` (each board's rings, scaled from its own image size, with its player number in a disc above it; blue while choosing, green once locked), and **Choose boards again** / **Lock boards** / **Play**. Taps are ignored while the clip plays or a search is running. **Choose boards again** also **rewinds** the clip, so boards are chosen on the still first frame, not where playback stopped. Since 2026-10-19 a wrong outline can be dragged into place, and **Adjust boards** unlocks them (see Adjust Each Board); before that, a wrong outline meant Choose boards again.

**Shared** (since 2026-10-15) by the recording's `QuickDrawScreen` and the live `LiveQuickDrawScreen`, in `lib/ui/quick_draw_boards.dart`: `BoardChoosing` (a mixin on the screen's state: `findBoardAt`, `searching`, `missed`, and the instruction line, `choosingInstruction`), `BoardsOverlay` (the painted boards, and the taps as fractions; `tapsOff` while a recording plays), `BoardsPainter`, `boardLines` and `quickDrawLine` (the bottom line). Until then they were private to `quick_draw_screen.dart`.

## Adjust Each Board (2026-10-19)

**Requirement:** [[Two Targets]], [[Game Type]] (Quick draw).

**Decision** ([[story-checkpoint-adjust-boards]] Task 1, backlog #10): when two boards are chosen (both Quick draw screens and two-target Play), **each board's outline can be dragged into place**, as the single target's can: drag inside to move it, drag its long-axis handle to turn and stretch it, its short-axis handle to stretch it. Until then a wrong outline could only be fixed with **Choose boards again**, which forgets both boards. Nigel also said yes to an **Adjust boards** button after locking (*"yes, start #10 with the Adjust boards button"*): it unlocks, **keeping both boards**, so a knocked board is fixed without choosing both again.

**Options (architectural purity over the quick option):**
- **Quick, not chosen:** a `CalibrationEditor` for one "selected" board, with buttons to switch boards. It adds a mode to learn, and the other board can't be touched meanwhile.
- **Chosen:** the single target's drag rules taken out as pure functions and shared. **`grabAt(calibration, point, reach)`** says what a touch picks up (`CalibrationGrab`: `move`, `major`, `minor`, or null); **`dragged`** applies the drag (`TargetCalibration.moved`, `withMajorHandleAt`, `withMinorHandleAt`). `CalibrationEditor` uses them unchanged, and a new **`BoardsEditor`** (`lib/ui/quick_draw_boards.dart`) hit-tests **both** boards: a handle beats a board's body; between bodies, the board whose centre is nearest the finger wins. No selection mode; the other board is untouched.

**The grab rule, and a fix for small targets:** a handle wins only when the finger is nearer the handle than the board's centre. Two boards in one view are often small on screen, and the handles' 32 px touch zones reached their middles, so touching the middle grabbed a handle. This changes the single target too (see Adjust and Lock the Calibration).

**How:**
- `BoardsOverlay(onAdjust:)` becomes the `BoardsEditor` while both boards are found and not locked (taps no longer find boards then). `BoardsPainter(handles: true)` draws each board's two handles.
- `QuickDrawTargetsNotifier.replace(index, board)` puts the dragged board in place (ignored once locked); `unlock()` keeps both boards. Shared by `quickDrawTargetsProvider` and `playTargetsProvider`.
- **Adjust boards** shows once the boards are locked:
  - live Quick draw (`quickDrawAdjust`): not while a round is on; the match is kept;
  - the recorded Quick draw: not while playing; it stops watching and **rewinds**, so the boards are adjusted on the still board;
  - two-target Play (`playAdjustBoards`, `_adjustBoards`): **stops watching** and **clears the marks** on the picture; the game's **scores stay**. Locking again watches afresh, as after choosing the boards.

**Safety (Review Agent §7):** while the outlines can be adjusted, `choosingInstruction` says *"Both boards found. Drag an outline to fit its rings if needed (only when no one is throwing), then lock them."* In Quick draw and two-target Play the phone stands **behind the throwers**, so adjusting means someone at the phone: only when no one is throwing. Requirement: [[Instructions and Safety]].

**Instructions (Task 2):** the in-app Instructions now cover it: *Two players on two targets* and *Quick draw* explain dragging an outline into place (or Choose boards again), and **Adjust boards** when a board or the phone is knocked (two targets: watching stops until Lock boards, the scores stay; Quick draw: between rounds, the match carries on), always only when no one is throwing. Details: Rounds and Scoring → In-app Instructions.

## Quick Draw: Timing and Scoring Each Board (2026-10-15)

**Decision:** each locked board is watched on its **own crop** of the picture by the **single-board throw detection**, looking at **every frame**, and each player's first throw (stuck or bounce-out) is kept with its **impact** time (Task 3 of [[story-checkpoint-quick-draw]]).

**How (`QuickDrawWatcher`, `lib/game/quick_draw_watcher.dart`):**
- Per board, a square crop **4 × the board's radius** (`cropRadii`; kept inside the picture). The watched region is 3 radii wide (`WatchRegion.fromCalibration`), so this leaves room around it.
- `CroppedCamera` (`lib/camera/cropped_camera.dart`) turns the crop into a camera of its own: frames are views into the source frame's bytes (no copying), at the source's full detail. BGRA and YUV; `x`, `y` (and, since the live Task 2, `width` and `height`) are rounded down to even numbers so YUV's half-size colour planes line up. Upright sources (the recordings) at first; since Task 2 of [[story-checkpoint-live-quick-draw]] it also cuts a live camera's sideways frames, in the sensor's layout (see Quick Draw: the Live Camera — 60 fps, Crops and a Queue).
- `TargetCalibration.within` moves the board's rings into the crop's coordinates.
- A `ThrowWatcher` per crop, with `interval` zero: every frame (60 fps), because the two knives land about 33 ms (2 frames) apart. Every board sees the same frames, so the players are timed alike.
- The first stuck or bounce-out event per player becomes a `QuickDrawThrow`: `impact`, `stuck`, and for a stuck knife its ring `score` (`TargetModel.scoreAt` on the entry point; null if no entry was found). Later events are ignored.

**Impact = `MotionEpisode.impact`:** the frame with the **largest moving shape on the target** (where a knife hits, the board jolts and the knife stops at once). Not the episode's start: seen from behind the thrower, a knife in flight is over the board's face all the way in, so motion starts frames before it arrives. On the clip (60 fps), motion started **1 and 7 frames** before the answer key's impact frames, the first shape on the target **1 and 5** before; the largest was **on** them. (Falls back to the episode's start if nothing moved on the target.)

**Board visits: 2% → 3% of the region (`classifyThrow` `visitArea`).** The right board's knife, flying in close to the camera, moved a shape of **2.2%** of the region and was taken for a person. People are **4%+** (Target 1 and Target 2); knives on the Target 1 / Target 2 recordings at most **1.1%**. So 3% still separates them.

**Shown:** **Play** with the boards locked starts a fresh `QuickDrawWatcher` (Choose boards again or Play again throws the old one away). Each board shows a line under it (drawn by `BoardsPainter`). In Task 3 this was the impact on the clip's own timeline ("3.62 s · 5"); since Task 4 it's the time **after go** (`boardLines`; see Quick Draw: Go, False Starts and the Winner). Without a lock, Play just plays the clip.

**Checked by** `test/game/quick_draw_replay_test.dart`: the clip through `RecordedCamera` → `RecordingAnalysisFeed` → `QuickDrawWatcher`, boards tapped at their centres: Player 1 (left) bounces out, Player 2 (right) sticks for 5, each impact within a frame of the answer key, Player 2 first.

**Dropped frames (Task 3; fixed in Task 4):** the watchers first looked at the picture's own frames, so a phone that skipped frames (Samsung 11–12 a second, iPhone ~42) made the times coarser ([[Known Issues]] → Quick Draw: Dropped Frames Make Times Coarser). Now they watch the analysis feed (next section).

**Confirmed:** 2026-10-15 (Nigel, Samsung: "it shows the scores and the times").

## Quick Draw: Analysing Every Frame, Reporting Late (2026-10-15)

**Decision (Nigel, 2026-10-15):** playback stays as it is, and may skip frames to keep up with the sound, but **analysis sees every one of the clip's frames, in order**, each timed by its **place in the clip**. The result may come late: *"analysis can come back with the actual result 1/2 second later"* (Task 4 of [[story-checkpoint-quick-draw]]).

**Why:** `RecordedCamera` decodes only the newest frame when it falls behind, and the same decoded frame fed both the picture and the watchers. On the 60 fps clip the iPhone showed about **42** frames a second (debug build), the Samsung A06 **11–12**. The two knives land 2 frames (about 33 ms) apart, so a skipped frame can hold the moment a knife lands, and both players often got the same time. Frames were also timed by when they arrived (`_now()`), which added decode jitter.

**How (`RecordingAnalysisFeed`, `lib/camera/recording_analysis_feed.dart`):** a `TargetCamera` that follows a `RecordedCamera`.
- It decodes its **own copy** of every frame (with the camera's `decoder`), one after another, from its **`first`** frame up to the frame on show: **never ahead of the picture**, so a result can't appear before the moment it shows.
- Each frame is stamped with its place in the recording, `timeOf(index)` = frame number ÷ frame rate, not with when it was decoded.
- **Starts 1 s before go** (`from:`, `quickDrawLeadIn` in `quick_draw_watcher.dart`; frame 108 on the clip, 1.8 s in). Nigel, 2026-10-15: *"I don't think analysis needs to start till 1 second before go, it will be super obvious if they go earlier than that."* So a false start more than a second early isn't detected by the app; the watchers still get 1.8 s of still board before the knives. It cuts the frames analysed before the throws by about half (108 of 217).
- `analysed`: the last frame analysed (`first` − 1 before any), so the screen can show how far behind analysis is; "Watching…" until the picture reaches `first`.
- When playback starts again from the beginning (the position goes back), so does the feed, from `first`. It decodes only while someone listens. `dispose` stops following the camera (the camera isn't the feed's to dispose).
- `QuickDrawWatcher` watches this feed, not the camera. The picture and the sound keep their own pace.

**The cost:** each frame from 1 s before go is decoded twice (once for the picture, once for analysis). If a phone analyses ~42 frames a second, analysis falls behind by about 0.4 s per second analysed: about 0.75 s by the throws at 3.6 s (less in a release build). If that's too slow, only the board crops need decoding (see [[backlog]] → Speed on the phone).

**Shown:** while analysis is more than 0.2 s behind, the bottom line says **"Analysing… 0.4 s behind the picture."**, otherwise **"Watching…"**; then the verdict, once both throws are in or the whole clip has been analysed.

**Checked by** `test/camera/recording_analysis_feed_test.dart` (every frame up to the one shown, in order, even when the picture skipped them; stamped with their place, not when analysed; never ahead of the picture; starts again on replay; nothing decoded without a listener) and `quick_draw_replay_test.dart` (with playback skipping 2 of every 3 frames: the same throws, on the same frames).

**Live camera:** there's no decoding to do, but the phone has to keep up with 60 fps analysis; the live game's timing questions are in [[backlog]] #9. Since Task 2 of [[story-checkpoint-live-quick-draw]], the live camera gets the same every-frame, report-late analysis by queueing each board's crops (`QueuedCamera`; see Quick Draw: the Live Camera — 60 fps, Crops and a Queue), from 1 s before the start signal's go (Quick Draw: the Live Duel and the Result).

**Confirmed:** 2026-10-15 (built; Nigel's device check pending).

## Quick Draw: Go, False Starts and the Winner (2026-10-15)

**Decision (Nigel, 2026-10-14):** **the first knife to stick wins.** A bounce-out loses. A knife that reaches its board **before "go"** is a **false start**, and loses. If both stick, the one that reached its board first wins; ring scores are shown but don't decide it. Both on the **same frame** is a **draw**. If neither sticks, **nobody wins** (Task 4 of [[story-checkpoint-quick-draw]]).

**Update (Nigel's brother, via Nigel, 2026-10-19): the score breaks a tie, and a match is three rounds.** Requirement: [[Game Type]] (Quick draw), [[Number of Rounds]], [[Ending Early]] (Finish match). *"The quick draw is always three rounds, first to stick in target wins, bounce outs lose, if the times are the same then score is the decider if possible, if the same score the round is a draw."* That's the European **Duel Cup** format (eurothrowers.org/duel-cup: 3 runs, the first to stick wins a run, at the same time the knife closer to the centre wins; level → more runs). [[story-checkpoint-quick-draw-match]]:
- **A round** (`judgeQuickDraw`): both stuck on the **same frame** → the **higher score** wins (`QuickDrawVerdict.byScore`; "Player 2 wins on score: …"); the same score, **or a score that wasn't found**, is a draw. "The same time" stays the same camera frame (about 17 ms at 60 fps), the finest the camera can tell apart (the Duel Cup's 10 ms needs a timing device).
- **A match** (`QuickDrawMatch`, `lib/scoring/quick_draw_match.dart`, pure Dart: it keeps each round's winner, not the verdicts, so scoring doesn't depend on `lib/game/`): **all three rounds are thrown**, even at 2–0, so both throw alike; the player with more rounds won wins. **Level after three: extra rounds** until one is won (Nigel). **Finish match** ends it after any round, on the rounds won so far; finished early and level is a draw (no extra rounds forced). Drawn rounds (no one stuck, or a tie) count for neither.
- False starts still lose the round (the Duel Cup warns first; not asked for).

**"Go":** `Recording.go`, when the recording's countdown says go, from its start. For `quickDrawRecording` it's **2.8 s** (161.3 s in the original, by Nigel's ear; answer key `reference/live-camera/quickdraw.json`). On the recording the app plays no countdown of its own: the footage's audio gives it. The live game plays its own countdown (Formula 1 style): see Quick Draw: the Start Signal. There `go` is the moment the go beep is asked to play, on the camera's clock; `judgeQuickDraw` is the same.

**How (`judgeQuickDraw`, `lib/game/quick_draw_judge.dart`):** each player's `QuickDrawThrow` (or null) and `go` give a `QuickDrawVerdict`:
- per player a `JudgedThrow`: `result` (`QuickDrawResult`: `none`, `falseStart` (impact before go; exactly at go is not), `bounced`, `stuck`), `afterGo` (impact − go; negative for a false start) and a stuck knife's `score`.
- `winner`: the stuck player with the smallest `afterGo`; null for a `draw` (two stuck at the same time, i.e. the same frame) or when nobody stuck.

**Times are shown from go, not from the clip's start** (Nigel, iPhone, 2026-10-15: *"the timer start is wrong ... they took about 1.2 seconds to strike the board and this says 3.69"*). Task 3 showed clip time, which starts 2.8 s before go. No clip time is left on screen, and `RecordedCamera.playbackTime` was removed. (The 1.2 s came from the Mac's early guess at go; from Nigel's by-ear go it's about 0.82–0.85 s.)

**Shown on `QuickDrawScreen`:**
- **GO!** (big, green) over the picture for **0.7 s** from go, while playing (`_GoFlash`, following `RecordedCamera.position`: the picture's time, so it matches what's heard).
- Under each board (`boardLines` → `judgedText`): "0.82 s · 5", "0.85 s · bounced", "false start" or "no throw"; empty until its throw is in.
- The bottom line (`verdictText`), e.g. **"Player 2 wins: stuck 5, 0.82 s after go. Player 1 bounced out."**, or "A draw: both stuck on the same frame. …", or "No winner. …".

**On the clip:** Player 2 (right) wins, stuck 5, about **0.82 s** after go; Player 1 (left) bounced out.

**Checked by** `test/game/quick_draw_judge_test.dart` (a table: both stick, a bounce-out, both bounce, false starts, exactly at go, the same frame, no throws; times from go; the result line), `quick_draw_replay_test.dart` (the verdict on the clip) and `quick_draw_screen_test.dart` (the line under each board; GO! shows at go and not before or long after; the bottom line follows the analysis, then gives the verdict).

**Confirmed:** 2026-10-15 (built; Nigel's device check pending).

## Quick Draw: the Live Screen (2026-10-15)

**Decision (Nigel, 2026-10-15):** Quick draw with the live camera has **its own Home button**, beside Play, so the two games are clearly different: *"one version is for scoring rounds on one target and the other is quick draw."* Home shows **Play** ("Rounds on one target") and **Quick draw** ("Two throwers, on a start signal"). Live test → Quick draw stays the recording (Task 1 of [[story-checkpoint-live-quick-draw]]).

**How:**
- `LiveQuickDrawScreen` (`lib/ui/live_quick_draw_screen.dart`): the live camera full screen on black, system bars hidden (as on the recording), a back button. Tap Player 1's board, then Player 2's, then **Lock boards**; **Choose boards again** clears them. Locked, it shows a big **Start** for the duel (Quick Draw: the Live Duel and the Result, below). Since Task 4 watching starts **1 s before go**, not at Lock (Task 2 watched from Lock), so nothing is queued while the throwers get ready.
- The picture comes from `CameraView`, which now takes a `camera:` provider (default `cameraProvider`), so camera errors, release in the background and re-opening work as on Play.
- **`liveQuickDrawCameraProvider`** (`lib/providers.dart`): Quick draw's own `LiveCamera`, not `cameraProvider` (which Calibrate and Play share with the Live test's recordings, and which carries the calibration's zoom). Auto-disposed: released when Quick draw closes; never retried automatically.
- Choosing the boards is the shared code above (`BoardChoosing`, `BoardsOverlay`), with taps as fractions, so the live camera's sideways Android frames find the same board as the upright picture shows.
- **No zoom** for now: both boards must be in view, and zooming in is rarely wanted (Plan Changes Log, 2026-10-15).

**Checked by** `test/ui/live_quick_draw_screen_test.dart` (Home's two buttons and captions; Play still opens Play; Quick draw full screen asking for Player 1; tapping both in order, then Lock boards; Choose boards again; a refused camera shows the camera error; leaving restores the system bars; since Task 4, the duel: see Quick Draw: the Live Duel and the Result).

**Confirmed:** 2026-10-15 (built; Nigel's device check pending).

## Quick Draw: the Live Camera — 60 fps, Crops and a Queue (2026-10-15)

**Decision:** once the boards are locked, the live Quick draw watches each board on **every camera frame, in order**, at **60 fps** where the phone gives it. Each frame's board crops are copied into a queue per board and analysed one after another, so a phone that can't keep up **falls behind and reports late** rather than skipping frames, as decided for the recording (Quick Draw: Analysing Every Frame, Reporting Late, above). Task 2 of [[story-checkpoint-live-quick-draw]].

**Why each piece:**
- **60 fps (`LiveCamera.open(fps:)`):** the two knives on the clip land about 33 ms apart: 2 frames at 60 fps, often the same frame (a draw) at 30. `liveQuickDrawCameraProvider` opens with `fps: 60` (the `camera` plugin's `fps`). If the camera won't open at it (a `CameraException` that maps to `CameraFailure.unknown`), it's opened again at its default rate (a `debugPrint` says so). A refused permission is never retried at the default: asking twice would show the prompt again. Play and Calibrate (`cameraProvider`) ask for no rate. **Asked for, not guaranteed:** see [[Known Issues]] → Live Quick Draw: 60 fps Is Asked For, Not Guaranteed.
- **Crops cut in the sensor's layout (`CroppedCamera`):** an Android camera sends frames sideways (`uprightRotation` 90 or 270); iOS's BGRA frames are upright (0). The board's rectangle is in the upright picture (where the boards were found), so `sensorRect` maps it into the sensor's layout and the crop is cut there, still a view into the frame's bytes. The crop reports the source's rotation, so `ThrowWatcher` turns it upright as it does any frame and gets exactly the upright rectangle. **No whole frame is ever turned**, only the crops.
- **Rotation fixed when the crop is made** (Review Agent fix): `CroppedCamera` keeps the source's `uprightRotation` from when it's made (at Lock boards in Task 2; since Task 4, when each duel's watching starts, 1 s before go). Read on every frame, a change in the phone's reported orientation could cut the wrong region or read past the frame. The phone is on a stand, so the boards don't move in the sensor's picture. A frame the rectangle doesn't fit (a different size) is skipped: `crop` returns null.
- **Even numbers:** `x`, `y`, `width` and `height` are all rounded down to even (before: `x` and `y`), so YUV's half-size colour planes line up whichever way the crop is turned. `QuickDrawWatcher` rounds the crop's side to even too, and `TargetCalibration.within` uses the crop's own size.
- **Compact copies (`compactFrame`):** a crop is a view into the whole source frame, so keeping it keeps the whole 1–4 MB frame alive. `compactFrame` copies only its own pixels, packed tightly (a 250 × 250 crop keeps ~250 KB).
- **The queue (`QueuedCamera`, `lib/camera/queued_camera.dart`):** a live camera can't be asked for a frame again, so each arriving crop is kept as a compact copy and handed on in order, one per turn of the event loop (so the screen keeps drawing). Frames keep their own timestamps (when they arrived in Dart). `waiting` (frames queued), `behind` (newest arrived − last handed on), `dropped`.
- **A memory cap: 75 MB a board** (`maxBytes`; Review Agent fix). A kept crop is 0.2–2 MB (a 250–720 px square; BGRA on iOS is 4 bytes a pixel, YUV on Android 1.5). The first cap, 600 frames, could reach 1–2.5 GB on a phone that never catches up, since watching ran from Lock until Choose boards again. 75 MB holds **1.2–6 s at 60 fps**, by crop size; past it the oldest frames are dropped and counted. Since Task 4, watching starts only 1 s before go and stops at the result (Next duel), so a duel's backlog is a few seconds at most.
- **`QuickDrawWatcher(queue: true)`** wraps each board's crop in a `QueuedCamera` (the recording doesn't need one: `RecordingAnalysisFeed` already hands over every frame in order). `states` (each board's `WatchState`) and `queues` are there to show progress.

**Shown (`LiveQuickDrawScreen`):** a `QuickDrawWatcher` on both boards, started 1 s before go (Task 2 started it at Lock; Task 4 moved it: Quick Draw: the Live Duel and the Result); **Next duel**, **Stop**, **Choose boards again** (or leaving) dispose it. Debug builds (`kDebugMode`) show a line above the instruction line (`_WatchDebugLine`): **"1: watching · 2: motion · 0.03 s behind"** (the further behind of the two queues), plus "· N dropped" if any were. The frames/s label (top left, debug) shows the rate the phone delivers.

**Safety Report (2026-10-15): OK for local testing**, after the two fixes above (the byte cap; the rotation fixed at Lock). No manifest, plist or pubspec change; the fallback never hides a refused permission; crops stay in memory; the debug line is debug only. **Still to check on the phones** (both in [[Known Issues]] → Live Quick Draw: 60 fps Is Asked For, Not Guaranteed):
- 60 fps is applied silently: iOS picks the nearest rate at 720p; Android's CameraX may stay at 30 or change the stream size. A fixed 60 fps caps exposure at 1/60 s: darker, noisier frames in dim light.
- Heat and stutter: cropping, brightness and motion work run on the UI thread at 60 fps × 2 boards while watching (since Task 4, from 1 s before go to the result). A 10+ minute run on the slower phone, watching "s behind" and the temperature; a long-lived worker isolate is the fix if needed.

**Checked by** `test/camera/cropped_camera_test.dart` (for 0°, 90°, 180° and 270°: BGRA and YUV crops, turned upright, are exactly the upright rectangle; a compact copy keeps every pixel; the rotation is fixed when made; a frame that doesn't fit is skipped; even rounding), `test/camera/queued_camera_test.dart` (frames arriving faster than they're taken are all handed on, in order, with their timestamps; `waiting` and `behind`; compact copies; the byte limit drops and counts), **`test/game/quick_draw_live_path_test.dart`** (the Quick draw clip from 1 s before go, fed as a **sideways** camera all at once through crops and queues: Player 1 bounced, Player 2 stuck 5, each within a frame of the answer key; no frame dropped) and `live_quick_draw_screen_test.dart` (watching from 1 s before go, since Task 4).

**Confirmed:** 2026-10-15 (built; Nigel's device check pending).

## Quick Draw: the Start Signal (2026-10-15)

**Decision (Nigel and Mark, 2026-10-14; the pause, Nigel, 2026-10-15):** the live Quick draw starts **like Formula 1**: **5 short beeps a second apart**, each lighting one of 5 lights, then a **random pause**, then a **long, higher "go" beep** as the lights go out. **Nothing is shown for go:** the beep is the signal (Nigel, 2026-10-16: "no need for a go on the screen just a long beep(higher frequency)"). The pause is **one of 1.0, 1.2, 1.4 … 3.0 s**, picked at random each time, so the throwers can't time go. Nigel: *"choose any 0.2 of a second between 1 and 3 seconds"*. Task 3 of [[story-checkpoint-live-quick-draw]].

**The sounds:** three small bundled WAVs in `assets/sounds/` (mono, 16-bit, 22.05 kHz; ~61 KB together; listed in `pubspec.yaml` assets), **made by a tool**, like the printable target: `tool/make_signal_sounds.dart` (see [[Common Tasks#Remake the Quick Draw Sounds]]).
- `beep.wav`: each countdown beep, 1 kHz, 0.2 s.
- `go.wav`: the go beep, 1.5 kHz, 0.8 s: longer and higher, so it can't be taken for a countdown beep.
- `result.wav`: the result chime, two notes (660 then 990 Hz, 0.2 s each).

Each tone fades in and out over 5 ms so it doesn't click. Generated rather than recorded: exact pitch and length, no licence question, and easy to change.

**Playing them (`lib/sound/signal_sounds.dart`, a new edge folder):** `SignalSounds` is the interface (`beep`, `go`, `result`, `dispose`); tests use a fake. `AssetSignalSounds` gives each sound **its own `audioplayers` player**, loaded once in **low-latency mode** (`PlayerMode.lowLatency`, `ReleaseMode.stop`), so a sound starts as soon as asked: the go beep is when the throwers go. They use the Live test's audio context (`AssetRecordingSound.audioContext`): **duck other apps' audio** and **play with the silent switch on**. `signalSoundsProvider` (`lib/providers.dart`, auto-disposed) releases them when Quick draw closes. `audioplayers` is the plugin already used for the Live test's clip: no new plugin or permission (sound out only).

**The schedule (`lib/game/start_signal.dart`):**
- `startPauses`: the 11 pauses, 1.0–3.0 s in 0.2 s steps.
- `StartSchedule(pause)`: `beepTimes` 0, 1, 2, 3, 4 s (`beeps` 5, `gap` 1 s); `go` = the last beep + `pause` (5.0–7.0 s after Start); `watchFrom` = go − `quickDrawLeadIn` (1 s), as on the recording. `StartSchedule.random` picks the pause. `startScheduleProvider` hands out a new random schedule for each duel; tests override it with a fixed pause.
- `StartSignal` (a `ChangeNotifier`) runs one: `start` sounds the first beep at once and sets timers for the rest; `phase` (`StartPhase`: `ready`, `countdown`, `go`) and `lit` (0–5 lights on); `onWatch` at go − 1 s; at go it reads the clock, plays the go beep, sets `goAt`, puts the lights out and calls `onGo(goAt)`. `stop` cancels (back to `ready`).

**Go is on the camera's clock.** `goAt` is read from `TargetCamera.now` (new on the interface): the time on the clock the camera stamps its frames with. Throws are timed by their frames' timestamps, so go and impacts are compared on **one clock**. Each camera gives its own: `LiveCamera` its stopwatch (the one that stamps frames as they arrive in Dart), `RecordedCamera` its playback clock, `CroppedCamera` and `QueuedCamera` their source's, `RecordingAnalysisFeed` the playback position (its frames are stamped with their place in the clip).

**Why it's fair:** `goAt` is taken when the go beep is **asked** to play. The sound comes out a little later (the audio system's own start delay), and frames are stamped when they arrive in Dart, not at capture, so absolute times may be a little off; but both delays are the **same for both throwers**, so who won doesn't change. Measuring each phone's sound delay is left for the device check ([[Device Test Plan]] → Quick Draw Checks).

**Checked by** `test/game/start_signal_test.dart` (the schedule's times; the pauses are exactly 1.0–3.0 s in 0.2 s steps and a random schedule uses them all; a light and a beep each second, then the lights out with the go beep at the right moment and `goAt` on the camera's clock; watching from go − 1 s, once; Stop cancels).

**Confirmed:** 2026-10-15 (built; Nigel's device check pending).

## Quick Draw: the Live Duel and the Result (2026-10-15)

**Decision:** the live Quick draw runs a whole duel with **nobody touching the phone** between Start and the result, and shows the result **large enough to read from the throwing line** (about 4 m), as the Quick draw Safety Report asked. Task 4 of [[story-checkpoint-live-quick-draw]]. Requirement: [[Instructions and Safety]].

**The flow (`LiveQuickDrawScreen`):**
1. Tap both boards, **Lock boards** (Quick Draw: the Live Screen). The line says "Boards locked. Throwers ready? Tap Start: 5 beeps, then go on the long beep."
2. **Start** (big): the start signal (Quick Draw: the Start Signal). During the countdown, **5 lights** (`_Lights`, red as each beep sounds), "Wait for the long beep…" and **Stop** (cancels; the boards stay).
3. **From go − 1 s** the boards are watched: `QuickDrawWatcher(queue: true)` on both (every frame, in order, report late: Quick Draw: the Live Camera — 60 fps, Crops and a Queue). **Watching no longer starts at Lock** (Task 2 did, for its debug check): nothing is queued while the throwers get ready, which settles the Task 2 Safety Report's memory point.
4. **Go:** the lights go out with the go beep (1.5 kHz, 0.8 s, against the countdown's 1 kHz, 0.2 s), "Watching…". No GO! on screen (Nigel, 2026-10-16; it was 96 pt for 0.7 s until then). Each board's line under it (`boardLines`, timed from `goAt`).
5. **The result** (`_checkResult`, every 250 ms): once **both throws are in**, or **4 s after go** (`resultWindow`) **once analysis has caught up** (every queue empty), so a thrower who doesn't throw doesn't hang the duel and a slow phone isn't cut off. Then `judgeQuickDraw(throws, goAt)` (the same rule as the recording: Quick Draw: Go, False Starts and the Winner), the **chime** (`result.wav`) and the result panel.
6. **Next duel** (big): keeps the boards, ready for Start; collect the knives first. **Choose boards again** forgets the boards too.

**Readable from the throwing line (`_Result`):** a dark panel in the middle of the screen, the headline **"Player 2 wins"** / **"A draw"** / **"No winner"** at **52 pt** (green), then each player's line at **34 pt** (`judgedText`): "1:  0.85 s · bounced", "2:  0.82 s · 5", "false start" or "no throw", the winner's in white, the other dimmer. Chosen over a sentence like the recording's (`verdictText`), which is too small at 4 m. The instruction line hides while it shows.

**Update (2026-10-19, [[story-checkpoint-quick-draw-match]] Task 2): a match of three rounds.** Requirement: [[Game Type]], [[Number of Rounds]], [[Ending Early]]. `LiveQuickDrawScreen` keeps a `QuickDrawMatch`; each result adds the round's winner (`add(verdict.winner)`; a round ended with Stop doesn't count).
- **The panel** (`QuickDrawResultPanel(verdict, match)`; `names:` since 2026-10-19, "Sam wins the match 2–1": Named Players): "Round 2 of 3" or "Extra round" (`roundLabel`, 24 pt), the round's headline (52 pt; "Player 2 wins on score" when the score broke a same-frame tie), each player's line (34 pt), then **the match** (`matchText`, 34 pt): "Player 2 leads 1–0" / "Level 1–1"; at the end, **"Player 2 wins the match 2–1"** / "Match drawn 1–1" in green at 44 pt (the leader's wins first).
- **Fits any way up:** the panel wraps to the screen's width and, if still too tall (a phone held sideways), scales down rather than overflowing (`FittedBox`, as Play's corrections row).
- **Buttons:** after a round, **Next round** (or **Extra round** when level after three) and **Finish match**; between rounds, Start and Finish match; at the end, **New match** (no rounds won, boards kept). Finish match asks first (`confirmFinishMatch`: "It ends on the rounds won so far; if they are level, it is a draw"), like Finish game. The line between rounds: "Round 2 of 3 (Player 1 leads 1–0). Throwers ready? Tap Start: …".
- **Choose boards again keeps the match** (a board moved mid-match can be chosen again without losing the rounds); leaving Quick draw ends it (nothing is kept: Quick draw isn't in History).

**Next duel is a tap,** not detected (Plan Changes Log, 2026-10-15): the plan suggested waiting to see both boards visited (knives collected), but a tap after collecting is simpler and can't misfire; the boards stay locked, so no re-tapping.

**False starts:** a knife between go − 1 s and go is a false start (impact before go). One thrown earlier is already in the board when watching starts, so it isn't timed: an obvious false start the throwers can see for themselves.

**Checked by** `test/ui/live_quick_draw_screen_test.dart` (Start lights the 5 lights a second apart with a beep each; at go the lights go out and the go beep sounds, with no GO! on screen, watched from 1 s before; with no throws, after the window, "No winner" in large type (≥ 48 pt) with the chime; Next duel keeps the boards; Stop cancels the countdown) and `test/game/quick_draw_live_path_test.dart` (judged from go on the frames' clock: Player 2 wins, ~0.82 s after go).

**Confirmed:** 2026-10-15 (built; Nigel's device check pending: [[Device Test Plan]] → Quick Draw Checks).

## Quick Draw: Draw Round the Boards (2026-10-21)

Requirement: [[Game Type]] (Quick draw), [[Board Finding]]. Story: [[story-checkpoint-quick-draw-areas]].

**Problem:** on Mark's stencilled boards the tapped search sometimes puts the outline at the wrong scale (backlog #20). Mark (Nigel's brother), 2026-10-21, asked to *"draw his finger round the board as a single hit point, not worrying about rings for scoring, just relying on hit time in the area he draws"*.

### Decision: a board drawn round by finger, timed only
- Both Quick draw screens (the live one and the recording) have **Draw round the boards** / **Tap the boards** (`boardsModeButton`, key `quickDrawBoardsMode`), shown until the first board is chosen. Tapping stays the default.
- Drawn: drag a finger round Player 1's board, then Player 2's. `LoopDrawer` draws the path as the finger moves; on lift the loop (fractions of the picture) goes to `BoardChoosing.addDrawnBoard`.
- **Timed, never scored:** any knife that sticks inside the board's watched region counts. The line under a board shows only the time ("0.82 s"); the result says "Player 2 wins: stuck, 0.82 s after go."
- **The same frame is a drawn round:** with no score, nothing breaks the tie (the judge already treats a missing score as a draw: Quick Draw: Go, False Starts and the Winner). Level after three: extra rounds, as usual.
- **Kept for the session** (`boardsDrawnProvider`, not auto-disposed): Choose boards again, and leaving and coming back to Quick draw, keep the choice until the app is closed.
- **Not two-target Play:** Play needs the rings to score each throw, so it never shows the button.

### Decision: the ellipse fitted to the loop
`areaBoard` (`lib/game/area_board.dart`): the loop, in the upright picture's pixels → `fitEllipse` → a `TargetCalibration` whose outer ring is that ellipse and whose rings are the same ellipse scaled 0.2 … 0.8.
- **Why an ellipse, not the raw loop:** a board seen from the side is an ellipse, and everything downstream already works on one: the board's crop (`cropRadii`), the watched region (`WatchRegion.fromCalibration`), the outline editor (dragging, Adjust boards) and `TargetCalibration.within`. A loop of any shape would need its own version of each. The fit also smooths a wobbly finger.
- **Why rings at all:** the entry-point code needs a centre ring. They're never scored (`QuickDrawTargets.areas`) and never drawn (`BoardsPainter` shows only the outline).
- **The picture's size** comes from `pictureSizerProvider` (`uprightPictureSize`): the camera's next frame turned upright, at most **1920 px** (`uprightSizeOf`), the size tapped boards are found in, so drawn and tapped boards share one picture.

**Thresholds** (a loop that fails one → "That loop is too small or too flat for a board."):
- **`minLoopPoints` 8:** fewer is a tap or a flick, not a loop, and too few for a fair fit.
- **`minAreaRadius` 0.03:** the smaller radius at least 3% of the picture's shorter side. Smaller is a slip of the finger, and too small a board for the throw detection to see a knife on.
- **Larger radius at most the shorter side:** anything bigger isn't one board.
- **`minRoundness` 0.35** (minor ÷ major): a board seen from the side is about 0.5, so 0.35 leaves room; flatter is a line or a scribble, whose fit isn't a board.

**Throws:** `QuickDrawWatcher(areas:)` (both screens pass `targets.areas`) gives those players' throws `QuickDrawThrow.scored` false and no score; `JudgedThrow.scored`, `judgedText` and `verdictText` show times only ("A draw: both stuck on the same frame.").

**Options (architectural purity over the quick option):**
- **Quick, not chosen:** a free-shape "hit area" with its own crop, region and watcher path. It would duplicate the crop, watched-region and editor code.
- **Chosen:** the loop becomes an ordinary `TargetCalibration`, marked unscored per player (`QuickDrawTargets.areas`), so the existing machinery is reused unchanged.

**Safety (Review Agent §7):** drawing is on the screen, before anyone throws, like tapping. The in-app Instructions (Quick draw) say on the screen, never at the boards, only when no one is throwing, and that only the time decides. Requirement: [[Instructions and Safety]]. No platform, permission or dependency change.

**Checked by:**
- `test/game/area_board_test.dart`: circle, oval, picture size and rings, wobbly loop; too few points, too small, too big, too flat, a straight line → null
- `quick_draw_targets_test.dart`: areas kept through replace, lock and unlock; clear forgets them
- `quick_draw_judge_test.dart`: times only; the same frame a draw
- `quick_draw_replay_test.dart`: the Quick draw recording with both boards drawn: the same throws on the same frames, no scores, Player 2 still wins
- `live_quick_draw_screen_test.dart`, `quick_draw_screen_test.dart`: switching, drawing both, a tiny loop, the choice kept
- Device checks: [[Device Test Plan]] → Drawn Board Checks (QA0–QA7)

**Confirmed:** 2026-10-21 (built; device checks to come).

> **Later (2026-10-21):** a loop with corners now becomes a four-cornered board, not its oval. See **Quick Draw: Round or Four-Cornered Boards** below.

## Quick Draw: Round or Four-Cornered Boards (2026-10-21)

Requirement: [[Game Type]] (Quick draw), [[Board Finding]], [[Instructions and Safety]]. Story: [[story-checkpoint-board-outlines]] (follows [[story-checkpoint-quick-draw-areas]]).

**Problem:** Nigel, 2026-10-21: a drawn board "might be a circle as you have assumed but sometimes it could be a square or rectangular board … if it looks vaguely circular, fine, but if it looks rectangular make it rectangular. I guess the actual view the camera can see should also factor in." A square board's covering oval misses its corners (a knife there isn't watched) and counts strips beyond its edges as the board.

### Decision: boards answer for their own shape (`BoardShape`)
`lib/vision/board_shape.dart`: throw detection asks the board's shape, not its outer ring.
- **`BoardShape`:** `reach(p)`, `centre`, `halfExtent` (the box round it), `area`, `meanRadius`, `rescaled`, `translated`.
- **`EllipseShape`:** a ring board's outer ring; the same sums as before (`reach` = `Ellipse.normalisedRadius`).
- **`OutlineShape`:** convex corners in order (either way round); `centre` is the corners' average.
- **`TargetCalibration.outline`** (optional corners; null for a round board) and **`shape`** (the outline if set, else the outer ring). `moved`, `within`, the crop and the handle drags carry the corners along.
- **Who asks the shape:** `WatchRegion.fromCalibration` (the box; `target` is now a `BoardShape`), the motion detector's on-target test (`reach` ≤ 1.05), `cropToBoard` (`centre`, `meanRadius`), `findNewObject` (search and touch test) and `minKnifeArea` (`area`).
- **Not asked:** `zoomToFit` (Play only) and the entry point (drawn boards are never scored), so they still use the ellipse. `outer` stays on an outlined board as the oval nearest the loop (its rings feed the entry-point code, never scored).

**Reach** (`OutlineShape.reach`): for each edge, how far the point is from the centre towards that edge, as a share of the edge's own distance from the centre; the largest share wins. So it is 0 at the centre, 1 on the edge, and the outline scaled by k about its centre is where reach is k: the same meaning as an ellipse's normalised radius, so the existing margins (1.05 on-target, `searchMargin`, the watched region's `margin`) mean the same on both shapes.

**Ring boards keep their search square:** `findNewObject` searches a square of side 2 × the ellipse's first semi-axis × `searchMargin` on an `EllipseShape`, as always (the ring tests and duel replays unchanged); an outline searches its own box.

**Options (architectural purity over the quick option):**
- **Quick, not chosen:** keep everything an ellipse and swap a square for the oval covering it. It would miss nothing inside, but count strips outside the board as on it, and a smaller oval would miss the corners.
- **Chosen:** one `BoardShape` the detection code asks, with the ellipse as one case, so a new shape needs no change to the watcher, crop or knife search.

### Decision: round or four corners, decided by the fit
`lib/game/area_board.dart`:
- **`areaBoard`** first **cuts the loop at the picture's edge** (each point clamped into the picture), fits the oval as before (`outer`, the size and roundness thresholds unchanged), then asks `boardOutline`.
- **`boardOutline(loop, oval)`:** the loop's `convexHull` (Andrew's monotone chain) → the four hull points enclosing the most area (`_largestQuad`: for each diagonal, the best point on each side) → kept only when the loop's **mean miss** from the four corners (`|reach − 1|`, averaged over the loop) plus **`cornerMargin` 0.01** is under its mean miss from the oval. Otherwise null (round).
- **Automatic:** no button; the fit decides.

**Measured** (mean miss, oval vs corners):
- Circle: 0 vs 0.27. Shaky circle (20 px): 0.07 vs 0.15.
- Square: 0.10 vs 0. Shaky square: 0.12 vs 0.10.
- Shaky rectangle in perspective: 0.11 vs 0.05.

Every round loop misses its corners by more; every cornered loop misses its oval by more. The margin is a small lean to the oval, so a loop that fits both about as well stays round.

**Why a margin, not a ratio:** first tried "corners under 0.5 × the oval's miss". A square drawn with 12 px of jitter came out round (0.064 vs 0.105), because shaking adds to both misses alike; a ratio punishes a shaky hand, a difference doesn't.

**Corners stay where drawn, in picture coordinates:** a rectangle seen from the side isn't a rectangle in the picture (perspective), so the outline is never squared up. "The actual view the camera can see" is the picture itself.

**Convexity:** `OutlineShape.reach` needs a convex outline. The hull and the largest quad are convex by construction; dragging a corner goes through `TargetCalibration.withCornerAt`, which refuses a move that would fold the outline (`isConvex`: every corner turns the same way).

### Decision: the screen
- **`BoardsPainter`:** a four-cornered board is painted as its outline; while adjusting, a handle on each corner. The player number and result line sit on its box.
- **Adjust boards:** `CalibrationGrab.corner0`…`corner3`. `grabAt` on an outline: the nearest corner within reach (unless the touch is nearer the centre), else inside the outline (`reach` ≤ 1.1) moves it. `BoardsEditor` ranks boards by `shape.reach`.
- **Instruction line:** "Draw a finger round the edge of Player 1's board (round, square or rectangular)." The in-app Instructions (Quick draw): a round board stays round; a square or rectangular one gets four corners to drag into place.
- **Two-target Play unchanged** (it taps and scores ring boards).

**Mark's duel replayed with square boards:** `quick_draw_replay_test.dart` draws each board as a square round it. The same throws; Player 1 on the same frame; Player 2 seen **one frame sooner** (the corners reach further than the oval did); Player 2 still wins.

**Safety (Review Agent §7):** unchanged from drawing round the boards: on the screen, before anyone throws. No platform, permission or dependency change.

**Checked by:**
- `test/vision/board_shape_test.dart`: the ellipse as before; the outline's reach (centre, edge, corner, halfway, outside, either way round, perspective), box, area, rescale, move; a board with an outline through the watched region, crop and smallest knife; a knife in a square board's corner found
- `test/game/area_board_test.dart`: round loops stay round (circle, side-on oval, wobbly, shaky); square, rectangle, perspective rectangle, square on its corner, jittery square → corners where drawn; a board off the picture's edge cut at it
- `quick_draw_replay_test.dart`: Mark's duel with square boards
- `board_adjust_test.dart`: grab and drag a corner, folding refused, move, painted with 4 corner handles, `isConvex`
- `live_quick_draw_screen_test.dart`: a square drawn on the screen → four corners; `instructions_test.dart`
- Device checks: [[Device Test Plan]] → Drawn Board Checks (QA8–QA14)

**Confirmed:** 2026-10-21 (built; device checks to come).

## Ring Finding on Real Boards: Colour Edges, Any Paint (2026-10-11)

> **Later (2026-10-21):** stencilled boards whose rings are painted in arcs with gaps (Mark's) aren't read by this; a tapped fallback finds them. See **Boards With Broken Rings: Tap the Board** below.

**Problem:** the two Live test boards (see Live Test above) are painted in **several colours on wood**:
- board 1: dark bull, wood, red, wood, red
- board 2: red bull, wood, red, wood, dark green

On top of that, they are small (a 140 px crop, bull radius about 8.5 px) and blurred by compression. `ColourRingLocator` assumed two alternating colours, so it found neither.

**Measured truth** (colour averaged all the way round the centre, on the still at the start of each video): the boundaries are at 8.5 / 16.5 / 25–25.5 / 32.5 px, with the outer edge at 41.5–42.5 px. That's almost exactly the IKTHOF proportions: 2, 3 and 4 bull radii. The pale rim beyond, out to about 48 px, is wood (scores 0).

**Decision:** `ColourRingLocator` now reads every candidate centre two ways and keeps the better plausible fit:
1. **Two colours** (as before): A/B runs along rays.
2. **Colour edges** (`_Reading.edges`):
   - Along each ray, the colour change is measured at a scale of about 8–16% of the bull radius, so it ignores grain.
   - The bull's edge is the **strongest** edge between 0.6× and 1.5× the expected bull radius. (The first edge can be texture, or knives inside the bull.)
   - Each further boundary is the strongest edge within ±15% of 2, 3 and 4 **times that ray's own bull edge**. Measuring along the same ray cancels perspective.
   - This is colour-blind: it works whatever the paint.

**Also changed:**
- **Small images are enlarged** (bilinear) to at least 420 px first (`minWorkingSize`). Board 2 was found far more reliably at 3×.
- Each candidate keeps its **best plausible pass**, not its last: re-centring sometimes made a good fit worse.
- **Fits below 40% confidence are rejected** (`minConfidence`, reported as "Rings too unclear"). On the recordings, wrong fits scored 23–47% and right ones 46–78%.

**Result** (every 10 s through each 3-minute video):
- Target 1: 13 of 19 right, 1 wrong.
- Target 2: 8 right, 2 wrong.
- The rest are "not found", mostly when people, knives or a compression jump are in the frame.
- **Both first frames, where the Live test calibrates, are right.**

`test/vision/live_recording_locate_test.dart` guards this. Every earlier fixture (the reference photo, renders, the A4 printout) still passes.

**Rejected:**
- **Paint vs wood by colour distance.** Board 1's inner wood ring comes out pinkish: about 47 from the wood and 52 from the red, so no single cut-off separates them.
- **Picking boundaries from piles of edges across rays.** The speckled wood of board 2 drowned the piles.
- **Expected sizes from the outer estimate.** Hand-painted ring widths and a wrong bull estimate shifted the windows.

## Boards With Broken Rings: Tap the Board (2026-10-21)

Requirement: [[Board Finding]]. Story: [[story-checkpoint-gapped-rings]].

**Problem:** Mark (Nigel's brother) couldn't get Play's **Calibrate → Find target** to fix on his boards (2026-10-20). They are stencilled:
- a sprayed red bull, bare wood, a **black ring painted in four arcs with gaps**, wood, a second broken black ring, then wood to the bark;
- speckled wood, red dots and cracks;
- three boards side by side on a fence, with a net above them, all in one picture.

Before any change (a frame at 1 s of his video): the middle and right boards gave "Rings too unclear", the left a wrong, tiny fit, and the whole picture "found" a target in the net.

**Measured truth** (the middle board, 120 rays from the bull, an ellipse fitted per edge; corrected after an overlay check):
- edges at 27 / 56 / 84.5 / 113 / 141 px, i.e. **0.19 / 0.40 / 0.60 / 0.80** of the outer edge: IKTHOF's spacing after all (an earlier rough reading of 0.16 / 0.33 / 0.58 / 0.74 was taken off-centre);
- the answer key is `test/fixtures/marks_boards/truth.json`; the middle board's soft 0.4 edge (speckle to black) is allowed 10%.

**What actually fails** (traced on the middle board): from its true centre the usual edge reading already fits the rings, so the gaps alone weren't the problem. What fails is **where the search starts and how big it thinks the board is**:
- no single-colour region is centred on a board whose rings are arcs on speckled wood, so no candidate centre is near the middle;
- from a start a few px off, the size comes from the first colour change, which is a speck;
- each ray measures the rings from its own bull edge, which on a sprayed, speckled bull is noise.

### Decision: a fallback for a tapped board, by ring alignment
`ColourRingLocator` step 6 (in its doc comment), only when a seed (a tap) is given and the usual search found nothing plausible:
1. **Ring alignment** (`_alignedStarts`): from the true centre every ring edge is at one distance all round, so the colour change averaged over every direction, by distance (`_radialProfile`, 72 rays) has sharp peaks; from a little off it smears, speckle never lines up, and gaps only lower a peak. Centres within `_alignReach` (8% of the shorter side) round the tap are scored by the sum of their profile's 6 highest values, on a copy shrunk to ~`_alignSize` (360) px for speed: a coarse grid, then a finer one round each of the `_alignStarts` (3) best, kept apart.
2. **Size:** for each of the 3 starts, the bull radius whose 1×, 2×, 3× and 4× multiples (the boundary ratios) land on the strongest peaks.
3. **Edges with the size fixed:** the usual edge reading (`_edgePoints(fixedScale: true)`), with every ray measuring from the known bull size rather than its own bull edge, and keeping rays whose bull edge isn't seen.
4. **The fit must be big enough:** its outer radius at least 10% of the searched window's shorter side (`_alignMinShare`): grass under a tap made a 6% fit. Mark's middle board is ~29%, the Quick draw boards ~19%.

**The tap fallback's fits only:** a bull radius under 6 working px (`_minBullRadius`) is "Target too small". Edges are measured over ~8–16% of the bull's radius, so a smaller bull is grain or speckle that happens to look like rings. *Not* applied to the usual search (changed after the Traceability review, 2026-10-21): there a small, distant board's rejected fit still guides `CoarseToFineLocator`'s close-up, and a "too small" rejection would hide it and stop the 1200 px retry.

### Decision: Tap the board on Play's calibration
- `CalibrationScreen` has a **Tap the board** button until the target is locked ("Cancel tap" while waiting).
- In tap mode the outline is hidden and the status says *"Tap the middle of the board in the picture."*. The next tap runs `locateTappedInFrame` at that point (as Quick draw does), **at the camera's current zoom**: zooming would move the board from under the tap.
- The result starts the calibration as Find target's does: adjust, then Lock target.
- Find target's not-found texts now suggest tapping the board. The same tap picks one board when several are in the picture.
- **Safety** ([[Instructions and Safety]]; Review Agent §7): the "only when no one is throwing" note shows in tap mode too, and the Instructions (Calibrating the target) say to tap only when no one is throwing.

### Decision: no automatic fallback
Find target with no tap behaves exactly as before. The alignment fallback was tried from the picture's middle with no tap, on Live test board 2: it turned frames the usual search couldn't read into near misses (a ring 10–20% off), with confidence overlapping Mark's real fits, so no cut-off could separate them. A wrong outline that looks right is worse than "not found" plus a tap.

### Tried and rejected
Each broke boards that work today, or didn't help:
- **Gaps counted as neutral in the confidence:** the rays through a gap find wood grain, not nothing.
- **Dropping weak edges.**
- **Centre votes along edge gradients:** a broad hill, not a peak.
- **A size from the averaged edge profile as a third reading,** even only as a fallback: Live test board 2 went from 2 to 5 wrong frames.
- **The alignment fallback with no tap,** from the picture's middle (see above).
- **Other ring proportions** (planned as Task 3): not needed. Measured properly, Mark's rings are IKTHOF's.

### Results
- **Middle board**, tapped on its bull or 7–10 px off (4 taps): found, the rings on the paint (28 / 55 / 86 / 112 / 140 px vs measured 27 / 56 / 84.5 / 113 / 141).
- **Right board** (in shade, against the sky): found tapped on its bull or 10 px above. Taps 10 px right or (−7, 7) give a wrong fit: a known limit; drag the outline, or tap again ([[Known Issues]]).
- **Left board:** cut off by the picture's edge; not a usable view.
- **A tap on the fence** finds nothing.
- **Unchanged:** every earlier fixture (the Live test recordings, the Quick draw taps including "a tap on the grass finds nothing", the ring locator's tests).
- Guarded by `test/vision/marks_boards_test.dart` and `test/ui/calibration_screen_test.dart`. Device checks: [[Device Test Plan]] → Board Finding Checks.

**Confirmed:** 2026-10-21 (Nigel approved the plan; Mark's scoring: red 5, wood 4, inner black 3, wood 2, outer black 1).
