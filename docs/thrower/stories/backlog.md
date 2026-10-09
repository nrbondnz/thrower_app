# Backlog

Stories not yet started, in rough priority order. Each becomes a `story-checkpoint-<slug>.md` when it starts.

| # | Story | Notes | Depends on |
|---|---|---|---|
| ~~1~~ | ~~Target calibration~~ | **Done 2026-10-08** ([[story-checkpoint-target-calibration]], archived) | — |
| ~~2~~ | ~~Throw detection and scoring~~ | **Done 2026-10-08** ([[story-checkpoint-throw-detection]], archived). Was: Throw motion → settle → compare with the reference frame → stick or bounce-out → blade entry point under the handle → `TargetMapping` → score. Also retrieval (end of round) and knives that fall out later. See [[Design Decisions]] → Throw Detection. | 1 |
| 3 | **Refine scoring by hit point** | Line-touch rules and per-sport variants (IKTHOF / WATL / IATF). Nigel put this on the backlog on 2026-10-04. `LineTouchRule` already supports higher/lower. | 2 |
| 4 | **Accounts** | Choose the backend and auth provider; implement `AuthService`. Revisit CI/CD (A8) at the same time. | — |
| 5 | **Game modes** | Single-player rounds of **3 throws**, then players, history. | 2 |
| 6 | **Store-release hygiene** | Remove or gate the 170 KB debug asset (`assets/debug/target-example.jpg`); review debug screens; check the iOS `NSMicrophoneUsageDescription` question (Review Agent note, setup story). | before any store build |
| 7 | **Axes** | Axe throws: wide head, long handle; entry point and scoring differ from knives (Nigel: knives first, 2026-10-08). | 2 |
| 8 | **Full-screen Play (optional)** | Hide the system bars while playing (immersive sticky mode) for a cleaner view on a stand. Content already stays clear of them (`SafeArea`), so this is cosmetic. | — |

## Carry-overs from Throw Detection

- **Device checks of Tasks 2–5** (motion, stuck/bounce, entry dot, Play): approved without reported device results. **Test plan for Nigel's brother: [[Device Test Plan]]** (interactive page records results). Android with the A4 printout (a grey pen in Blu Tack as the "knife"), then **iOS**, then a **real board and real knives**.
- **Confirm the fall-out rule:** a knife that sticks then falls out before being collected scores 0 (assumed).
- **Speed on the phone:** the motion pass runs ~15 times a second on the UI thread (brightness only, ~320 px); full-resolution conversion and the entry search run in background isolates. Not yet measured on a device.
- **Things the renders don't cover:** wind moving the board, moving shadows (clouds, trees), a dog or a person crossing the background inside the board's region, knives landing touching an existing knife, the board's bark edge being hit (outside the rings: stuck, 0).

## Carry-overs from Target Calibration

- **iOS device check of Tasks 2–4** (frame orientation on iPhone is unverified; see Design Decisions → Target Locating).
- **A non-red board** on a device (two-colour learning is tested only on synthetic and recoloured images).
- **Real angled photos of a real board** from the mount position. Only the A4 printout and renders so far; Nigel has no real board yet.
- **Where does ring 1 end?** Painted line or bark? Today `outer` is extrapolated from the 0.8 edge (decides scoring of the outermost ring).
- **Remember the calibration between app sessions?** Today: session only.

## Open Product Questions

- **Q2:** ~~board size~~ (75–85 cm, answered 2026-10-08); ~~throwing distance~~: **4 m** (2026-10-08).
- ~~**Q5:** throws per round~~: **3** (2026-10-08).
- **Q3:** Nigel's own photos of a real board, from the phone's mount position.

## Docs Drift Items

- ~~Component→function tree / glossary; System Diagram / Data Flow~~: created 2026-10-08 ([[Glossary]], [[System Diagram]], [[Data Flow]]).
