# Knife and Axe Thrower: website

The public website for the Thrower App, at **knifeandaxethrower.com**. Astro + TypeScript, a static site served by AWS Amplify Hosting.

This branch is an **orphan**: it holds only the website, not the Flutter app or its backend (those are on `main`).

- **`website-dev`:** development, deployed to `dev.knifeandaxethrower.com`. Work here.
- **`website`:** production, deployed to `knifeandaxethrower.com`. Merge `website-dev` into it to release.

## Run it

```bash
npm install
npm run dev      # http://localhost:4321
npm run build    # astro check, then the static site in dist/
```

Node 22.22 or newer (Astro 7). Make the lock file with npm 10, as the Amplify build does: `npx -y npm@10 install`.

## Docs

The docs live in the Obsidian vault on `main`: `docs/thrower/website/Website Index.md`.
