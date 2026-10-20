---
tags: [website, index]
---

# Website Index

The public website for the Thrower App, at **knifeandaxethrower.com** (Nigel, 2026-10-20). Requirement: [[Website]]. Decision: [[Design Decisions#Website: Astro, Orphan Branches, in the Same Amplify App (2026-10-20)]].

## At a Glance

| Item | Value |
|---|---|
| Domain | `knifeandaxethrower.com` (Route 53, registered 2026-10-20) |
| Hosted zone | `Z06450252M8O38ES3PDKG` |
| Stack | Astro 7 + TypeScript, static |
| Production branch | `website` |
| Development branch | `website-dev` |
| Amplify app | `thrower_app` (`d1yhmpx84pdvnh`), with `main` |

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

## Hosting

The website branches are **branches of the existing `thrower_app` Amplify app** (`d1yhmpx84pdvnh`, London), next to `main` (Nigel, 2026-10-20). Each branch builds from its own `amplify.yml`: the website's has no backend phase, so a website build never deploys or changes the app's backend.

- **`website`:** stage Production; `https://website.d1yhmpx84pdvnh.amplifyapp.com`; first build OK 2026-10-20.
- **`website-dev`:** stage Development; `https://website-dev.d1yhmpx84pdvnh.amplifyapp.com`; first build OK 2026-10-20.
- Both auto-build on push. Added by CLI (`aws amplify create-branch`, framework Astro).

### Custom domain
`knifeandaxethrower.com` is attached to the app (`aws amplify create-domain-association`, 2026-10-20):
- the root and `www` → `website`;
- `dev` → `website-dev`.

The hosted zone is in the same AWS account, so Amplify adds the DNS records and the SSL certificate itself (up to about 30 minutes; it shows as "Available" under **Hosting → Custom domains**).

### Status
- [x] Domain registered, hosted zone made (2026-10-20)
- [x] Branches `website-dev` and `website` pushed with the Astro starter (2026-10-20)
- [x] Both branches added to the `thrower_app` Amplify app and built (2026-10-20)
- [x] Domain live with an Amplify-managed certificate (2026-10-20): `https://knifeandaxethrower.com`, `www.` and `dev.` all serve the site

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
