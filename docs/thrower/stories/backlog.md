# Backlog

Stories not yet started, in rough priority order. Each becomes a `story-checkpoint-<slug>.md` when it starts.

| # | Story | Notes | Depends on |
|---|---|---|---|
| 1 | **Target calibration** | **Active:** [[story-checkpoint-target-calibration]] | Printed target or the real board; Nigel's photos |
| 2 | **Throw detection and scoring** | Throw motion → settle → compare with the reference frame → stick or bounce-out → blade entry point under the handle → score. Also retrieval (end of round) and knives that fall out later. See [[Design Decisions]] → Throw Detection. | 1 |
| 3 | **Refine scoring by hit point** | Line-touch rules and per-sport variants (IKTHOF / WATL / IATF). Nigel put this on the backlog on 2026-10-04. `LineTouchRule` already supports higher/lower. | 2 |
| 4 | **Accounts** | Choose the backend and auth provider; implement `AuthService`. Revisit CI/CD (A8) at the same time. | — |
| 5 | **Game modes** | Single-player rounds, then players, history. Throws per round still open (Q5). | 2 |

## Open Product Questions

- **Q2:** board size and throwing distance (affects pixels per ring).
- **Q5:** throws per round.
- **Q3:** Nigel's own photos of the board, from the phone's mount position.

## Docs Drift Items (from the setup story's traceability review)

- No component→function tree or concept glossary yet (Docs Agent responsibility 5). Start one when the vision layer arrives: it brings the first real concepts (ellipse fitting, homography, frame differencing).
- No System Diagram / Data Flow pages yet; add them with target calibration.
