# Cloud Config Setup

Everything outside this repo that the Thrower App's cloud side depends on: AWS (Amplify, Cognito, IAM, CDK), Google Cloud, Apple Developer and, later, the payment services. It covers where each thing lives, who sets it up, and how each secret is sourced. Written 2026-10-20 (Nigel: "document how they are sourced for the project … some sort of 'cloud config setup'"). Laid out as headings and lists rather than wide tables, so it reads in Obsidian without cut-off cells.

Day-to-day how-tos stay in [[Common Tasks]] (Connect the App to the Amplify Backend; Set Up Google and Sign in with Apple). Gotchas met so far are in [[Known Issues]].

**Thrower shares nothing with WhereWillWeVisit** (Nigel, 2026-10-20): every client, key, ID, secret and payment account is **new and Thrower's own**. The only common ground is the AWS account itself (and the Apple and Google developer accounts they're made in). Nothing is copied or reused from WhereWillWeVisit, even as a stopgap.

Related: [[story-checkpoint-app-user-accounts]] (accounts, stage 2), [[Accounts and Sign-In]], [[Subscriptions]], [[Design Decisions]] → User Accounts Required, [[Mac Handoff]].

---

## 1. AWS

### Account and region
- **Account:** `445567075330`. The same AWS account as WhereWillWeVisit, but nothing in it is shared: Thrower has its own app, region, role, pools, tables and secrets.
- **Region:** **Europe (London) `eu-west-2`** (Nigel, 2026-10-19). UK users' data stays in the UK (UK GDPR).
- **The PC's AWS CLI:** the default profile's region is **Sydney** (WhereWillWeVisit's), so Thrower commands need `AWS_REGION=eu-west-2` ([[Known Issues]]).

### Amplify app
- **Name:** `thrower_app`. **App ID:** **`d1yhmpx84pdvnh`**.
- **Set up by:** Nigel, in the console, connected to GitHub `nrbondnz/thrower_app`.
- **Build:** `amplify.yml` deploys `amplify/` (`ampx pipeline-deploy`) and serves `web_public/`.
- **Branches:**
  - `main` = production (connected).
  - `dev` = development (**not yet created**; see section 6).
  - Each branch gets its own Cognito pool and its own data tables.

### Service role
- **Role:** **`amplify-thrower-app-backend-role`**, trusted by `amplify.amazonaws.com`, with AWS's managed policy `AmplifyBackendDeployFullAccess`.
- **Set up by:** Claude, via the CLI, with Nigel's OK (2026-10-19).
- **Why:** without it, builds run as Amplify's own role and the deploy fails ([[Known Issues]]).

### CDK bootstrap
- **What:** the `CDKToolkit` stack in `eu-west-2`. Gen 2 deploys need it, **once per region**.
- **Set up by:** Claude, 2026-10-19: `npx cdk bootstrap aws://445567075330/eu-west-2`.

### Cognito (sign-in)
- **User pool (`main`):** `eu-west-2_TmfChXYyo`, made by the deploy. Email sign-in; Google and Apple from Task 3.
- **Sign-in domains** (set in `amplify/backend.ts`, `domainPrefixByBranch`; made by the deploy that adds Google and Apple):
  - `main`: `throwerapp.auth.eu-west-2.amazoncognito.com`
  - `dev`: `throwerapp-dev.auth.eu-west-2.amazoncognito.com`
  - They're hard to rename later (it takes two deploys). Google's and Apple's redirect lists need each one (section 2).
- **Managed Login branding:** per app client. Not in CDK, so **Claude runs it by CLI once the domain exists**. Without it Cognito shows "Login pages unavailable" (WhereWillWeVisit's lesson):
  ```bash
  aws cognito-idp create-managed-login-branding --user-pool-id <pool> --client-id <client> --use-cognito-provided-values --region eu-west-2
  ```
- **Sign-up code emails:** Cognito's own sender (about 50 a day). **Before launch:** set up SES in `eu-west-2` with production access, then point Cognito at it ([[Known Issues]]).

### Data (the backup)
- AppSync and DynamoDB: `KeptGame` and `PlayerNameList`, owner-only (`amplify/data/resource.ts`), made by the deploy. Accounts Task 4.

### The app's settings file
- `assets/config/amplify_outputs.json`: gitignored, one per branch. **Not a secret** (just IDs and endpoints).
- **Generated on each build machine:**
  ```bash
  AWS_REGION=eu-west-2 npx ampx generate outputs --app-id d1yhmpx84pdvnh --branch main --out-dir assets/config
  ```
- Without it, the app runs signed out.

---

## 2. The Six Sign-In Secrets (Accounts Task 3)

### Where they live
- Amplify console → `thrower_app` → **Hosting → Secrets → Manage secrets**, applied to **all branches**.
- Amplify stores them in AWS Systems Manager Parameter Store as SecureStrings: `/amplify/shared/d1yhmpx84pdvnh/<NAME>` in `eu-west-2`.
- `amplify/auth/resource.ts` reads them with `secret('<NAME>')`.
- **They never go in git, a chat, a doc or a screenshot.** A deploy fails until all six exist.

### Who sets them
- **Nigel.** Claude doesn't read or copy secret values. Copying WhereWillWeVisit's was refused by the safety check, which was right.

### All new: nothing from WhereWillWeVisit
- All six are **created fresh for Thrower** (Nigel, 2026-10-20). Don't reuse or copy WhereWillWeVisit's Google client, Services ID or keys, even temporarily. WhereWillWeVisit's secrets stay in its own app (`d1wqo0bm59b4p9`, Sydney); its list is due a cleanup (its Known Issues → Backlog).
- **Why:**
  - Google's consent screen and Apple's sign-in sheet name **Thrower**, not WhereWillWeVisit.
  - Each app's users get their own Apple user IDs (Apple keys aren't grouped).
  - Revoking or rotating one app's credentials never breaks the other.
  - The two apps can move teams, projects or regions independently.

### Summary

| # | Secret | Source |
|---|---|---|
| 1 | `GOOGLE_CLIENT_ID` | New Thrower Google project |
| 2 | `GOOGLE_CLIENT_SECRET` | The same new client |
| 3 | `APPLE_TEAM_ID` | Thrower's team, `QCQ64RLD77` |
| 4 | `APPLE_CLIENT_ID` | New Services ID |
| 5 | `APPLE_KEY_ID` | New Sign in with Apple key |
| 6 | `APPLE_PRIVATE_KEY` | That new key's `.p8` |

### 1. `GOOGLE_CLIENT_ID`
- **What:** the Google OAuth client's ID (ends `….apps.googleusercontent.com`).
- **How to source it** (Google Cloud console):
  1. **Create a new Google Cloud project** for Thrower (e.g. "Thrower App"). Don't use WhereWillWeVisit's project.
  2. **APIs & Services → OAuth consent screen:** External; app name **Thrower**; support email; scopes `email`, `profile`, `openid`.
  3. **Credentials → Create credentials → OAuth client ID → Web application.**
  4. **Authorized redirect URIs:** add both:
     - `https://throwerapp.auth.eu-west-2.amazoncognito.com/oauth2/idpresponse`
     - `https://throwerapp-dev.auth.eu-west-2.amazoncognito.com/oauth2/idpresponse`
  5. Copy the **Client ID**.
- **New:** the client lives in Thrower's own project, whose consent screen is named Thrower.

### 2. `GOOGLE_CLIENT_SECRET`
- **What:** the same client's secret.
- **How to source it:** the client from #1 → **Client secret**.
- **New:** with #1 (they're a pair).

### 3. `APPLE_TEAM_ID`
- **What:** the Apple developer team.
- **How to source it:** developer.apple.com → **Membership details → Team ID**.
- **Value:** **`QCQ64RLD77`**, Thrower's team. Everything Apple below (the App ID, Services ID and key) is created in this team.

### 4. `APPLE_CLIENT_ID`
- **What:** the **Services ID**, which Cognito uses as Apple's client ID for its web sign-in flow (not the App ID).
- **How to source it** (developer.apple.com):
  1. **Identifiers → App IDs → `nz.nrbond.thrower`:** tick **Sign in with Apple**, and save.
  2. **Identifiers → Services IDs → +:** e.g. **`nz.nrbond.thrower.signin`**.
  3. Tick **Sign in with Apple → Configure:**
     - primary App ID: `nz.nrbond.thrower`;
     - **Domains:** `throwerapp.auth.eu-west-2.amazoncognito.com` and `throwerapp-dev.auth.eu-west-2.amazoncognito.com`;
     - **Return URLs:** the two `…/oauth2/idpresponse` URLs from #1.
  4. The secret's value is the **Services ID itself** (e.g. `nz.nrbond.thrower.signin`).
- **New:** Thrower's own Services ID.

### 5. `APPLE_KEY_ID`
- **What:** the Sign in with Apple key's ID.
- **How to source it** (developer.apple.com):
  1. **Keys → +.**
  2. Tick **Sign in with Apple → Configure:** primary App ID `nz.nrbond.thrower`.
  3. Register, then note the **Key ID**.
- **New:** Thrower's own key, with `nz.nrbond.thrower` as its primary App ID. It's never grouped with another app's (grouping gives both apps the same Apple user ID).

### 6. `APPLE_PRIVATE_KEY`
- **What:** that key's private key.
- **How to source it:** the same page → **Download** the `.p8`.
  - **It can be downloaded once only.** Keep it in the password manager.
  - The secret's value is the **whole text** of the `.p8`, including the `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` lines.
- **New:** with #5.

### After setting them
- Tell Claude. It:
  1. pushes the Task 3 commit (already made, not yet pushed);
  2. watches the deploy;
  3. runs the Managed Login branding command;
  4. regenerates the settings file;
  5. installs the build on the Samsung with `adb install -r` (keeping the app's data).

### Changing one later (rotation, or a revoked key)
- Update it in the console, then redeploy each branch (Amplify → Redeploy this version). The values are read at deploy time.

---

## 3. iOS (Xcode on the Mac)
- **Sign in with Apple capability:** Runner → Signing & Capabilities → **+ Sign in with Apple**. This makes `Runner.entitlements` and sets `CODE_SIGN_ENTITLEMENTS` in Debug, Release and Profile. Nigel clicks; Claude explains ([[Mac Handoff]] section 00000).
- **Store review:** check that the Sign in with Apple button meets Apple's style. WhereWillWeVisit was rejected under Guideline 4 for a custom button.

---

## 4. The Public Site and Store Listings
- `web_public/` is served by Amplify Hosting at `https://main.d1yhmpx84pdvnh.amplifyapp.com`. A custom domain can come later.
- **Privacy policy:** [[Privacy Policy (Draft)]] → `web_public/privacy.html` once Nigel approves it. Its URL goes in App Store Connect and Google Play, with the privacy labels it lists.

---

## 5. Future: Subscriptions (Not Built; Requirement Backlogged)

From [[Subscriptions]]: 14 days free, then subscribe; the Game Centre is the reason to pay. **Nigel, 2026-10-20: "stripe will be used on android"**, a requirement, backlogged as [[backlog]] #15.

### iOS: Apple in-app purchase
- **Why:** Apple requires its own in-app purchase for digital subscriptions.
- **Cloud config it will need:**
  - subscription products in App Store Connect;
  - an **App Store Server API** key (to check purchases on the server);
  - an **App Store Server Notifications** URL (a backend function).
- **Secrets (Amplify, new for Thrower;** the same *pattern* as WhereWillWeVisit's `verifyAppleTransaction` and `appleServerNotifications`, but Thrower's own key, never WhereWillWeVisit's**):**
  - `APPLE_IAP_ISSUER_ID`: App Store Connect → Users and Access → Integrations → **In-App Purchase** keys → Issuer ID.
  - `APPLE_IAP_KEY_ID`: a key generated on that same page.
  - `APPLE_IAP_PRIVATE_KEY`: that key's `.p8` (downloaded once).

### Android: Stripe (Nigel's requirement)
- **Cloud config it will need:**
  - **Thrower's own Stripe account** (not WhereWillWeVisit's), with products and prices (a subscription);
  - a **webhook** endpoint (a backend function) for subscription events;
  - the publishable key in the app.
- **Secrets (Amplify, new for Thrower)**, named as WhereWillWeVisit's but with Thrower's own values, each from Thrower's Stripe dashboard (Developers → API keys; the webhook's signing secret):
  - `STRIPE_SECRET_KEY`
  - `STRIPE_PUBLISHABLE_KEY`
  - `STRIPE_WEBHOOK_SECRET`
  - test-mode twins: `STRIPE_SECRET_TEST_KEY`, `STRIPE_WEBHOOK_SECRET_TEST`

### ⚠️ To check before building the Android side: Google Play's payments policy
- For an app distributed on Google Play, digital goods and subscriptions bought **in the app** must normally use **Google Play Billing**.
- Other billing (such as Stripe) is allowed only:
  - under Google's **alternative / user-choice billing** programmes, which apply in particular regions, need enrolment, and may still carry a Google service fee; or
  - for purchases made **outside** the app (e.g. a web checkout).
- Check the current policy for the UK and the other target countries, and whether enrolment is needed, before Stripe goes into the Android app. The Review Agent's store check applies. Policy facts change, so verify them at the time.

---

## 6. Setting Up a New Environment (e.g. `dev`)
1. `git checkout -b dev && git push -u origin dev` (Claude, when asked).
2. Amplify console → **Add branch → `dev`**. The six secrets already apply to all branches.
3. After its first deploy, run Managed Login branding for its app client. The `throwerapp-dev` URLs are already on the Google and Apple lists (section 2).
4. Generate the settings file with `--branch dev` for test builds.
