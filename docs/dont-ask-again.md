# Don't Ask Again — Settled Questions

> Referenced from `working-with-nigel.md`. Read this before asking Nigel a clarifying question — check whether it's already settled here first.

This is a cross-session, ever-growing list of questions that came up once, got answered, and shouldn't need re-asking. When Nigel answers a clarifying question with a general preference (not a one-off, situation-specific answer), add it here rather than letting it live only in that conversation.

**How to use this file:**
- Before asking Nigel a clarifying question, scan this list — if the category is already settled, apply the settled answer directly instead of asking again.
- After Nigel answers a clarifying question, decide: is this a reusable default, or specific to the moment? If reusable, add an entry here (and update `working-with-nigel.md` too if it's significant enough to belong in the main doc's tables/sections).
- Entries should be short: the question/category, the settled answer, why, and the date confirmed.

> **Origin:** the entries below were carried over from the WhereWillWeVisit project on 2026-10-04. They describe how Nigel works, not anything specific to that project. The entry about four-branch doc syncing was left out because it only applies there. "Obsidian vault" here means `docs/thrower/`.

---

## IDE: JetBrains, not VS Code
**Settled answer:** Nigel runs the app via JetBrains (Android Studio / IntelliJ Ultimate) Run Configurations only. Never create `.vscode/` tooling.
**Confirmed:** see `working-with-nigel.md` §"IDE: JetBrains ... not VS Code" for full detail (existing run configs live in `.idea/workspace.xml`, gitignored).

## "Demonstrable" means Nigel can run it himself
**Settled answer:** A Story Agent task's "Verify" step must be something Nigel can click, run, or call himself — not just an AWS CLI command I ran and reported the output of.
**Why:** A CLI call I run and report on isn't independently verifiable by Nigel and doesn't prove the user-facing behavior works.
**Confirmed:** 2026-07 (Apple IAP story).

## Truncated/cut-off mid-turn messages
**Settled answer:** If a message arrives mid-turn that's obviously an incomplete fragment (e.g. cut off while typing), don't stop to ask what it meant — keep working and let Nigel send the rest when ready.
**Why:** Interrupting on an obvious typing fragment breaks flow; Nigel will follow up himself.
**Confirmed:** 2026-07-24.

## Doc file edits/creation — standing authorization
**Settled answer:** I'm authorized to edit existing docs and create new doc files in the Obsidian vault without asking first. The one carve-out: never silently delete a doc file — investigate why it exists (git history, backlinks) first, prefer merge/redirect over deletion, and call out any actual deletion explicitly rather than treating it as routine cleanup.
**Why:** Docs drift constantly; asking permission for every doc edit slows down keeping them in sync with the code, which the Docs Agent protocol already treats as mandatory (`docs/agents/docs-agent/docs-agent.md`).
**Confirmed:** 2026-07-24.

## Xcode work happens in the foreground, in Xcode
**Settled answer:** iOS build, archive, signing and upload work is done **visibly in Xcode**, so Nigel can follow it, not as background CLI builds (`flutter build ipa`) that he only hears about afterwards. The pattern for an archive:
1. **Claude:** bump `version: 1.0.0+N` in `pubspec.yaml`, then `flutter build ios --config-only --release`. This only refreshes `Generated.xcconfig` (the version and build number Xcode uses); it isn't a build.
2. **Claude:** `open ios/Runner.xcworkspace`, and say exactly what to click.
3. **Nigel**, in Xcode: destination **Any iOS Device (arm64)** → **Product → Archive**. Xcode compiles the Dart code itself (Flutter's build-phase script), shows progress, then opens **Organizer** → **Distribute App → App Store Connect → Upload**.
4. **Claude:** confirms the result from Xcode's logs (`$TMPDIR/*.xcdistributionlogs`) and App Store Connect, and narrates each step.

The same goes for signing (Xcode's *Signing & Capabilities*, with Claude explaining) and device installs (Xcode's Run button, or `flutter run` with Xcode open). Claude can't click inside Xcode; it prepares, explains and checks. Read-only checks (git diffs, logs, `flutter test`) stay on the command line.
**Why:** Nigel wants to follow and learn the Xcode flow, not just get results.
**Confirmed:** 2026-10-10.

---

*Add new entries above this line as they come up. Keep each entry to a few lines — link to `working-with-nigel.md` or another doc for full detail rather than duplicating it here.*
