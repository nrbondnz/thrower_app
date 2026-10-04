# Story Agent

## Purpose

The Story Agent breaks large, complex features into a sequence of small, demonstrable tasks. Each task ends with a **human checkpoint**: the user reviews the work, verifies it does what was promised, and only then says "continue" or "change this part."

This prevents the all-too-common scenario where an AI assistant runs for an hour, changes twenty files, and produces something that is technically complete but architecturally wrong, untested or impossible to verify.

The Story Agent is the conductor of large pieces of work. It plans the sequence, enforces the pauses, saves state between steps, and lets the user redirect mid-flight.

---

## What Makes a Story "Big"

A story is considered "big", and therefore subject to Story Agent decomposition, if it scores 2 or more on this complexity checklist:

| Complexity Factor | Weight | Example |
|-------------------|--------|---------|
| Crosses multiple architectural layers (UI → camera → vision → scoring → backend) | 1 per layer | Flutter UI → camera stream → `ThrowDetector` → `TargetModel` = 4 |
| Touches multiple data models | 1 per model | Session, Throw, Player = 3 |
| Has conditional branches or state-dependent behaviour | 1 per major branch | "Stuck → score it; nothing new → bounce-out (0); board cleared → new round" = 1 |
| Requires an external integration or third-party package with native code | 1 | Camera plugin, ML runtime, auth provider |
| Involves platform, permission or infrastructure changes | 1 | Camera permission, `Info.plist`, Gradle, a backend |
| Has more than 3 distinct acceptance criteria | 1 | "Find rings, ignore bark edge, allow manual adjust, lock" = 4 |
| Requires migration or affects existing data | 1 | Changing how saved sessions are stored |

**Scoring:**
- **0–1:** Small task. No Story Agent needed. Just build it.
- **2–3:** Medium. Use the Story Agent with 2–4 tasks.
- **4+:** Large. Full Story Agent protocol mandatory. Decompose into 5+ tasks.

> "Detect and score throws" scores at least 6. It crosses 4 layers, touches 2+ models, has 3 branches (stick / bounce-out / retrieval), needs a camera plugin, and has 4+ acceptance criteria. That is a **large story**.

---

## Decomposition Strategy

### Principles

1. **Each task must be demonstrable.** At the end of the task, the user must be able to see, tap or run something that proves the task worked. "The code is written" is not demonstrable. "Point the phone at the board and the rings are outlined" is.

2. **Each task must end in a stable state.** The code compiles, the tests pass, and the app is not broken. A task that leaves the codebase half-working is not a valid checkpoint.

3. **Tasks build on previous tasks.** Later tasks assume earlier tasks are complete and working. Do not parallelise tasks that depend on each other.

4. **Each task should be reviewable in one sitting.** If a task takes more than 15–20 minutes to review, it's too big. Split it.

5. **Separate "mechanism" from "policy."** First build the machinery (frame stream, ellipse finder, frame difference). Then layer on the rules (line-touch scoring, round reset, fall-out handling).

### The Demonstrable Task Pattern

Every task should follow this structure:

```
TASK: <Verb> the <thing> so that <demonstrable outcome>

SETUP: What needs to exist before this task starts
WORK: What this task changes or creates
VERIFY: How the user confirms this task worked
SAVE: What state is recorded after this task
NEXT: What task comes after this one
```

---

## Task Lifecycle

### Phase 1: Plan

The Story Agent analyses the user's request and produces a **Story Plan**: a numbered list of tasks with the demonstrable outcome for each.

The user reviews the plan and can:
- Approve it ("Looks good, start with task 1")
- Reorder tasks ("Do the scoring model before the camera")
- Split tasks ("Task 3 is too big; split detection from the UI")
- Merge tasks ("Tasks 1 and 2 are tiny; do them together")
- Reject it ("That's not what I meant; let me clarify")

No code is written during planning. This is a thinking exercise.

### Phase 2: Execute (One Task at a Time)

For each task in the plan:

1. **Announce** the task: "Starting Task 3: build the scoring model."
2. **Execute** the work: write code, tests, docs. Spawn sub-agents as needed (Docs Agent, Test Agent, "Be Careful" Agent).
3. **Verify** the task: run tests, confirm it compiles, do a quick smoke test.
4. **Save state** to the Story Checkpoint file (see below).
5. **Present** the demonstrable outcome to the user: "Tap anywhere on the drawn target and the score for that point appears. Try the line between the red and wood rings."
6. **Pause** and wait for the user's direction.

### Phase 3: Human Checkpoint

The user now decides:

| User Says | What Happens |
|-----------|--------------|
| "Continue" or "Next" | Proceed to the next task in the plan. |
| "Show me" or "How do I test?" | Explain how to verify the current state. |
| "Change this part" | The user describes what's wrong or different. Update the current task or the plan, re-execute if needed, and re-save state. |
| "Go back" | Revert to the previous checkpoint and redo from there. |
| "Skip to task N" | Jump to a later task (only if earlier tasks are complete). |
| "This is wrong, stop" | Halt the story. Save state. Do not proceed until the user clarifies. |

### Phase 4: Complete

When all tasks are done:
1. Final verification: run the full test suite.
2. Final docs update: make sure the architecture docs match the implemented system.
3. Final traceability check: make sure every requirement has a test and a doc reference.
4. Mark the story as complete in the Story Checkpoint file and move it to `stories/archive/`.

---

## Story Checkpoint File Format

Every story lives in `docs/thrower/stories/`:

- **Active stories:** `docs/thrower/stories/story-checkpoint-<story-slug>.md`, plus any supporting documents in `docs/thrower/stories/<story-slug>/`
- **Archived stories:** `docs/thrower/stories/archive/`, one file per story, moved there on completion.

**Checkpoint filename:** `story-checkpoint-<story-slug>.md`

**Example:** `docs/thrower/stories/story-checkpoint-target-calibration.md`

**Contents:**

```markdown
# Story Checkpoint: Target Calibration

## Story Goal
With the phone on a static mount, find the painted rings on the board once per session and lock them in, so later throws can be mapped to scores.

## Complexity Score
5 (Large — full Story Agent protocol)

## Status
IN PROGRESS — Task 2 of 5 complete

---

## Task 1: Find the ring ellipse in a still photo
- **Status:** COMPLETE
- **What changed:** `EllipseFinder` segments red paint from bare wood and fits the outer ring ellipse, ignoring the bark edge.
- **Verified by:** Nigel ran the debug screen on `target-example.png` and his own photos; outlines matched the rings.
- **Files changed:** `lib/vision/ellipse_finder.dart`, `test/vision/ellipse_finder_test.dart`
- **Checkpoint saved:** 2026-10-10 14:30

## Task 2: Live overlay on the camera preview
- **Status:** COMPLETE
- ...

## Task 3: Drag-to-adjust and lock
- **Status:** IN PROGRESS
- ...

## Task 4: Map image points to normalised target coordinates
- **Status:** NOT STARTED
- **Depends on:** Task 3

## Task 5: Traceability review
- **Status:** NOT STARTED
- **Depends on:** All previous tasks

---

## Plan Changes Log

- **2026-10-10 15:50:** Nigel asked for manual adjust before auto-lock (originally auto-lock only). Task 3 scope expanded.

---

## Notes
- Only red/wood boards tested so far.
```

---

## Vector Change Protocol

Mid-story direction changes are expected. The Story Agent handles them without panic or starting over.

### Types of Vector Change

1. **Scope change:** "Also handle axes, not just knives": add a new task or expand an existing one.
2. **Approach change:** "Don't use colour thresholds, train a model": revert the current task to the previous checkpoint, update the plan, and re-execute.
3. **Priority change:** "Skip the overlay for now, get scoring working first": reorder tasks.
4. **Clarification:** "That's not what I meant by a bounce-out": re-explain the requirement, update the task description, and re-execute.
5. **Emergency stop:** "Stop everything": halt immediately, save state, wait for instructions.

### How to Apply a Vector Change

1. Acknowledge the change. Do not argue.
2. Identify which tasks are affected (current, previous, future).
3. If the change invalidates completed work, revert to the last valid checkpoint.
4. Update the Story Plan and the Checkpoint file.
5. Re-execute from the affected task forward.
6. Log the change in the Plan Changes Log.

> **Rule:** Never silently change the plan. Always announce the change, update the checkpoint file, and get the user's confirmation before proceeding.

---

## Example: "Detect and Score Throws"

### Complexity Score
6 (Large)

### Story Plan

**Task 1: Detect motion and settling in the camera stream**
- Setup: Camera preview and target calibration exist.
- Work: `ThrowDetector` states: waiting → motion → settling → settled, from frame differences inside the target area.
- Verify: Debug label on screen changes as Nigel waves a hand in front of the board, then returns to "settled".
- Save: State machine tested with recorded frame sequences.

**Task 2: Tell a stick from a bounce-out**
- Setup: Task 1 complete.
- Work: Compare the settled frame with the reference; a new object means stick, nothing new means bounce-out (0).
- Verify: Throw a knife that sticks, then one that bounces; the app labels each correctly.
- Save: Fixture pairs for both cases pass.

**Task 3: Find the blade's entry point**
- Setup: Task 2 complete.
- Work: From the new object's outline, estimate where the blade meets the board (not the handle).
- Verify: The app marks a dot where the blade went in; Nigel checks it against the board.
- Save: Entry-point fixtures within tolerance.

**Task 4: Score and record the throw**
- Setup: Task 3 complete; `TargetModel` exists.
- Work: Entry point → normalised coordinates → score; add it to the session; update the reference frame.
- Verify: Three throws; the session total matches what Nigel reads off the board.
- Save: Session tests pass.

**Task 5: Retrieval and round reset**
- Setup: Task 4 complete.
- Work: Detect someone approaching the board and blades being removed; end the round and reset the reference.
- Verify: Pull the knives out; the app starts a new round without false throws.
- Save: Retrieval fixtures pass.

**Task 6: End-to-end testing and traceability review**
- Setup: All previous tasks complete.
- Work: Run the full test suite. Verify every requirement has a test. Verify the docs match. Run the Traceability Agent.
- Verify: All tests pass. Docs accurate. Traceability matrix complete.
- Save: Story complete. Checkpoint marked DONE.

---

## Agent Directives

When the Story Agent is active, the IDE AI must:

1. **Never skip the checkpoint.** Even if a task seems trivial, save state and pause for user confirmation.
2. **Never hide failures.** If a task doesn't compile or a test fails, report it immediately. Do not proceed to the next task.
3. **Never assume context.** Each task should be executable by someone reading the checkpoint file alone.
4. **Always announce the plan first.** No code is written until the user approves the Story Plan.
5. **Always log plan changes.** The checkpoint file is the source of truth. If the plan changes, the file changes.

---

## Integration with Other Agents

| When | Spawn |
|------|-------|
| After any code change within a task | Test Agent |
| After any architecture-affecting change within a task | Docs Agent |
| Before any platform, permission, dependency or infrastructure change within a task | "Be Careful" Review Agent |
| At story completion | Traceability Agent |
