# Test Agent

## Purpose

The Test Agent writes and updates tests for every code change. Not as an afterthought. Not as a separate ticket. As part of the same unit of work.

The goal is not 100% coverage for coverage's sake. The goal is **confidence**: that the code works, that edge cases are handled, and that the next developer does not break this functionality without knowing.

## Trigger

**Every code change.** No exceptions.

- New feature → write tests for the happy path and the error paths
- Bug fix → write a test that reproduces the bug, then verify it passes after the fix
- Refactor → ensure existing tests still pass; update or add tests if behaviour changed
- Platform/config change → add or update tests if the change affects behaviour (e.g. permission-denied handling)

## Responsibilities by Layer

The app is split into camera → vision → scoring (see [[Design Decisions]]). Each layer is tested on its own terms.

### Scoring Domain (pure Dart)

- **Unit tests** for `TargetModel`: a normalised point → ring score (5 for the inner ring down to 1, 0 outside), including the line-touch setting (higher / lower / majority of blade)
- **Unit tests** for session state: throws, totals, bounce-outs scoring 0, round reset
- These tests need no camera, no device and no images, and must be fast

### Vision (target finding, throw detection)

- **Fixture-image tests:** run the pipeline on saved photos and frame pairs (`test/fixtures/`, starting from `docs/thrower/reference/`) and assert on the detected ellipse, stick vs bounce-out, and entry point **within a stated tolerance**
- **Regression set:** every misdetection Nigel reports becomes a fixture with its expected answer
- **Mock the camera** at the frame-stream boundary. Feed recorded frames; never require a live camera in tests

### Flutter UI

- **Widget tests:** does the screen render correctly for a given state (calibrating, ready, throw scored, permission denied)?
- **Integration tests** (on a device, when needed) for user flows: start session → calibrate → throw → score shown

## Test Quality Standards

A test written by the Test Agent must:

1. **Have a clear name** that says what is being tested and under what conditions.
   - Good: `'point on the boundary between ring 4 and 5 scores 5 with higher-ring rule'`
   - Bad: `'score test'`

2. **Test one thing.** One assertion per test is ideal. Two or three is acceptable. More than that suggests the test is doing too much.

3. **Be independent.** Tests must not depend on the order they run in. Each test sets up its own state.

4. **Be deterministic.** Given the same inputs, the test must always pass or always fail. No randomness, no timing dependencies, no live camera. Vision tests use fixed fixtures and explicit tolerances.

5. **Fail with a useful message.** If a test fails, the message should say what went wrong (e.g. "expected entry point within 5 px of (412, 300), got (460, 251)") without the reader needing to open the test.

## Output Format

The Test Agent produces a **Test Report**: a brief record of what tests were added or updated.

**Example Test Report:**

```markdown
## Test Report — 2026-10-10 16:25

### New Tests
- `target_model_test.dart`: 14 table-driven cases (each ring, boundaries, outside, line-touch rules)
- `session_test.dart`: 'bounce-out records a 0-point throw'
- `ellipse_finder_test.dart`: 'finds rings on target-example.png within 3% of the hand-measured ellipse'

### Updated Tests
- `widget_test.dart`: replaced the counter test with the home screen test

### Results
- `flutter test`: 23 passed, 0 failed

### Notes
- One test skipped: entry-point detection on axe fixtures. No axe photos yet (waiting on Nigel's photos).
```

## Integration with Story Agent

When running inside a Story Agent workflow, the Test Agent is spawned **during every task** that produces code. The Test Report is appended to the Story Checkpoint file.

Tests must pass before the task is marked complete. A task with failing tests is not a valid checkpoint.

## Directives

1. **Never commit without running the tests.** The Test Agent runs `flutter test`. If tests fail, the agent reports the failure and stops. It does not proceed to the next task.
2. **Prefer table-driven tests for repetitive cases.** If the same logic is tested with ten inputs (scoring points), loop over a table rather than writing ten copy-pasted tests.
3. **Mock at the right boundary.** Mock the camera stream and any future backend. Do not mock the code under test.
4. **Leave a breadcrumb for the next developer.** If a test is skipped or deferred, explain why in a comment.
