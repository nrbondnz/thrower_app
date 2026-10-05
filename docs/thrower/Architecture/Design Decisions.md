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

## State Management: Riverpod

**Decision:** Use `flutter_riverpod` (3.x). Layers are wired up in `lib/providers.dart`.

**Rationale:**
- Each layer (camera, vision, scoring, auth) is reached through a provider, so tests and debug screens can swap in a fake: recorded frames instead of the live camera, a fake `AuthService`.
- Handles streams (camera frames, throw events) well.
- Errors are caught at compile time, not looked up at runtime.

**Trade-off:** More concepts to learn than `Provider`/`ChangeNotifier`. Code generation isn't used yet, to keep the build simple.

**Confirmed:** 2026-10-05 (Nigel chose it over Bloc and Provider).

## Code Layout: One Folder per Layer

**Decision:**

| Folder | Layer | Rule |
|---|---|---|
| `lib/scoring/` | Scoring domain | **Pure Dart**: no Flutter imports, no pixels. `TargetModel`, `TargetPoint`, `Ring`, `LineTouchRule`. |
| `lib/auth/` | Accounts | `AuthService` interface and `AppUser`. No provider until the backend is chosen; `authServiceProvider` throws until overridden. |
| `lib/camera/` | Camera | `CameraFrame` (plugin-independent pixels + timestamp), `CameraSource` (interface: `frames()`), `LiveCamera` (the `camera` plugin's back camera), `FrameRateMeter`. Vision depends on `CameraSource`/`CameraFrame` only, never on the plugin. |
| `lib/vision/` | Target finding, throw detection | **Pure Dart, no Flutter imports.** `RgbImage`, `Ellipse`/`fitEllipse`/`fitEllipseRansac`, `TargetLocator` → `ColourRingLocator`, `SyntheticTarget` (test scenes with known answers), `decodeToRgb`. |
| `lib/ui/` | Screens and painters | Depends on the layers through providers. |
| `lib/providers.dart` | Wiring | One place to see and override every layer. |

Folders are created when their first code arrives, never empty "just in case". Navigation is plain `Navigator` until there are enough screens to justify a router.

**Confirmed:** 2026-10-05.

## Camera: `camera` Plugin, Back Camera, No Audio

**Decision:** Use the official `camera` plugin (0.12) with the back camera at `ResolutionPreset.high`. Frames come as BGRA on iOS and YUV420 on Android. Audio is off.

**Permissions:**
- **iOS:** `NSCameraUsageDescription` ("Thrower App watches your target to score each throw."). No microphone string, because the app records no audio.
- **Android:** `CAMERA` only. The plugin also declares `RECORD_AUDIO` and `WRITE_EXTERNAL_STORAGE` (which implies `READ_EXTERNAL_STORAGE`); our manifest removes all three with `tools:node="remove"`. `ACCESS_NETWORK_STATE` (from `androidx.media3`, a no-prompt background permission) remains. `INTERNET` is debug-only.

**Lifecycle:**
- `liveCameraProvider` is `autoDispose`: the camera is released when the screen closes or the app goes to the **background** (`paused`). It isn't released on `inactive`, because the permission prompt itself makes the app inactive.
- Coming back to the foreground re-opens the camera, which also picks up access granted in Settings.
- **No automatic retry** (Riverpod 3 retries failed providers by default; on Android that would re-show the permission prompt after "Don't allow"). The user retries from the error view.

**Denied access:** each `CameraFailure` gets a plain message. "Try again" is offered only where asking again can work (`denied`, `unknown`). Permanent denial points to Settings. No `permission_handler` package yet; add it if a direct "Open Settings" button is wanted.

**Confirmed:** 2026-10-05 (Task 4).

## Target Locating: Pure-Dart Two-Colour Rings

**Decision (Nigel, 2026-10-05):** Process images in **pure Dart** (no OpenCV, no ML model yet), behind the `TargetLocator` interface so either can replace it later.

**Rings can be any two colours (Nigel, 2026-10-05).** Boards are painted in any pair of alternating colours (red/wood, black/white, blue/yellow, …), so the locator **learns the two colours from the image** instead of using fixed thresholds. Nigel chose this over asking the user to pick the colours. The first version (Task 1) was hard-coded to red paint on bare wood.

**How `ColourRingLocator` works:**
1. Downscale to 600 px on the long side.
2. **Find candidate centres.** Reduce the image to an 8-colour palette (seeded k-means, so the result is repeatable). Merge palette colours closer than 45 RGB units, so one flat colour with sensor noise isn't split into speckles. The centres of the 12 largest single-colour regions (each at least 0.1% of the image) are the candidates. On a target, the bull's region and each ring's region are all centred on the target.
3. **Learn the colours per candidate.** Cast 72 probe rays. Colour **A** (the bull) is the median colour inside the first edge, where the colour changes by more than `edgeContrast` = 60 RGB units. Colour **B** is the median colour of the band where the next ring should be. Ratios along a ray through the centre survive an affine view, so that band sits at a fixed multiple of the bull's edge. The candidate is rejected if A and B differ by less than 60. The probes also give a rough target size.
4. Cast 180 rays from the centre. Along each ray:
   - Each sample is A, B or **neither** (more than 0.55 × the A–B distance from both). Blends along a sprayed edge always count as A or B. **"Neither" samples (handles, shadows, slots, bark, background) are gaps and are skipped.**
   - A majority filter puts sprayed, fuzzy edges at their midpoint.
   - The A/B runs (bull = A, then B, A, B, A) give the boundaries in order (0.2, 0.4, 0.6, 0.8).
   - A boundary hidden inside a wide gap (under a handle) is dropped for that ray.
5. Fit an ellipse per boundary with **RANSAC** (Halíř–Flusser direct fit), so bad rays are outvoted. Re-centre and repeat (3 passes).
6. Sanity-check each candidate's result (shared centre, growing outwards, roughly in proportion within 35%) and score it with a **confidence** (the share of ray samples on the fitted ellipses). The best plausible candidate wins; the search stops early once one passes 0.85.

**Known weakness:** a handle whose colour is close to one ring colour (dark handles on a black or dark-green board) counts as that colour rather than as a gap. RANSAC outvotes most of these rays. On the synthetic green-bull scene with handles, the fit stays within 3%.

**Measured boundaries, not ideal ones:** hand-painted boards aren't exact. On the reference photo the bull's edge is about 0.28 of the 0.8 edge rather than 0.25. The proportion check is therefore loose, and **scoring (Task 4) should use the measured boundaries**, not the ideal IKTHOF radii.

**The outer ring's outer edge isn't fitted.** On a log board the outer red often runs on to the bark, so `TargetFound.outer` is *extrapolated* (the 0.8 boundary × 1.25). **Open question for Nigel:** on his board, does ring 1 end at a painted line or at the board's edge? This decides how the outermost ring is scored.

**From camera frame to rings (Task 2):** `locateInFrame` (top-level, run with `compute`) does `frameToRgb` → `ColourRingLocator`.
- `frameToRgb` converts BGRA (iOS) or YUV420 (Android, U/V pixel stride 1 or 2) to RGB, downscales to 600 px on the long side (fractional step, sampled) and rotates upright in one pass.
- **Upright rotation** = `(sensorOrientation − deviceOrientation + 360) % 360` (`frameRotation`, `LiveCamera.uprightRotation`). This assumes stream frames arrive in sensor orientation on **both** platforms. Android is the usual case; **iOS is unverified until Nigel's device check**.
- **Overlay alignment:** the outline is drawn as `CameraPreview`'s `child`, which the plugin sizes and places exactly over the preview, scaled by preview width ÷ upright image width. This assumes the image stream and the preview share a field of view (same `ResolutionPreset`); checked by eye on the device.

**Performance:** about 270 ms on a PC for a 600 × 800 photo (130 ms when it was red-only; trying several candidate centres costs the extra). It runs in a background isolate on the phone; the device timing is still to be measured. That's fine for a one-off calibration; throw detection may need a smaller region of interest.

**Confirmed:** 2026-10-05 (plain-Dart image processing chosen by Nigel; algorithm from Task 1).

## Throwing Sport: Knives and Axes into a Wooden Board

**Decision (Nigel, 2026-10-04):** Users throw **knives or axes** (not darts) at a **wooden board with 5 painted circles**. The **camera is static** (fixed in place, not handheld).

**What the reference photo shows** (`docs/thrower/reference/target-example.png`, a stand-in until Nigel's own photos arrive):
- A round slice of log on a three-legged stand. Its outer edge is **irregular, with bark**, so the board's outline is **not** the target. Detection must use the **painted rings**.
- 5 scoring zones, alternating **red paint and bare wood**: red bull, wood, red, wood, red outer ring. (Other boards use other colour pairs; the locator handles any two. See Target Locating.) The paint is sprayed on, so the ring edges are soft, not crisp lines.
- The surface is **full of old cuts and slots** from earlier throws, so "the board looks different" doesn't on its own mean a new throw.
- The knife handles **stick out towards the camera** and cover part of the rings. Viewed from an angle, the handle appears well away from where the blade went in.

**How the sport scores (research, 2026-10-04):**

| Body | Rings / points | A blade touching a line | Did not stick |
|---|---|---|---|
| **IKTHOF** (knife & axe) | 5 rings at 10 / 20 / 30 / 40 / 50 cm diameter, scoring **5 / 4 / 3 / 2 / 1** | **Higher** score | 0 |
| WATL (axe) | Bull 6, rings 5 to 1, killshot 8 | **Lower** score | 0 |
| IATF (axe) | 5 / 3 / 1, clutch 7 | Where the **majority of the blade** is | 0 |

Nigel's 5-to-1 five-ring target matches the **IKTHOF** layout. Scoring is decided by **where the blade meets the target surface**, not by where the handle is. A throw only scores if it **sticks**.

**Backlog (Nigel, 2026-10-04):** refine scoring by hit point, meaning which line-touch rule applies and any per-sport variants. For now: IKTHOF ring values, a touching blade scores the higher ring, and a throw that doesn't stick scores 0. The line-touch rule is a setting on `TargetModel` (`LineTouchRule.higher` / `.lower`), not hard-coded. **Implemented in Task 3:** `TargetModel.scoreAt(point, bladeHalfWidth:)` treats a blade as touching a line when it comes within `bladeHalfWidth` of it; a point exactly on a line counts as touching. IATF's majority-of-blade rule needs the blade's extent and stays on the backlog.

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
