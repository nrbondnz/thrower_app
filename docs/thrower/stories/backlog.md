# Backlog

Stories not yet started, in rough priority order. Each becomes a `story-checkpoint-<slug>.md` when it starts.

| # | Story | Notes | Depends on |
|---|---|---|---|
| ~~1~~ | ~~Target calibration~~ | **Done 2026-10-08** ([[story-checkpoint-target-calibration]], archived) | — |
| ~~2~~ | ~~Throw detection and scoring~~ | **Done 2026-10-08** ([[story-checkpoint-throw-detection]], archived). Was: Throw motion → settle → compare with the reference frame → stick or bounce-out → blade entry point under the handle → `TargetMapping` → score. Also retrieval (end of round) and knives that fall out later. See [[Design Decisions]] → Throw Detection. | 1 |
| 3 | **Refine scoring by hit point** | Line-touch rules and per-sport variants (IKTHOF / WATL / IATF). Nigel put this on the backlog on 2026-10-04. `LineTouchRule` already supports higher/lower. | 2 |
| 4 | **Accounts** | Choose the backend and auth provider; implement `AuthService`. Revisit CI/CD (A8) at the same time. | — |
| 5 | **Game modes** | Single-player games of **9 rounds of 3 throws** with reset (done 2026-10-09, [[story-checkpoint-instructions-and-game-length]]); next: players, history, other game lengths. | 2 |
| 6 | **Store-release hygiene** | ~~Remove the 170 KB debug asset~~ and the Camera / Ring finder test screens (done 2026-10-10); decide on the remaining *Scoring test target* screen; check the iOS `NSMicrophoneUsageDescription` question (Review Agent note, setup story). **Live test recordings** (`assets/live/`, +52 MB since 2026-10-12): remove them, or confirm the people filmed are happy to be in a public app ([[story-checkpoint-live-test]] safety flags). | before any store build |
| 7 | **Axes** | Axe throws: wide head, long handle; entry point and scoring differ from knives (Nigel: knives first, 2026-10-08). | 2 |
| 8 | **Full-screen Play (optional)** | Hide the system bars while playing (immersive sticky mode) for a cleaner view on a stand. Content already stays clear of them (`SafeArea`), so this is cosmetic. | — |
| 9 | **Start-signal duel** (Mark's idea, 2026-10-14) | Grand-prix start: five beeps, a **random pause**, then a longer "go" beep. Then the app shows **left vs right**: each thrower's time from "go" to their knife landing, in **ms**, and whether either **bounced out**. Nigel: "a simplification if anything". **Test case (likely the only real one for a while):** see *Duel test case* below. **Open questions:** what counts as the throw time (the impact frame, or when the board settles)? **Timing precision:** the motion pass runs ~15 times a second (about ±67 ms), and the duel test case was decided by **30 ms**, so the app needs impact *sound* (the microphone: a new permission and the `NSMicrophoneUsageDescription` question, Review Agent) or a 60 fps frame pass. **Safety:** a start signal means two people throwing at once, so it needs separate lanes and the Review Agent §7 check; the beeps must play with the iPhone on silent. Needs Mark on an iPhone (TestFlight). | 2; 10; iPhone tester |
| 10 | **Two targets in one view** (Nigel, 2026-10-14) | One phone watching **two boards side by side**, needed for the duel (9) and for testing it on the real footage. **Calibrate both:** find two targets in one frame, label them **left / right** (target 1 / target 2), adjust and lock each. **Watch both:** a throw watcher per target, with its own rounds and score, and a shared clock for the duel. **Full-screen Live test:** play the **whole frame** of the original video, not the per-board 322 × 322 crops the Live test uses now (`assets/live/target1.tfrm`, `target2.tfrm`), and keep its **audio** (the `.tfrm` packs have none). **Input needed from Nigel:** the original `IMG_1628.mov` (1080 × 1920, 60 fps), which isn't kept in the repo (`reference/live-camera/README.md`). Watch app size: the two crops are already 52 MB. | 1; Live test (done) |

## Carry-overs from Live Test

- **Device checks** ([[story-checkpoint-live-test]], archived 2026-10-11): the Live test on a phone (marks on Play, rounds following the footage); **camera zoom** on Find target (the image stream zooms too; Play keeps the zoom); the A4 printout's waved-hand bounce-out still registering.
- ~~**The original phone video**~~: done 2026-10-12 (boards ~245 px; 12 of 19 knives scored as Nigel did). **Next: re-check the answer key's scores against the original.** They were read from the blurry copy. The app differs on 7 knives: board 1 at 18.2, 40.5, 133.0 and 136.5 s; board 2 at 69.6, 105.2 and 177.0 s.
- **App size:** the Live test recordings are now 51.8 MB (Nigel's choice, 2026-10-12).
- **Side-mounted phones on real boards:** the Live test recordings are filmed face on (`faceOnEntry`); the app's intended 45° mount still has only renders and the A4 printout behind it.

## Carry-overs from Throw Detection

- **Device checks of Tasks 2–5** (motion, stuck/bounce, entry dot, Play): approved without reported device results. **Test plan for Nigel's brother: [[Device Test Plan]]** (interactive page records results). Android with the A4 printout (a grey pen in Blu Tack as the "knife"), then **iOS**, then a **real board and real knives**.
- **Confirm the fall-out rule:** a knife that sticks then falls out before being collected scores 0 (assumed).
- **Speed on the phone:** the motion pass runs ~15 times a second on the UI thread (brightness only, ~320 px); full-resolution conversion and the entry search run in background isolates. Not yet measured on a device.
  - **2026-10-13: the Live test jumps and freezes on Nigel's Samsung SM A065F.** Likely cause: pure-Dart JPEG decoding of the 322 px recording frames on the UI thread (see [[Known Issues]] → Live Test Playback Jumps and Freezes). **Done: (a)** (Nigel's choice): Flutter's native image codec, asynchronous, skipping to the newest frame; Nigel to re-check on the Samsung. Rejected: (b) a background isolate running the same slow decoder, and (c) smaller recordings (they give back detail). Also worth doing for the live camera: one long-lived worker isolate instead of a new `compute` isolate for each full-resolution copy (about one a second).
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

## Duel Test Case (Original Video, 2:42)

Worked out 2026-10-14 from `reference/live-camera/1.mp4` and `2.mp4`: two crops of the original, same timeline, 60 fps, same audio. Mark counted down "three, two, one, go" (barely audible). Both threw; each board's round 4/5 has only this throw (answer key `b2-t10`, `b1-t13`).

| | Mark: board 2 (right) | The Captain: board 1 (left) |
|---|---|---|
| Knife lands (video) | 162.12–162.13 s: in flight 162.083–162.117 s from the top right | 162.15–162.17 s: first seen above the bull at 162.150 s |
| Thud (audio) | **162.132 s** | **162.162 s** |
| Result | **5**, top of the bull | **bounce-out**: hits the bull, slides off down the board (it lands below at about 162.55 s, a later thud) |

- **Winner: Mark, by about 30 ms**, and on score.
- **Decoy:** board 1 brightens across its whole face at about 162.0 s (light or exposure flicker, not a knife). A plain frame-difference trigger takes it for the throw and gets the order wrong; this test should catch that.
- **The knife already in board 1** at the right of the bull (3 o'clock) is from an earlier throw and doesn't move.
- **"Go":** unconfirmed. There's a speech-band burst at about 160.9–161.4 s with quiet after it. If that's "go", both throws took about 1.2 s from go to landing. A clear "three, two, one" isn't separable in the audio; Nigel to listen around 2:40–2:41 and confirm.
- **Possible second duel:** both boards also have a single-throw round at about 177.0 s (`b1-t14` bounce-out, `b2-t11` stuck 3). Not yet checked for a countdown or impact order.
- **Method** (to turn into a test): per-board frame difference restricted to the target, plus a 2 ms audio envelope (onsets over 6× the median), then match thuds to boards by the video landing frames.

