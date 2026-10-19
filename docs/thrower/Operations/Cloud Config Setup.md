# Cloud Config Setup

Everything outside this repo that the Thrower App's cloud side depends on: AWS (Amplify, Cognito, IAM, CDK), Google Cloud, Apple Developer and, later, the payment services. It covers where each thing lives, who sets it up, and how each secret is sourced. Written 2026-10-20 (Nigel: "document how they are sourced for the project … some sort of 'cloud config setup'"). How-to steps for day-to-day use stay in [[Common Tasks]] (Connect the App to the Amplify Backend; Set Up Google and Sign in with Apple). Gotchas met so far are in [[Known Issues]].

Related: [[story-checkpoint-app-user-accounts]] (accounts, stage 2), [[Accounts and Sign-In]], [[Subscriptions]], [[Design Decisions]] → User Accounts Required, [[Mac Handoff]].

---

## 1. AWS

| Item | Value | Set up | Notes |
|---|---|---|---|
| Account | `445567075330` | existing (shared with WhereWillWeVisit) | The default AWS CLI profile on the PC. Its region is **Sydney**, so pass `AWS_REGION=eu-west-2` for Thrower ([[Known Issues]]) |
| Region | **Europe (London) `eu-west-2`** | Nigel, 2026-10-19 | UK users' data stays in the UK (UK GDPR) |
| Amplify app | **`thrower_app`**, App ID **`d1yhmpx84pdvnh`** | Nigel, in the console, connected to GitHub `nrbondnz/thrower_app` | Builds with `amplify.yml`: deploys `amplify/` (`ampx pipeline-deploy`) and serves `web_public/` |
| Branches | `main` = production (connected); `dev` = development (**not yet created**) | Nigel adds `dev` in the console once the git branch exists | Each branch gets its own Cognito pool and data tables |
| Service role | **`amplify-thrower-app-backend-role`**, trusted by `amplify.amazonaws.com`, with AWS's `AmplifyBackendDeployFullAccess` | Claude via the CLI, Nigel's OK, 2026-10-19 | Without it, builds run as Amplify's own role and the deploy fails |
| CDK bootstrap | the `CDKToolkit` stack in `eu-west-2` | Claude (`npx cdk bootstrap aws://445567075330/eu-west-2`), 2026-10-19 | **Once per region.** Gen 2 deploys need it |
| Cognito user pool (`main`) | `eu-west-2_TmfChXYyo` | made by the deploy | Email sign-in; Google and Apple from Task 3 |
| Sign-in domains | `throwerapp.auth.eu-west-2.amazoncognito.com` (`main`), `throwerapp-dev.auth.eu-west-2.amazoncognito.com` (`dev`) | `amplify/backend.ts` (`domainPrefixByBranch`), made by the deploy that adds Google and Apple | Hard to rename (two deploys). Google's and Apple's redirect lists need each one |
| Managed Login branding | per app client | **Claude, by CLI after the domain exists** (`aws cognito-idp create-managed-login-branding … --use-cognito-provided-values --region eu-west-2`) | Not in CDK. Without it Cognito shows "Login pages unavailable" (WhereWillWeVisit's lesson) |
| Data (backup) | AppSync and DynamoDB: `KeptGame`, `PlayerNameList`, owner-only | `amplify/data/resource.ts`, made by the deploy | Task 4 |
| Email for sign-up codes | Cognito's own sender (about 50 a day) | default | **Before launch:** SES in `eu-west-2` with production access, then point Cognito at it ([[Known Issues]]) |
| The app's settings | `assets/config/amplify_outputs.json` (gitignored, per branch) | **generated on each build machine**: `AWS_REGION=eu-west-2 npx ampx generate outputs --app-id d1yhmpx84pdvnh --branch main --out-dir assets/config` | Without it the app runs signed out. Not a secret (IDs and endpoints) |

## 2. The Six Sign-In Secrets (Accounts Task 3)

**Where they live:** the Amplify console → `thrower_app` → **Hosting → Secrets → Manage secrets**, applied to **all branches**. Amplify stores them in AWS Systems Manager Parameter Store as SecureStrings under `/amplify/shared/d1yhmpx84pdvnh/<NAME>`, in `eu-west-2`. `amplify/auth/resource.ts` reads them with `secret('<NAME>')`. **They never go in git, a chat, a doc or a screenshot.** A deploy fails until all six exist.

**Who sets them:** Nigel. Claude doesn't read or copy secret values: copying WhereWillWeVisit's was refused by the safety check, which was right.

**New or shared with WhereWillWeVisit?** All six should be **new for Thrower**. WhereWillWeVisit's are in its own app (`d1wqo0bm59b4p9`, Sydney); its secrets list is due a cleanup (its Known Issues → Backlog).

| # | Secret | What it is | How to source it | New for Thrower? |
|---|---|---|---|---|
| 1 | **`GOOGLE_CLIENT_ID`** | The OAuth client's ID (`….apps.googleusercontent.com`) | **Google Cloud console:** a project for Thrower → **APIs & Services → OAuth consent screen** (External; app name **Thrower**; support email; scopes `email`, `profile`, `openid`) → **Credentials → Create credentials → OAuth client ID → Web application** → **Authorized redirect URIs:** `https://throwerapp.auth.eu-west-2.amazoncognito.com/oauth2/idpresponse` and `https://throwerapp-dev.auth.eu-west-2.amazoncognito.com/oauth2/idpresponse` → copy the **Client ID** | **New.** The consent screen belongs to the *project*, so sharing WhereWillWeVisit's client would show "WhereWillWeVisit" when signing into Thrower. Sharing still works if needed (add the two redirect URIs to it) |
| 2 | **`GOOGLE_CLIENT_SECRET`** | That client's secret | The same client → **Client secret** | **New**, with #1 (they're a pair) |
| 3 | **`APPLE_TEAM_ID`** | The Apple developer team | developer.apple.com → **Membership details → Team ID** | **`QCQ64RLD77`** (Thrower's team). The same as WhereWillWeVisit's only if that app is in the same team |
| 4 | **`APPLE_CLIENT_ID`** | The **Services ID**, which Cognito uses as Apple's client ID for its web sign-in flow (not the App ID) | developer.apple.com → **Identifiers → App IDs → `nz.nrbond.thrower`**: tick **Sign in with Apple**. Then **Identifiers → Services IDs → +**, e.g. **`nz.nrbond.thrower.signin`** → tick Sign in with Apple → **Configure**: primary App ID `nz.nrbond.thrower`; **Domains** `throwerapp.auth.eu-west-2.amazoncognito.com` and `throwerapp-dev.auth.eu-west-2.amazoncognito.com`; **Return URLs** the two `…/oauth2/idpresponse` URLs. The secret's value is the Services ID itself | **New** (per app) |
| 5 | **`APPLE_KEY_ID`** | The Sign in with Apple key's ID | developer.apple.com → **Keys → +** → tick **Sign in with Apple** → **Configure**: primary App ID `nz.nrbond.thrower` → register → note the **Key ID** | **New.** A key belongs to one team and one primary App ID; sharing means grouping the apps, which gives both the same Apple user ID |
| 6 | **`APPLE_PRIVATE_KEY`** | That key's private key | The same page → **Download** the `.p8`. **It can be downloaded once only:** keep it in the password manager. The secret's value is the whole text of the `.p8`, including the `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` lines | **New**, with #5 |

**After setting them:** tell Claude. It pushes the Task 3 commit (already made, not yet pushed), watches the deploy, runs the Managed Login branding command, regenerates the outputs, and installs the build on the Samsung (with `adb install -r`, keeping the app's data).

**Changing one later** (rotation, or a key revoked): update it in the console, then redeploy each branch (Amplify → Redeploy this version), since the values are read at deploy time.

## 3. iOS (Xcode on the Mac)

- **Sign in with Apple capability:** Runner → Signing & Capabilities → **+ Sign in with Apple** (makes `Runner.entitlements`; `CODE_SIGN_ENTITLEMENTS` in Debug, Release and Profile). Nigel clicks; Claude explains ([[Mac Handoff]] section 00000).
- **Store review:** check the Sign in with Apple button meets Apple's style. WhereWillWeVisit was rejected under Guideline 4 for a custom button.

## 4. The Public Site and Store Listings

- `web_public/` is served by Amplify Hosting (`https://main.d1yhmpx84pdvnh.amplifyapp.com`). A custom domain can come later.
- **Privacy policy:** [[Privacy Policy (Draft)]] → `web_public/privacy.html` once Nigel approves it. Its URL goes in App Store Connect and Google Play, with the privacy labels it lists.

## 5. Future: Subscriptions (Not Built; Requirement Backlogged)

From [[Subscriptions]] (14 days free, then subscribe; the Game Centre is the reason to pay). **Nigel, 2026-10-20: "stripe will be used on android"**: a requirement, backlogged ([[backlog]] #15).

| Platform | Payments | Cloud config it will need | Secrets (Amplify, new for Thrower) |
|---|---|---|---|
| **iOS** | Apple **in-app purchase** (StoreKit). Required by Apple for digital subscriptions | Subscription products in App Store Connect; the **App Store Server API** key (to check purchases on the server); an **App Store Server Notifications** URL (a backend function) | `APPLE_IAP_ISSUER_ID` (App Store Connect → Users and Access → Integrations → **In-App Purchase** keys → Issuer ID), `APPLE_IAP_KEY_ID` and `APPLE_IAP_PRIVATE_KEY` (a key generated there; `.p8`, downloaded once). As WhereWillWeVisit's `verifyAppleTransaction` and `appleServerNotifications` |
| **Android** | **Stripe** (Nigel's requirement) | A Stripe account (products and prices; a subscription); a **webhook** endpoint (a backend function) for subscription events; the publishable key in the app | `STRIPE_SECRET_KEY`, `STRIPE_PUBLISHABLE_KEY`, `STRIPE_WEBHOOK_SECRET`, and test-mode twins (`STRIPE_SECRET_TEST_KEY`, `STRIPE_WEBHOOK_SECRET_TEST`), as WhereWillWeVisit's. Each from the Stripe dashboard (Developers → API keys; the webhook's signing secret) |

**⚠️ To check before building the Android side: Google Play's payments policy.** For an app distributed on Google Play, digital goods and subscriptions bought *in the app* must normally use **Google Play Billing**. Other billing (such as Stripe) is allowed only under Google's alternative and user-choice billing programmes, which apply in particular regions and need enrolment (Google may still charge a service fee), or for purchases made **outside** the app (e.g. a web checkout). Check the current policy for the UK and the other target countries, and whether enrolment is needed, before Stripe goes into the Android app. The Review Agent's store check applies. Policy facts change, so verify them at the time.

## 6. Setting Up a New Environment (e.g. `dev`)
1. `git checkout -b dev && git push -u origin dev` (Claude, when asked).
2. Amplify console → **Add branch → `dev`** (the six secrets apply to all branches).
3. After its first deploy: Managed Login branding for its app client. The `throwerapp-dev` URLs are already on the Google and Apple lists (section 2).
4. Generate outputs with `--branch dev` for test builds.
"""
