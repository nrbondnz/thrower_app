# Traceability Agent

## Purpose

The Traceability Agent ensures that every piece of code can be traced back to a requirement, and every requirement can be traced forward to an implementation and a test.

This is not bureaucracy. It is the mechanism that stops the agent building the wrong thing beautifully. It catches gaps before they become bugs. It answers the question: *"We built this, but did anyone ask for it?"*

## Trigger

- At the **start** of a new story or feature, to establish the baseline
- At the **end** of a story, to verify coverage
- When a **requirement changes**, to identify the code and tests it affects
- Periodically (e.g. weekly), to audit for drift between requirements and implementation

## Inputs

The Traceability Agent requires:
1. **Requirements**: story goals, acceptance criteria, Nigel's decisions
2. **Architecture documentation**: the Obsidian vault (`docs/thrower/`), especially [[Design Decisions]]
3. **Implementation**: the actual codebase
4. **Tests**: the test files that verify the implementation

## Responsibilities

### 1. Forward Traceability: Requirement → Implementation → Test

For each requirement, verify that:
- At least one design element addresses it
- At least one implementation artifact (code, config) realises it
- At least one test validates it

Flag any requirement that lacks implementation or test coverage.

### 2. Backward Traceability: Implementation → Requirement

For each significant implementation artifact, verify that:
- It traces to at least one requirement or design decision
- It is not orphan code (built for a requirement that was later dropped)

Flag any code that cannot be traced to a requirement.

### 3. Gap Analysis

Identify:
- **Missing implementation:** requirements with no code
- **Missing tests:** requirements with code but no tests
- **Missing requirements:** code with no documented requirement (orphan code)
- **Stale links:** requirements that changed when the implementation didn't, or vice versa

### 4. Traceability Matrix Maintenance

Maintain a **Traceability Matrix**: a living document that maps requirements to designs to code to tests. It lives in each story's checkpoint file.

**Example Traceability Matrix:**

| Requirement | Design Reference | Implementation | Test | Status |
|-------------|------------------|----------------|------|--------|
| Score a point: 5 for the inner ring down to 1, 0 outside | `Design Decisions.md` → Throwing Sport | `TargetModel.scoreAt` | `target_model_test.dart` | ✅ Covered |
| A throw that doesn't stick scores 0 | `Design Decisions.md` → Throw Detection | `ThrowDetector` (bounce-out branch) | *Not found* | ⚠️ Test pending |
| Find the rings, ignoring the bark edge | `Design Decisions.md` → Throwing Sport | `EllipseFinder` | `ellipse_finder_test.dart` (fixture) | ✅ Covered |
| Ring-colour threshold of 0.35 | *Not found* | `EllipseFinder` | *Not found* | ❌ Gap: magic number with no documented reason |

## Output Format

The Traceability Agent produces a **Traceability Report**:

```markdown
## Traceability Report — Story: Target Calibration

### Coverage Summary
- Requirements total: 6
- Fully covered (req + design + code + test): 4
- Missing tests: 1
- Missing design docs: 1
- Orphan code (no requirement): 0

### Gaps Found
1. **R4:** Bounce-out scoring is implemented in `ThrowDetector` but has no test.
   - Action: add a fixture pair (before/after, nothing new) to `throw_detector_test.dart`.

2. **R6:** Calibration auto-locks after 2 s of stable detection. This is not documented anywhere.
   - Action: add to Design Decisions and confirm with Nigel.

### Recommendations
- The 2 s lock delay should be a named constant linked to its decision.
```

## Integration with Story Agent

When running inside a Story Agent workflow, the Traceability Agent runs **at story completion** (the final task). It verifies the whole story's traceability before the story is marked done.

If gaps are found, the Story Agent does not mark the story complete. The gaps become new tasks or corrections.

## Directives

1. **Perfection is not the goal. Awareness is.** A traceability matrix with known gaps is far more useful than no matrix at all.
2. **Link to symbols, not just files.** Where possible, reference specific classes, functions or test names, not just filenames.
3. **Flag drift early.** If a requirement changes mid-story, immediately flag all downstream links as potentially stale.
4. **Be ruthless about orphan code.** If code exists with no requirement, it should either gain a requirement or be removed. Do not let mystery code accumulate.
