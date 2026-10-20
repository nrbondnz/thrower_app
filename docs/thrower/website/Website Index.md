---
tags: [website, index]
---

# Website Index

The public website for the Thrower App, at **knifeandaxethrower.com** (Nigel, 2026-10-20). Requirement: [[Website]]. Decision: [[Design Decisions#Website: Astro, Orphan Branches, Its Own Amplify App (2026-10-20)]].

## At a Glance

| Item | Value |
|---|---|
| Domain | `knifeandaxethrower.com` (Route 53, registered 2026-10-20) |
| Hosted zone | `Z06450252M8O38ES3PDKG` |
| Stack | Astro 7 + TypeScript, static |
| Production branch | `website` |
| Development branch | `website-dev` |
| Amplify app | `knifeandaxethrower-website` (to create) |

## Branches and Domains

- **`website-dev`** → `dev.knifeandaxethrower.com`. Day-to-day work goes here.
- **`website`** → `knifeandaxethrower.com` (and `www.`). Release by merging `website-dev` into `website`.
- Both are **orphan branches**: they share no history with `main` and hold only the site. The Flutter app, its backend (`amplify/`) and these docs stay on `main`.
- Never merge `main` into a website branch, or the other way round.

## Working on the Site

The site has its own folder on the PC, a **git worktree** next to the app, so switching to it never swaps the app's files under Obsidian or the IDE:

- **Folder:** `C:\dev\flutter_projs\thrower_app-website` (branch `website-dev`).
- **Made with:** `git worktree add --orphan -b website-dev ../thrower_app-website` (from the app's folder).
- **Run:** `npm install`, then `npm run dev` (http://localhost:4321).
- **Build:** `npm run build` runs `astro check` (TypeScript) and writes the static site to `dist/`.
- **Lock file:** make it with npm 10 (`npx -y npm@10 install`), as the Amplify build does; npm 11's lock fails `npm ci` there ([[Known Issues]]).
- **Node:** 22.22 or newer (Astro 7). `amplify.yml` runs `nvm install 22` because the build image's Node 22 may be older.

### Files on the branch

- `src/pages/`: one file per page (`index.astro` is the home page). Pages can also be Markdown.
- `src/layouts/Base.astro`: the shared page frame (head, header, footer, colours, dark mode).
- `public/`: files served as they are (`favicon.svg`).
- `amplify.yml`: **frontend only**, no backend phase, so a website build can never deploy or change the app's backend.
- `README.md`: a short pointer back to this page.

## Hosting: Setup Steps

### 1. Create the Amplify app (Nigel, in the console)
The app has to be connected to GitHub once, which only the console can do.
1. AWS console, region **London (`eu-west-2`)** → **AWS Amplify → Create new app**.
2. **GitHub** → repository **`nrbondnz/thrower_app`** → branch **`website`**.
3. App name: **`knifeandaxethrower-website`**.
4. Amplify finds `amplify.yml`. No service role is needed (no backend). **Save and deploy.**

### 2. Connect `website-dev` and the domain (Claude, by CLI)
Once the app exists:
1. Connect the `website-dev` branch (`aws amplify create-branch`, stage Development).
2. Add the domain (`aws amplify create-domain-association`):
   - the root and `www` → `website`;
   - `dev` → `website-dev`.
3. The domain's hosted zone is in the same AWS account, so Amplify adds the DNS records and the SSL certificates itself. It takes up to about 30 minutes.

### Status
- [x] Domain registered, hosted zone made (2026-10-20)
- [x] Branches `website-dev` and `website` pushed with the Astro starter (2026-10-20)
- [ ] Amplify app created (Nigel)
- [ ] `website-dev` connected; domains added (Claude)

## Content

### Now
- **Home:** what the app does, its main features, "coming soon" to the stores, and the safety line (keep the phone and yourself out of the line of throw).

### Planned
- **Privacy policy:** `/privacy`, from [[Privacy Policy (Draft)]] once Nigel approves it. Its URL goes in App Store Connect and Google Play.
- **Support:** a contact page (both stores want a support URL).
- **How to play:** setup, the rules (KATTA), Quick draw; it can follow the in-app Instructions.
- **Later:** store badges once the app is live; the [[Rankings|Game Centre]] (leaderboards), which would read the app's backend.

## Related
- [[Cloud Config Setup]] (section 4, the public site)
- [[Accounts Roadmap]] (the Game Centre)
