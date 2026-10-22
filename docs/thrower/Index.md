# Thrower App Documentation

Obsidian knowledge base for **Thrower App**. Open `docs/thrower/` as a vault. Organised by domain; folders are added as the architecture takes shape (following the WhereWillWeVisit vault's layout: Management, Frontend, Backend, Infrastructure, Architecture, Build and Deploy, Operations, Troubleshooting).

## Folder Map

- **[[Architecture Index|Architecture]]**
  - **What's Inside:** Design decisions, system diagram, data flow
- **`AppDesign/`**
  - **What's Inside:** [[App Design Index]]: how the app should look and feel (brand, themes, navigation, Home, stats, components)
- **`requirements/`**
  - **What's Inside:** [[Requirements Index]]: what the app should do, by area (setup, play, Game Centre), with what exists today and open questions
- **`stories/`**
  - **What's Inside:** Story checkpoint files (active), [[backlog]]; `stories/archive/` for completed ones
- **`website/`**
  - **What's Inside:** [[Website Index]]: the public site at knifeandaxethrower.com (Astro, branches `website` and `website-dev`, hosting setup, content plan)
- **`Operations/`**
  - **What's Inside:** [[Common Tasks]], [[Device Test Plan]], [[Mac Handoff]] (state + App Store setup for Claude on the Mac), [[Cloud Config Setup]] (AWS, Google, Apple and payment setup; how each secret is sourced)
- **`Troubleshooting/`**
  - **What's Inside:** [[Known Issues]]

## Quick Links

- [[Design Decisions]]: why things are built the way they are
- `reference/`: the example target photo and printable test targets (`reference/printable/`, regenerate with `dart run tool/printable_target.dart`)
- **Next story: to be chosen from the [[backlog]]**
- [[story-checkpoint-throw-detection]]: throw detection and play (archived)
- [[story-checkpoint-target-calibration]]: target calibration (archived)
- [[System Diagram]] · [[Data Flow]] · [[Glossary]]
- **Architecture web pages:** `docs/web/index.html` (open in a browser): the layer diagram with a page per component and per flow, like WhereWillWeVisit's. Rebuilt with `python tool/web_docs/build.py` (Common Tasks → Update the Architecture Web Pages)
- [[backlog]]: what's next
- [[Accounts Roadmap]]: how accounts grow towards a game centre, in stages
- [[story-checkpoint-setting-up-throwing-app]]: project setup (archived)
- `../working-with-nigel.md`: how to work on this project
