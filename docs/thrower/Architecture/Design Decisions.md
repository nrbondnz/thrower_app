# Design Decisions

Each entry: **Decision**, **Rationale**, **Trade-off**, and the date Nigel confirmed it.

## Why Flutter?

**Decision:** Thrower App is a single Flutter codebase (`thrower_app`).

**Rationale:**
- Same stack as WhereWillWeVisit, so patterns, agents and know-how carry over
- One codebase for mobile, web and desktop

**Trade-off:** Platform-specific code needs conditional handling.

**Confirmed:** 2026-10-04 (project created with `flutter create`).

## What the App Does

**Decision:** The user sets up a phone on a **static** mount pointed at a wooden target and throws **knives or axes** at it. The app finds the target, detects where each throw lands, and records the score. (See Throwing Sport below.)

**Target model (initial, to be refined):**
- Circular, with 5 concentric rings in alternating colours so they can be told apart.
- Scores run from **5** for the innermost ring (bull) to **1** for the outermost ring.
- The camera will usually be off-centre, so the circle appears as an **ellipse** in the image and the app has to locate it rather than assume where it is.

**Confirmed:** 2026-10-04.

## Why iOS and Android Only?

**Decision:** Target platforms are iOS and Android.

**Rationale:** The app is camera-first and is used standing near a physical target, so it belongs on a phone.

**Done:** the `web/`, `windows/`, `macos/` and `linux/` folders and their `.metadata` entries were removed on 2026-10-04 at Nigel's request. To bring a platform back later: `flutter create --platforms=<name> .`

**Confirmed:** 2026-10-04.

## User Accounts Required; Backend and Payments Deferred

**Decision:** The app needs user accounts. The backend and payments are decided later.

**Rationale:** Nigel's call: get the core (vision and scoring) working first.

**Consequence:** Accounts depend on an auth provider, which is a backend choice. Until that's chosen, account and session handling sit behind an app-side interface (`AuthService`) so the provider can be plugged in later without touching the UI or scoring code.

**Confirmed:** 2026-10-04.

## Source Control: GitHub

**Decision:** The project is hosted on GitHub.

**Repo:** `thrower_app`, **private**.

**Branch model:** `main` only for now. Add a dev/prod split when there's a backend or release pipeline that needs one.

**Confirmed:** 2026-10-04.

## Vision and Timing Pipeline: On-Device, Separate from Scoring

**Decision:** Split the work into three layers that don't know about each other's internals:
1. **Camera**: streams frames.
2. **Vision**: finds the target (ellipse plus a rectifying homography to a top-down view) and detects impacts (when, and where in target coordinates).
3. **Scoring domain**: pure Dart. Maps a point in normalised target coordinates (centre 0,0, outer edge radius 1) to a ring score, and tracks throws, rounds and players.

**Rationale:**
- **On-device**, because impact timing needs low latency and it should work without signal. Cloud AI can still be added for analysis or calibration later.
- **The scoring domain is testable with no camera.** Vision outputs a point; scoring never sees pixels.
- **The vision approach can be swapped** (classical OpenCV-style ellipse fitting and frame differencing first, a trained ML model later) without touching scoring or UI.

**Trade-off:** More structure up front than a single camera screen. This is the "architectural purity" option.

**Confirmed:** 2026-10-04 (plan approved).

## Throwing Sport: Knives and Axes into a Wooden Board

**Decision (Nigel, 2026-10-04):** Users throw **knives or axes** (not darts) at a **wooden board with 5 painted circles**. The **camera is static** (fixed in place, not handheld).

**What the reference photo shows** (`docs/thrower/reference/target-example.png`, a stand-in until Nigel's own photos arrive):
- A round slice of log on a three-legged stand. Its outer edge is **irregular, with bark**, so the board's outline is **not** the target. Detection must use the **painted rings**.
- 5 scoring zones, alternating **red paint and bare wood**: red bull, wood, red, wood, red outer ring. The paint is sprayed on, so the ring edges are soft, not crisp lines.
- The surface is **full of old cuts and slots** from earlier throws, so "the board looks different" doesn't on its own mean a new throw.
- The knife handles **stick out towards the camera** and cover part of the rings. Viewed from an angle, the handle appears well away from where the blade went in.

**How the sport scores (research, 2026-10-04):**

| Body | Rings / points | A blade touching a line | Did not stick |
|---|---|---|---|
| **IKTHOF** (knife & axe) | 5 rings at 10 / 20 / 30 / 40 / 50 cm diameter, scoring **5 / 4 / 3 / 2 / 1** | **Higher** score | 0 |
| WATL (axe) | Bull 6, rings 5 to 1, killshot 8 | **Lower** score | 0 |
| IATF (axe) | 5 / 3 / 1, clutch 7 | Where the **majority of the blade** is | 0 |

Nigel's 5-to-1 five-ring target matches the **IKTHOF** layout. Scoring is decided by **where the blade meets the target surface**, not by where the handle is. A throw only scores if it **sticks**.

**Backlog (Nigel, 2026-10-04):** refine scoring by hit point, meaning which line-touch rule applies and any per-sport variants. For now: IKTHOF ring values, a touching blade scores the higher ring, and a throw that doesn't stick scores 0. The line-touch rule should be a setting on `TargetModel`, not hard-coded.

Sources: [IKTHOF tournament rules](https://ikthof.com/tournament-rules/), [WATL rules](https://worldaxethrowingleague.com/axe-throwing-rules/), [IATF standard scoring](https://internationalaxethrowingfederation.com/standard-scoring/), [knife-throwing rules archive](https://thrower-archive.knifethrowing.info/rules.html).

## Single Player First

**Decision:** The first version supports one player. Multiple players and rounds come later.

**Consequence:** The game model (`Session` → `Throw`) should leave room for a `Player` without building multi-player now.

**Confirmed:** 2026-10-04.

## Throw Detection: Before/After Comparison from a Static Camera

**Decision (approach; details are refined in the throw-detection story):**
1. **Calibrate once.** The camera is static, so find the rings' ellipse when the session starts (with optional manual confirmation or a drag-to-adjust overlay) and then lock it. No re-detection every frame.
2. **Keep a reference frame** of the settled board.
3. **Spot a throw** from a burst of motion (and, later, possibly the sound of the impact).
4. **Once the scene is still**, compare it with the reference. If a new object has appeared, it's a **stick**. If there was a burst of motion but nothing new, it's a **bounce-out** (0 points).
5. **Find the blade's entry point.** Take the end of the new object where it meets the board, i.e. the blade and the slot in the wood, **not** the handle. This is the step most likely to need a trained model.
6. Convert the entry point to normalised target coordinates, score it, and make this frame the new reference.
7. **Someone walking up to the board** (to pull out blades) appears as a large occlusion followed by blades removed. That ends the round and resets the reference.

**Rationale:**
- Thrown blades stay put, so the score can be read from a still frame. "Timing" means telling throw, stick, bounce-out and retrieval apart, not catching the blade in flight.
- With a static camera, calibration is a one-off and frame-to-frame comparison is stable.

**Known hard parts (for the throw-detection story):**
- Finding the entry point beneath a handle that sticks out towards the camera and covers it. Axes are worse: a longer handle and a wide blade.
- A board already scarred with old cuts, which must not be mistaken for new hits.
- A knife that sticks and then **falls out** later.
- Outdoor light and shadows changing between throws.
- **Safety:** the phone has to sit outside the line of throw, so viewing from an angle is the normal case, not an edge case.

**Confirmed:** 2026-10-04 (plan approved).

---

*Further decisions are recorded here as they're made in [[story-checkpoint-setting-up-throwing-app]].*
