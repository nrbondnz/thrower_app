# Working with Nigel

> Read this file at the start of every new conversation session.

Set up 2026-10-04, modelled on the WhereWillWeVisit project's version (`C:\dev\flutter_projs\whereinuk\where_in_nz_v3\docs\working-with-nigel.md`). The working habits are carried over as they are. The project-specific sections are placeholders, filled in as Thrower App's architecture is decided in [[story-checkpoint-setting-up-throwing-app]].

## Don't Ask Again

Before asking a clarifying question, check [`dont-ask-again.md`](dont-ask-again.md). It's an ever-growing list of questions already settled in past sessions. If the category is already covered there, apply the settled answer instead of re-asking. When Nigel answers a new clarifying question with a general (not one-off) preference, add it to that file.

## Agent Directive (Mandatory)

**For every code change request, no matter how small, spawn the relevant agents from `docs/agents/` as part of the workflow.**

The agents are part of the delivery pipeline, not optional extras. The human architect does not trigger them manually; the IDE AI spawns them automatically based on the nature of the work.

| If the work involves... | Spawn these agents |
|------------------------|-------------------|
| Any code change | Test Agent |
| Any non-trivial code change (new feature, API change, schema change) | Docs Agent + Test Agent |
| Platform, permission or config changes (`AndroidManifest.xml`, `Info.plist`, Gradle/Xcode, native plugins in `pubspec.yaml`, signing, secrets) | "Be Careful" Review Agent + Docs Agent + Test Agent |
| A multi-step feature or large story | Story Agent (orchestrates all other agents per task) |
| Story completion or requirement audit | Traceability Agent |
| An operational/tooling issue or third-party bug is found, even with no code change | Docs Agent (record it in Known Issues / Common Tasks immediately) |

Full agent definitions, triggers and output formats are in `docs/agents/`.

## Project Overview

- **What it is:** the user sets a phone on a static mount pointed at a wooden board and throws **knives or axes** at it. The board has 5 painted rings in alternating colours (IKTHOF layout), scoring 5 for the inner ring down to 1 for the outer. The app registers the score of each throw. The phone sits off to the side, out of the line of throw, so the app has to find the target. AI is used for the visual and timing tasks.
- **Platforms:** iOS and Android only.
- **Accounts:** needed. **Backend and payments:** deferred.
- **Source control:** GitHub (not yet set up).
- **Flutter app** (`thrower_app`): SDK `^3.13.5`, Riverpod; layers `lib/scoring/` (pure Dart), `lib/camera/`, `lib/auth/` (interface), `lib/ui/`; wiring in `lib/providers.dart`. Repo: private `github.com/nrbondnz/thrower_app`, `main` only.
- Details and rationale: [[Design Decisions]]. Current story: none active (choose from the [[backlog]]); last: [[story-checkpoint-instructions-and-game-length]]; upcoming work in [[backlog]]. How-tos: [[Common Tasks]]; gotchas: [[Known Issues]].

## Commit / Deploy Rules

Carried over from WhereWillWeVisit. Revisit once there's a backend and a pipeline.

| Change Type | Commit? | Notes |
|-------------|---------|-------|
| Dart/Flutter only | **NO**: leave unstaged | Nigel tests locally (hot reload) first, then commits when ready |
| Test files only | **YES** | Commit alongside related changes |
| Config / infra | **YES** | After the "Be Careful" Review Agent passes |
| Docs / markdown | **NO**: leave unstaged | Avoids unnecessary CI/build triggers |
| `.claude/` (settings, memory, CLAUDE.md) | **YES** | So other developers can load Claude context quickly |

**Branches:** `main` only, on the private GitHub repo `thrower_app` (decided 2026-10-04). No dev/prod split until there's a backend or release pipeline. **Hosting and deploy flow:** not yet decided (no backend yet).

## Working Patterns Nigel Prefers

### 1. Dart/Flutter Changes
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
