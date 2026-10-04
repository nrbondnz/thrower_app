# Story Checkpoint: Setting Up Throwing App

## Story Goal

Turn the default `flutter create` scaffold into a properly set-up project for an app that **scores throws at a physical round target using the phone camera**. Purpose and architecture are agreed and recorded, the docs/agents workflow is in place, source control is ready, and the skeleton is structured for the vision, scoring and accounts work that follows.

**Product, in Nigel's words (2026-10-04):** "Users will point a camera at a physical round target. The target will be round but the camera will likely be off to centre so it will need to identify the target. Big picture, the user will throw at the target and the app will register the score. The target will have a number of rings, the inner most ring scores 5 and the outer most ring scores 1, so 5 rings, each alternating colors to differentiate. We will need to refine this a lot but start there."

**Scope note:** this story is **setup**, not the full scoring feature. Target detection and throw detection each get their own story once the foundations exist (see Follow-on Stories).

## Complexity Score

| Factor | Score |
|---|---|
| Layers: Flutter UI, camera, vision, scoring domain | 4 |
| Infrastructure: git/GitHub, platform trimming, iOS/Android camera permissions | 1 |
| More than 3 acceptance criteria | 1 |
| **Total** | **6 (Large): full Story Agent protocol** |

## Status

**IN PROGRESS (2026-10-04)**: Story Plan approved by Nigel. Tasks 0–1 complete; **waiting at the Task 1 checkpoint** for Nigel to review before Task 2.

---

## Architecture Questions

| # | Question | Answer (2026-10-04) |
|---|---|---|
| A1 | What does the app do? | Camera on a round 5-ring target (5 = inner, 1 = outer, alternating colours); detects the target off-centre; registers the score of each throw. To be refined. |
| A2 | Target platforms | **iOS and Android** |
| A3 | Backend | **Later** |
| A4 | Auth / accounts | **Accounts needed** (provider deferred with the backend) |
| A5 | Payments | **Later** |
| A6 | Structure / AI | AI for **visual and timing** tasks. Proposed: on-device, 3-layer split. See [[Design Decisions]]. |
| A7 | Source control | **GitHub, private repo `thrower_app`, `main` only** |
| A8 | CI/CD | Not yet discussed. Revisit with the backend decision. |

## Open Questions (refining the product)

| # | Question | Why it matters |
|---|---|---|
| Q1 | What's being thrown? | **Knives or axes** into a wooden board (Nigel, 2026-10-04; corrects an earlier "darts"). Score is where the blade meets the board; a throw that doesn't stick scores 0. See [[Design Decisions]] → Throwing Sport. |
| Q2 | Target size, and how far is the phone from it? Tripod or handheld? | **Static camera** (2026-10-04). Board size and distance are still open; IKTHOF's is 50 cm with throws from about 12–21 ft. |
| Q3 | Ring colours? Real photos? | Close example: red paint and bare wood alternating, red bull (`reference/target-example.png`). **Nigel's own photos to follow.** |
| Q4 | A throw on a line: higher or lower score? A miss scores 0? | **Backlog** (refine scoring by hit point). Interim: IKTHOF, i.e. touching blade scores the higher ring, no stick = 0. Make it a setting. |
| Q5 | Players, rounds and throws per round? Single-player first? | **Single player first** (2026-10-04). Throws per round still open. |
| Q6 | Repo name and public/private; dev/prod branches as in WhereWillWeVisit? | **`thrower_app`, private, on GitHub; `main` only for now** (2026-10-04). |
| Q7 | Remove the web/desktop platform folders? | **Yes**: done 2026-10-04 |

## Traceability Matrix (baseline)

| ID | Requirement | Design ref | Implementation | Test | Status |
|---|---|---|---|---|---|
| R1 | Project has a docs area matching WhereWillWeVisit's workflow | `working-with-nigel.md` | `docs/`, `CLAUDE.md` | n/a (docs) | ✅ Task 0 |
| R2 | Runs on iOS and Android only | Design Decisions | web/desktop folders removed; bundle IDs pending | `flutter analyze` clean | ⏳ Task 2 (partly done) |
| R3 | Scores a point on a 5-ring target: 5 inner → 1 outer, 0 outside; line-touch rule is a setting (default: higher) | Design Decisions | | | ⏳ Task 3 |
| R4 | Live camera preview of the target on iOS and Android | Design Decisions | | | ⏳ Task 4 |
| R5 | Finds the round target when viewed off-centre | Design Decisions | | | Follow-on story |
| R6 | Detects a thrown knife or axe that sticks and registers its score; a throw that doesn't stick scores 0 | Design Decisions | | | Follow-on story |
| R7 | User accounts | Design Decisions | `AuthService` interface | | ⏳ Task 3 (interface only) |

---

## Story Plan (APPROVED 2026-10-04)

### Task 1: Settle architecture and adapt the agents
- **Work:** Record answers to Q1–Q7 in [[Design Decisions]]. Confirm or amend the proposed 3-layer vision/scoring split. Rewrite the "Be Careful" Review Agent checklist for this stack (camera permissions, iOS `Info.plist` / Android manifest, signing, secrets). Strip the WhereWillWeVisit-only examples from the agents.
- **Verify (Nigel):** read Design Decisions and the Review Agent and agree they describe this app.

### Task 2: Git, GitHub and platform trimming
- **Work:** `git init`, `.gitignore` check, private GitHub repo `thrower_app` under `nrbondnz` (Nigel creates it on github.com, or installs `gh`, which isn't installed yet), initial commit on `main`. ~~Remove the web/desktop folders~~ (done early, 2026-10-04). Set the app name and bundle IDs.
- **Verify (Nigel):** the repo is visible on GitHub; the app still runs from the JetBrains `main.dart` run configuration on an Android device and on iOS.

### Task 3: App skeleton and scoring domain
- **Work:** Replace the counter demo. Set up the `lib/` layout (`camera/`, `vision/`, `scoring/`, `auth/`, `ui/`), state management (recommendation to be presented as options), routing and theme. The pure-Dart `TargetModel` maps a normalised point to a score (5→1, 0 outside, edge rule per Q4). Add an `AuthService` interface (no provider yet). Test Agent: table-driven scoring tests.
- **Verify (Nigel):** a debug screen where tapping a drawn target shows the score for that point; `flutter test` passes.

### Task 4: Camera preview with permissions
- **Work:** Add a camera package, request permission on iOS and Android, and show a full-screen preview with a frame stream ready for the vision layer. Review Agent (permissions, manifest/plist).
- **Verify (Nigel):** on both phones, the app asks for camera permission and shows the live preview of the target.

### Task 5: Traceability review and close
- **Work:** Traceability Agent pass; update docs; archive this story; open the follow-on stories.
- **Verify (Nigel):** the matrix is complete and the follow-on stories are listed.

## Follow-on Stories (not this story)
- **Target calibration:** with the static camera, find the painted rings' ellipse once per session (ignoring the irregular log edge); drag-to-adjust overlay; lock it.
- **Throw detection and scoring:** throw motion → settle → compare with the reference frame → stick or bounce-out → find the blade's entry point under the handle → score. Also handle retrieval (end of round) and knives that fall out later.
- **Backlog: refine scoring by hit point** (line-touch rules, per-sport variants: IKTHOF / WATL / IATF).
- **Accounts:** choose the backend and auth provider; implement `AuthService`.
- **Game modes:** players, rounds, history (Q5).

---

## Task Records

### Task 0: Create the docs area — COMPLETE
- **What changed:**
  - `CLAUDE.md`: auto-loads the docs below at session start.
  - `docs/working-with-nigel.md`: adapted from WhereWillWeVisit; working habits kept, project sections as placeholders.
  - `docs/dont-ask-again.md`: general settled answers carried over.
  - `docs/agents/`: the five agent definitions copied, with a note that their examples come from WhereWillWeVisit.
  - `docs/thrower/`: vault with `Index.md`, `Architecture/`, `stories/`.
- **Verified by:** Nigel to review the files.
- **Checkpoint saved:** 2026-10-04

### Task 1: Settle architecture and adapt the agents — COMPLETE (awaiting Nigel's review)
- **What changed:**
  - `Architecture/Design Decisions.md`: the 3-layer pipeline and the throw-detection approach changed from PROPOSED to confirmed; branch model `main` only; single player first; knives/axes scoring research (IKTHOF/WATL/IATF).
  - `docs/agents/review-agent/review-agent.md`: **rewritten checklist** for this app: platform permissions, iOS/Android parity, debug leaking into release, secrets/signing, privacy of camera data, app size and performance, **physical safety** (never encourage the phone or the user to be in the line of throw), app identity and rollback.
  - `docs/agents/test-agent/test-agent.md`: per-layer testing (pure-Dart scoring; vision against **fixture images with tolerances**; widget tests); Java/TypeScript sections removed.
  - `docs/agents/docs-agent/docs-agent.md`: vault-only (there's no `docs/web/` site here); new sections on the vision pipeline and scoring rules; examples use this app's components.
  - `docs/agents/story-agent/story-agent.md`: protocol unchanged; the complexity table, checkpoint example and worked example ("Detect and Score Throws") rewritten for this app.
  - `docs/agents/traceability-agent/traceability-agent.md`: examples rewritten.
  - `docs/agents/index.md`, `docs/working-with-nigel.md`: trigger tables and branch rules updated.
- **Verified by:** the agent docs contain no references to Stripe, Amplify, Lambda, Java, GraphQL or `whereinnz` (scanned). **Nigel to read Design Decisions and the Review Agent** and confirm they describe this app.
- **Not covered by Task 1 (still open, not blocking):** board size and throwing distance (Q2), throws per round (Q5), Nigel's photos (Q3), CI/CD (A8).
- **Checkpoint saved:** 2026-10-04

---

## Plan Changes Log

- **2026-10-04:** Plan approved by Nigel; branch model `main` only. Task 1 executed.

- **2026-10-04:** Q5/Q6 answered: single player first; repo `thrower_app`, private.

- **2026-10-04:** Q1 corrected: **knives and axes, not darts**. Camera is static; wooden board with 5 painted circles (example photo saved). Researched IKTHOF/WATL/IATF scoring; refining scoring by hit point goes to the backlog. Follow-on stories updated.

- **2026-10-04:** Q1 answered: darts, which stick in the target. Detection is a before/after frame comparison; the follow-on story was renamed to dart detection.

- **2026-10-04:** Nigel approved Q7 early. `web/`, `windows/`, `macos/`, `linux/` deleted and `.metadata` cleaned; `flutter analyze` shows no issues. Brought forward from Task 2.

- **2026-10-04:** Story created.
- **2026-10-04:** A1–A7 answered. Draft plan written (Tasks 1–5); target and throw detection split into follow-on stories.

## Notes
- Project is not yet a git repository.
- The source of truth for decisions is [[Design Decisions]]; this file tracks progress.
