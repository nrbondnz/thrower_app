# Working with Nigel

> Read this file at the start of every new conversation session.

Set up 2026-10-04, modelled on the WhereWillWeVisit project's version (`C:\dev\flutter_projs\whereinuk\where_in_nz_v3\docs\working-with-nigel.md`). The working habits are carried over as they are. The project-specific sections are placeholders, filled in as Thrower App's architecture is decided in [[story-checkpoint-setting-up-throwing-app]].

## Don't Ask Again

Before asking a clarifying question, check [`dont-ask-again.md`](dont-ask-again.md). It's an ever-growing list of questions already settled in past sessions. If the category is already covered there, apply the settled answer instead of re-asking. When Nigel answers a new clarifying question with a general (not one-off) preference, add it to that file.

## Agent Directive (Mandatory)

**For every code change request, no matter how small, spawn the relevant agents from `docs/agents/` as part of the workflow.**

The agents are part of the delivery pipeline, not optional extras. The human architect does not trigger them manually; the IDE AI spawns them automatically based on the nature of the work.

- **Any code change**
  - **Spawn these agents:** Test Agent
- **Any non-trivial code change (new feature, API change, schema change)**
  - **Spawn these agents:** Docs Agent + Test Agent
- **Platform, permission or config changes (`AndroidManifest.xml`, `Info.plist`, Gradle/Xcode, native plugins in `pubspec.yaml`, signing, secrets)**
  - **Spawn these agents:** "Be Careful" Review Agent + Docs Agent + Test Agent
- **A multi-step feature or large story**
  - **Spawn these agents:** Story Agent (orchestrates all other agents per task)
- **Story completion or requirement audit**
  - **Spawn these agents:** Traceability Agent
- **An operational/tooling issue or third-party bug is found, even with no code change**
  - **Spawn these agents:** Docs Agent (record it in Known Issues / Common Tasks immediately)

Full agent definitions, triggers and output formats are in `docs/agents/`.

## Project Overview

- **What it is:** the user sets a phone on a static mount pointed at a wooden board and throws **knives or axes** at it. The board has 5 painted rings in alternating colours (IKTHOF layout), scoring 5 for the inner ring down to 1 for the outer. The app registers the score of each throw. The phone sits off to the side, out of the line of throw, so the app has to find the target. AI is used for the visual and timing tasks.
- **Platforms:** iOS and Android only.
- **Accounts:** needed, never to score. **Backend:** AWS Amplify (decided 2026-10-19; accounts in progress, stage 2). **Payments:** deferred.
- **Source control:** GitHub (not yet set up).
- **Flutter app** (`thrower_app`): SDK `^3.13.5`, Riverpod; layers `lib/scoring/` (pure Dart), `lib/camera/`, `lib/auth/` (`AuthService`; `AmplifyAuthService`), `lib/ui/`; wiring in `lib/providers.dart`. Backend: AWS Amplify Gen 2 in `amplify/` (Cognito, London `eu-west-2`). Repo: private `github.com/nrbondnz/thrower_app`, `main` = production (`dev` to come). **Website:** orphan branches `website` / `website-dev` (Astro + TypeScript, knifeandaxethrower.com), worked on in the worktree `..	hrower_app-website`; see [[Website Index]].
- Details and rationale: [[Design Decisions]]. In progress: [[story-checkpoint-app-user-accounts]] (sign-in and backup on AWS Amplify; Task 1 built). Paused: [[story-checkpoint-entry-point]] (waiting for closer footage); last: [[story-checkpoint-quick-draw]] (a two-thrower duel on a recording, timed from "go", archived); built, device checks to come: [[story-checkpoint-players-and-targets]] (Play for 1 or 2 players, 1 or 2 targets) and [[story-checkpoint-game-history]] (finished games kept on the phone, Home → History) and [[story-checkpoint-score-corrections]] (tap a score to change it, or add a missed throw) and [[story-checkpoint-quick-draw-match]] (the live Quick draw as three rounds, the score breaking a tie; KATTA scoring) and [[story-checkpoint-named-players]] (a name for each player, kept on the phone, used by Play, History and Quick draw; 2026-10-19) and [[story-checkpoint-adjust-boards]] (drag each of two boards' outlines into place; Adjust boards after locking; 2026-10-19); accounts planned in stages in [[Accounts Roadmap]] (stage 1, named players, built; stage 2 next); requirements by area in `docs/thrower/requirements/` ([[Requirements Index]]); upcoming work in [[backlog]]. How-tos: [[Common Tasks]]; gotchas: [[Known Issues]].

## Commit / Deploy Rules

Carried over from WhereWillWeVisit. The backend now exists (AWS Amplify, 2026-10-19): `amplify/` and `amplify.yml` are config, committed after the Review Agent passes.

| Change Type | Commit? | Notes |
|-------------|---------|-------|
| Dart/Flutter only | **NO**: leave unstaged | Nigel tests locally (hot reload) first, then commits when ready |
| Test files only | **YES** | Commit alongside related changes |
| Config / infra | **YES** | After the "Be Careful" Review Agent passes |
| Docs / markdown | **NO**: leave unstaged | Avoids unnecessary CI/build triggers |
| `.claude/` (settings, memory, CLAUDE.md) | **YES** | So other developers can load Claude context quickly |

**Branches:** on the private GitHub repo `thrower_app`. `main` is **production**; a **`dev`** branch is for development (decided 2026-10-19, now there's a backend). `dev` is created when Nigel connects the Amplify app; it doesn't exist yet, so work stays on `main` until then. **Hosting and deploy flow:** Amplify Hosting deploys the backend (`amplify/`) from GitHub for each connected branch (`amplify.yml`: `ampx pipeline-deploy`), and serves `web_public/`. No sandbox from the PC. See [[Common Tasks]] → Connect the App to the Amplify Backend.

## Working Patterns Nigel Prefers

### 1. Dart/Flutter Changes
- **Within an approved story (2026-10-20):** commit and push per task and carry on; stop only when blocked or for a decision (`dont-ask-again.md` → Run whole stories, committing per task). The rules below apply outside a story.
- **Do NOT commit.** Leave unstaged so Nigel can hot-reload and test locally.
- Only commit after Nigel says "commit this" or "looks good, commit it."

### 2. Minimal Changes
- Make the smallest change that achieves the goal.
- Don't refactor unrelated code.
- Don't add features "just in case."

### 3. Clarify Options, Prefer Good Architecture
- When there are multiple valid approaches, **present the options with trade-offs** and ask which to pursue.
- Nigel prefers **good architecture over "quick and easy"**. Don't assume the fastest or hackiest path is wanted.
- When a trade-off is between a quick, entangled option and a cleaner, decoupled one, name it explicitly as **"easy" vs. "architectural purity"** and default the recommendation to architectural purity. (Lesson from WhereWillWeVisit, 2026-09-02: a feature built inside a shared backend for expediency broke the real deploy pipeline and had to be rebuilt standalone.)

### 4. Before Making Changes
- Read `AGENTS.md` if it exists in relevant directories.
- Check for existing tests to understand expected behaviour.
- Search the codebase for related patterns.

### 5. IDE: JetBrains (Android Studio / IntelliJ Ultimate), not VS Code
- Nigel runs the app through JetBrains using named Run Configurations (this project has `.idea/runConfigurations/main_dart.xml`).
- Don't create `.vscode/launch.json` or other VS Code-specific tooling.

## Environment & Key Paths

| Path | Purpose |
|------|---------|
| `lib/` | Flutter source, one folder per layer (see [[Design Decisions]] → Code Layout) |
| `tool/` | Dev utilities (`printable_target.dart`) |
| `test/` | Flutter tests |
| `docs/agents/` | Agent definitions |
| `docs/thrower/` | Obsidian architecture vault |
| `docs/thrower/stories/` | Story checkpoint files |
