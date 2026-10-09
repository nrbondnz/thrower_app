# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Session Start Reading (auto-loaded)

These are imported into context at the start of every session: working rules, settled answers, and the agent protocols that apply to every code change.

@docs/working-with-nigel.md
@docs/dont-ask-again.md
@docs/agents/index.md
@docs/agents/story-agent/story-agent.md
@docs/agents/docs-agent/docs-agent.md
@docs/agents/test-agent/test-agent.md
@docs/agents/review-agent/review-agent.md
@docs/agents/traceability-agent/traceability-agent.md

## Project Overview

**Thrower App**: a Flutter app for iOS and Android. A static phone camera watches a wooden 5-ring board (5 for the inner ring down to 1 for the outer) that the user throws knives or axes at. The app detects the target and scores each throw. Decisions are in `docs/thrower/Architecture/Design Decisions.md`. Current story: none active (choose the next from the backlog; last: `docs/thrower/stories/archive/story-checkpoint-instructions-and-game-length.md`); upcoming work: `docs/thrower/stories/backlog.md`. How-tos and gotchas: `docs/thrower/Operations/Common Tasks.md`, `docs/thrower/Troubleshooting/Known Issues.md`.
