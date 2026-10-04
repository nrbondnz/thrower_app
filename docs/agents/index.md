# Agents Index

This directory contains the definitions, behaviours, and operating procedures for AI sub-agents used within the Thrower App project.

Each agent has a specific responsibility, a defined trigger condition, and a documented output format. Agents are not optional extras — they are part of the core workflow. Every significant piece of work should involve at least one agent.

> **Origin:** these definitions are based on the WhereWillWeVisit project's agents (`where_in_nz_v3/docs/agents/`). They were adapted to Thrower App on 2026-10-04 (Task 1 of [[story-checkpoint-setting-up-throwing-app]]): the protocols are unchanged, while the checklists and examples now fit a Flutter iOS/Android camera app. Update the Review Agent's checklist again once a backend is chosen.

## Agent Registry

| Agent | Purpose | Trigger |
|-------|---------|---------|
| [Story Agent](story-agent/story-agent.md) | Breaks large stories into sequential, demonstrable tasks with human checkpoints between each step | User says "build me X" where X is a multi-step feature |
| [Docs Agent](docs-agent/docs-agent.md) | Updates Obsidian architecture docs after every non-trivial code change | Every non-trivial code change (feature, vision pipeline, scoring rules, data model, platform config) |
| [Test Agent](test-agent/test-agent.md) | Writes or updates unit, widget, and integration tests | Every code change |
| [Traceability Agent](traceability-agent/traceability-agent.md) | Maintains requirement-to-code traceability and flags uncovered areas | Every story or architectural change |
| ["Be Careful" Review Agent](review-agent/review-agent.md) | Safety audit for permissions, platform config, secrets, privacy, app size and physical safety | Before committing any `AndroidManifest.xml`, `Info.plist`, Gradle/Xcode, `pubspec.yaml` plugin or signing change |

## How Agents Are Used

Agents are invoked by the IDE AI (the orchestrator) as part of the normal workflow. The human architect does not manually trigger each agent — instead, the architect's directives to the IDE AI include instructions to spawn the relevant agents for the task at hand.

For example:
> "Build throw detection. Follow the Story Agent protocol. Spawn the Docs Agent after each task. Spawn the Test Agent for every code change. Run the 'Be Careful' Review Agent before any permission or platform change."

## Adding New Agents

If a new pattern of work emerges that warrants its own agent, create a new subdirectory here with:
1. An `index.md` or `<agent-name>.md` defining purpose, trigger, and behaviour
2. A clear output format
3. Examples of how the agent responds to typical inputs

Link the new agent in the table above.
