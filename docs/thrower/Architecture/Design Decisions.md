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
| `lib/camera/` | Camera | `CameraFrame` (plugin-independent pixels + timestamp), `CameraSource` (interface: `frames()`), `TargetCamera` (a `CameraSource` the screens use: upright rotation, zoom, `minChange`), with two implementations: `LiveCamera` (the `camera` plugin's back camera) and `RecordedCamera` (a Live test recording, `FramePack`). `FrameRateMeter`. Vision depends on `CameraSource`/`CameraFrame` only, never on the plugin. |
| `lib/vision/` | Target finding, throw detection | **Pure Dart, no Flutter imports.** `RgbImage`, `LumaImage`, `Ellipse`/`fitEllipse`/`fitEllipseRansac`, `TargetLocator` → `ColourRingLocator` (via `buildTargetLocator`), `TargetCalibration`, `zoomToFit`, `MotionDetector`, `classifyThrow`, entry points (`GeometricEntryEstimator`, `faceOnEntry`), `image_difference.dart`, `SyntheticTarget` (test scenes with known answers), `decodeToRgb`. |
| `lib/game/` | Watching a game | Joins camera and vision: `ThrowWatcher` (frames → `ThrowEvent`s), `ThrowTracker` (knives in the board, visit cool-down), `findTarget` (Find target with zoom), `WatchDebugLog`. |
| `lib/ui/` | Screens and painters | Depends on the layers through providers. `RoundMarks` holds the Play screen's marks for the round. |
| `lib/providers.dart` | Wiring | One place to see and override every layer. |

Folders are created when their first code arrives, never empty "just in case". Navigation is plain `Navigator` until there are enough screens to justify a router.

**Confirmed:** 2026-10-05.

## Camera: `camera` Plugin, Back Camera, No Audio

**Decision:** Use the official `camera` plugin (0.12) with the back camera at `ResolutionPreset.high`. Frames come as BGRA on iOS and YUV420 on Android. Audio is off.

**Permissions:**
- **iOS:** `NSCameraUsageDescription` ("Thrower App watches your target to score each throw."). No microphone string, because the app records no audio.
- **Android:** `CAMERA` only. The plugin also declares `RECORD_AUDIO` and `WRITE_EXTERNAL_STORAGE` (which implies `READ_EXTERNAL_STORAGE`); our manifest removes all three with `tools:node="remove"`. `ACCESS_NETWORK_STATE` (from `androidx.media3`, a no-prompt background permission) remains. `INTERNET` is debug-only.

**Lifecycle:**
- `cameraProvider` (was `liveCameraProvider`) is `autoDispose`: the camera is released when the screen closes or the app goes to the **background** (`paused`). It isn't released on `inactive`, because the permission prompt itself makes the app inactive.
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

## Find Roughly, Then Look Closely (Coarse-to-Fine)

**Decision (Nigel, 2026-10-08, option 1 of 2):** All ring finding goes through `buildTargetLocator` = `CoarseToFineLocator(ColourRingLocator)`:
1. A rough pass on the whole (downscaled to 600 px) image. Its rejected attempt is enough to say where the board is. **If it returns nothing at all, it's retried once at 1200 px** (on the uncompressed 1× render with no knives, the 600 px pass found nothing, while the 1200 px pass gave a position that the close-up then found at 92%).
2. A crop of 1.8 × the target radius each side, from the **full-resolution** image.
3. A second pass on the crop, moved back into whole-image coordinates. If the close-up fails, the rough result stands.

The camera path keeps frames at full camera resolution for this (`frameToRgb(maxSide: 1920)`; 1280 × 720 at `ResolutionPreset.high`).

**Why:** from beside the throwing line (2 m to the side, 2 m out) the board fills only about 1/6 of the main camera's width. Once shrunk to the finder's 600 px, the bull was about 10 px across and knife handles swamped the rings. With knives in the board, the finder **failed on both 1× views** (rendered tests). Coarse-to-fine finds all six rendered views (78–93% confidence). The rejected alternative, telling users to use 2× zoom, depends on the phone and on the user. (Since 2026-10-11, the app zooms the camera in on the board itself after the first find; see Zoom the Camera onto the Target.)

**Dim or flat light (2026-10-08):** each pass is wrapped in `ContrastNormalisingLocator`. The image is tried as it is; **only if that fails**, it's retried with brightness stretched (1st/99th percentile → 0/255, the same map on all channels, so hues are kept). Found from Nigel's first real Android frame (A4 printout, indoors): the frame itself worked (97%), but at half brightness or half contrast it wasn't found, because the ring colours fell under `edgeContrast`. Stretched: 93% / 97% (30% brightness: 94%). It's a fallback, not the default: stretching also boosts white paper against a grey wall, which made the finder pick the paper when the target was cut off by the frame edge.

**Cost:** two passes, about 0.4–0.6 s on a PC for a 1600 × 1200 image (a third, larger pass only when the first finds nothing).

**Confirmed:** 2026-10-08.

## Adjust and Lock the Calibration

**Decision (Task 3):** after "Find target", the rings become a `TargetCalibration` (the ring ellipses + the upright image size) that the user can correct and then **lock for the session** (`calibrationProvider`, not auto-disposed; "Re-calibrate" unlocks). It's in memory only: a new app session calibrates again, since the phone may have been moved.
- **Adjustments act on all rings together**, driven by the outer ring: drag inside to move; drag the long-axis handle to turn and stretch; drag the short-axis handle to stretch the short axis. The rings stay in proportion and keep their perspective offsets.
- **A rejected attempt can be adjusted and locked too**, so a near miss can be fixed by hand rather than retried forever.
- **Safety (Review Agent §7):** whenever the outline can be adjusted, the screen shows *"Only adjust when no one is throwing."* The phone sits beside the board, so adjusting means standing near the throwing lane.

## Zoom the Camera onto the Target (2026-10-11)

**Decision (Nigel, 2026-10-11):** *"on find it zooms to the target using camera zoom"*, using the camera's own zoom, **not** a crop of the picture. Built as Task 4 of [[story-checkpoint-live-test]], before throw detection, so knife detection is tuned on zoomed pictures.

**Why camera zoom:** frames reach the app at 1280 × 720 (`ResolutionPreset.high`) whatever the zoom. The phone zooms by cropping the sensor *before* that scale-down, or by switching to a telephoto lens, so a zoomed board gets several times more **real** pixels. A software crop would only enlarge the 720p pixels the app already has. The knives seen so far are small blobs (Live test footage) and the minimum-knife-size rule is marginal at small scales, so more pixels on the board helps every later step.

**How (`findTarget`, `lib/game/find_target.dart`):**
1. Zoom back to 1× (so **Find again** always starts from the whole picture) and find the rings.
2. `zoomToFit` (`lib/vision/zoom_to_fit.dart`) picks the zoom. The camera zooms about the **centre of the picture**, so the zoom is the smallest of:
   - the zoom at which the board fills **70%** of the picture's shorter side (`fill`), which leaves room for knife handles sticking out and for small nudges, which zoom makes bigger
   - the zoom at which the board, plus **0.3 × its radius** around it (`margin`), still fits in the picture: a board far from the centre limits the zoom (`offCentre`)
   - the camera's maximum (`TargetCamera.maxZoom`)

   A gain under **1.2×** (`minGain`) isn't worth searching again, so it gives 1×.
3. Zoom (`TargetCamera.setZoom`), wait **500 ms** for the frames to catch up, and find the rings again in the closer view.
4. If they aren't found zoomed in (or the camera refuses to zoom), go back to 1× and keep the first result.

**Off-centre board (Nigel's choice):** zoom as far as keeps the board in shot, and the status adds *"Centre the board in the picture for a closer view."* The status also says how far it zoomed ("zoomed in 2.4×").

**The zoom belongs to the calibration.** `CalibrationState.zoom` is kept through adjusting, locking and Re-calibrate. `cameraProvider` re-applies it whenever the camera reopens (for example, going from Calibrate to Play), because rings found zoomed in only line up at that zoom.

**Recordings can't zoom** (`RecordedCamera.maxZoom` = 1): their pixels are all there is, so the Live test is unchanged.

**Unverified until a device check:** that the camera plugin's `setZoomLevel` zooms the **image stream** as well as the preview, on both iOS and Android, and that 500 ms is long enough for it to show.

**Confirmed:** 2026-10-11 (placement and off-centre behaviour chosen by Nigel).

## Motion and Settle (Throw Detection, Task 2)

**Decision:** `MotionDetector` (pure Dart) works on **brightness only**, downscaled to ~320 px (`frameToLuma`: the Y plane on Android, converted BGRA on iOS), inside a `WatchRegion` = the locked outer ring's bounding box × 1.5 (room for handles). It runs about 15 times a second (`WatchStatus` processes a frame at most every 60 ms).
- A pixel has **changed** if it differs from the previous frame by more than 6 × the estimated sensor noise, at least `TargetCamera.minChange` levels (12 for the live camera, 20 for a recording). The noise is learned while the board is still. **Each pair of frames also sets its own floor:** 5 × its robust noise (1.4826 × the median difference), so compressed video's whole-picture jumps don't count (2026-10-11; see Throw Detection on Real Footage).
- States: **watching → motion** (the **largest connected changed shape** ≥ 0.1% of the region) **→ settling** (< 0.05%) **→ settled** after 0.3 s still, reporting a `MotionEpisode`. Until 2026-10-11 this was the total share that changed (0.2% / 0.08%); one compact shape tells a knife from scattered compression blocks.
- **"Still" isn't "clear":** the rendered retrieval showed a person standing still at the board reads as settled. So the detector keeps a **reference** frame of the last settled board, and only settles when **< 8%** of the region differs from it; otherwise it's **blocked** (something in the way). After 5 s still but different, the view is accepted as the new normal (flagged), e.g. lights switched on.
- Each episode reports its **peak change** (a person: ~25%; a throw: ~0.6–1.5%) and its **change from before** (a stuck knife: ~0.6–0.7%; a bounce-out: 0.0%; knives removed: ~1.2%), the basis for telling stick from bounce-out (Task 3) and retrieval (Task 5).
- The knife's flight is effectively invisible (one faint blurred frame): **episodes start at the impact.**

## Stuck or Bounced Off (Throw Detection, Task 3)

**Decision:** `classifyThrow(episode, calibration)` decides what a settled episode was:
1. Accepted as a new view → **scene changed** (not a throw; maybe re-calibrate).
2. Someone stood at the board (`wasBlocked`), ≥ 10% of the region changed at once, or one person-sized shape moved (`peakShape` ≥ 2% of the region) → **board visit** (not a throw).
   - **Except a knife placed by hand** (decided 2026-10-09, so Nigel can test with a pen on the A4 printout): if the visit left a knife-sized new shape that **appeared** (`appeared`: the shape stands out from the board around it in the *after* picture, not the *before*), isn't one of the known knives and no known knife was taken out, it's a **stuck** knife and scores like a throw. A visit that removes knives the app never saw stays a board visit, because that shape disappeared.
3. Otherwise, pixels differing from the before frame by more than the episode's threshold are grouped into connected shapes (8-connected) within 1.5 × the outer ring. The largest one that touches the target (outer × 1.05) and covers ≥ **0.25%** and ≤ **6%** of the target's area (min 4 px) → **stuck**, with the shape kept for the entry point (Task 4). Otherwise → **bounce-out** (0), if a knife-sized shape was seen moving (`peakShape` ≥ 0.22% of the region), or else **nothing** (a flicker; ignored).

**Margins on the renders (320 × 180 frames, target ~46 × 33 px):** stuck knives make shapes of **84 / 68 px** against a 12 px minimum; the bounce-out **0 px**. Noise (σ 4) and a shape away from the target don't count.

**Falling out (Task 5):** a knife falling out on its own leaves a "new shape" where it was. `classifyThrow(knownKnives:)` compares the shape with the knives already in the board (kept by `ThrowTracker` until someone collects them). Overlapping one by ≥ 50% means **fell out**, not stuck, unless the shape **appeared** (head-on knives thrown side by side overlap; 2026-10-11).

## Throw Detection on Real Footage (Live Test, 2026-10-11)

**Goal:** the two Live test recordings give exactly the throws, bounce-outs and collections in Nigel's answer key (`reference/live-camera/truth.json`), checked by `test/game/live_replay_test.dart`, which replays every frame through `MotionDetector` and `ThrowTracker`. Before these changes, nearly every second was a false bounce-out, and board 2 was "blocked" for 49 s. Now both boards match (Task 5 of [[story-checkpoint-live-test]]).

**What the footage needed, and the rule each led to (all measured on the recordings):**
- **Compression jumps:** about once a second the encoder re-encodes the picture and every pixel shifts by a few levels (median difference 3–9 instead of ~0). → **Per-pair threshold** (`MotionDetector.pairNoise`): 5 × that pair's robust noise.
- **Re-encoded blocks:** when anything moves elsewhere in the video (board 2 being hit), board 1's picture gets mid-grey blocky changes: up to 12 px shapes at a 20-level floor, while every real throw made 20+ px. → **Motion = largest connected shape**, and a **minimum change of 20** for recordings (`RecordedCamera.minChange`). The live camera keeps 12: at 20, the rendered ring-3 knife (low contrast on paint) was missed.
- **Refocusing and people at the picture's edge:** soft, spread-out changes with nothing left behind. Real bounce-outs moved a 42+ px shape (0.26% of the region), the false ones 27 px or less. → A bounce-out needs `peakShape` ≥ **0.22%**; smaller is **nothing**. A person walking up moves 686 px (4.3%), and no knife more than 132 px. → `peakShape` ≥ **2%** is a **visit**.
- **People walking back after collecting:** false events 0.6–1.6 s after a visit; the next real throw comes 6+ s after it. → `ThrowTracker.visitCooldown` **3 s**: anything but a stuck knife within it is part of the visit.
- **Small head-on knives:** before and after straddle a compression jump, so at 5 × noise (thresholds 30–44) three knives showed as only 9–12 px against the 12.6 px minimum. → The before/after comparison uses **3.5 × noise** (`settledNoiseFactor`); no bounce-out left anything behind even then. After a **visit** it stays at 5 × (`MotionEpisode.visitThreshold`), so marks left by collecting don't look like a placed knife; knives being **taken out** are still checked at the sensitive threshold.
- **The board re-exposing** made an 860 px "knife". → A knife covers at most **6%** of the target's area (the largest real one: 1.9%).
- **Knives side by side:** board 1's 140.5 s knife overlapped the 133 s one and was read as it falling out. → Fell out only if the shape **disappeared** (`appeared` is false).

- **Someone passing close to the camera** (board 2 at 97 s: a body filled the picture for 2.6 s) ended a round with one knife thrown. → A "visit" under **3 s** (`minVisit`) in which no one stood still and no known knife was taken is **nothing**. The shortest real collection took 3.9 s.

**Where a face-on knife went in (Task 6):** the side-view estimator decides which end is the handle from the board's tilt, which is noise on a face-on board (both recordings' rings are 0.95–0.97 as tall as wide), and it re-finds the knife by colour without the compression handling. On a **face-on** board (`isFaceOn`: short axis ≥ 0.9 × long axis), `faceOnEntry` takes the classifier's knife shape and uses its pixels **nearest the bull**. A camera in front of the board sees a handle lean away from the point it looks along (roughly the bull), and it's also the line rule (touching a line scores the higher ring).
- Against Nigel's scores (19 knives): **11 exact**, off by 12 rings in all. Alternatives: the shape's middle 11 exact (off by 13); the end along its axis nearer the bull 10; the side-view estimator 5–9.
- All but two are within a ring. The two are board 1 at 40.5 s and 43.2 s, where the changed shape isn't where Nigel places the knife (dark knives in the dark bull barely change the picture).
- At 140 px the rings are ~8 px apart and Nigel's own reading "is not always clear", so the replay test sets a floor (5 of 10 and 6 of 9), not a match.

**Confirmed:** 2026-10-11 (rules derived from the recordings; Nigel's device check pending).

## Rounds and Scoring (Throw Detection, Task 5)

**Decision:**
- **Single player, rounds of 3 throws** (Nigel). `GameSession` (pure Dart, immutable):
  - a throw is stuck (scored at its entry), a bounce-out (0) or fell out (0);
  - a stuck knife whose entry wasn't found counts as a throw, **unscored ("?")**;
  - a **board visit** (someone collecting the knives) closes the round;
  - throwing on after a full round starts the next round without waiting.
- **Assumed rule, to confirm with Nigel: a knife that sticks and then falls out (before being collected) scores 0.**
- Pieces:
  - `ThrowTracker` (pure): classification + the knives in the board.
  - `ThrowWatcher`: camera → detector → tracker → full-resolution entry, off the UI thread; emits `ThrowEvent`s.
  - `GameNotifier` (`gameProvider`): events → `GameSession`, scoring entries with `TargetMapping` + `TargetModel`.
  - **Play screen:** live picture, locked rings, round and game totals, and the round's marks (`RoundMarks`, since 2026-10-11): a yellow circle with its score where each knife went in, and a "0" beside the board for each bounce-out (or a stuck knife whose entry wasn't found, or one that fell out). Cleared when the knives are collected or the next round starts.
- **Safety:** at the end of a round the screen says *"Collect your knives when no one is throwing"*. It never says the lane is clear.

**Update (2026-10-09, [[story-checkpoint-instructions-and-game-length]]):**
- **A game is a fixed 9 rounds** (`GameSession.maxRounds`, default 9). `isOver` = round 9 complete (3 throws, or closed early by collecting). Later throws are ignored: `GameSession` returns itself, and `GameNotifier` doesn't remember a post-game knife, so it falling out can't zero a real throw. A round-9 knife falling out after game over still scores 0. Play shows "Round N of 9"; at game over "Game over! Final total" with every round, plus a **New game** button.
- **Reset asks first:** the Play app-bar button is **Reset game** (disabled before the first throw) with "Reset this game? Scores will be lost." Chosen over an instant reset so a stray tap mid-game can't wipe the scores. *New game* at game over doesn't ask.
- **In-app Instructions** (`lib/ui/instructions.dart`, *Instructions* on Home): Dart content, no Markdown package. Game length, throws per round, ring scores and the line-touch rule are read from `GameSession` / `TargetModel`, so the text follows the rules. Chosen over a Markdown asset (easier prose editing, but a new dependency and hand-typed numbers that drift). Keeping it current: [[Common Tasks#Update the In-App Instructions]].
- **Two versions** (Nigel, 2026-10-09): **Real board** (default; the main one: 75–85 cm board, phone 2 m away out of the line of throw, lane safety) and **Paper target** (A4 printout at 100%, phone 50 cm away, pens in Blu Tack placed by hand, hand-wave = bounce-out, never throw at the paper). One page with a switch at the top (`InstructionTarget`), not two screens: calibrating, scoring, resetting and reporting are shared, so they can't diverge.

## Blade Entry Point (Throw Detection, Task 4)

**Decision (D1 option A, geometry):** `GeometricEntryEstimator` (behind `EntryPointEstimator`, so a trained model can replace it) works on **full-resolution** upright before/after pictures (the calibration's own size):
1. **Colour** change (largest channel difference > 20) near the target → the largest new shape touching it. **Not brightness:** shaded steel on red paint has almost the paint's brightness (the rendered ring-3 knife's blade vanished that way: 6.4 px off and the wrong score), but a very different colour.
2. Keep the **steel** pixels (saturation < 0.3). A knife's shadow is new too and starts at the entry point, but keeps the board's hue. If too little is grey, fall back to the whole shape.
3. The steel pixels' **principal axis** is the knife's line; its ends are the 2nd / 98th percentile along it.
4. **Which end is the entry:** the knife sticks out towards the thrower. In the image "out of the board" points from the outer ring's ellipse centre towards the bull's centre (a tilted circle's centre appears shifted towards the far side). The handle is that way; the entry is the other end, taken as the centre of the knife pixels within 2 px of it.

**On the phone (`WatchStatus`):** while still, a full-resolution "before" is kept (refreshed every second, off the UI thread). When an episode is classed **stuck**, the next frame is the "after"; the entry is found in the background, scored through `TargetMapping` and shown as a yellow circle with its score. **Face on** (`isFaceOn`), the entry comes straight from the classifier's knife shape instead (`faceOnEntry`; see Throw Detection on Real Footage). The after then becomes the next before.

**Accuracy on 6 rendered throws** (2 sequences at 1280 × 720, 4 camera views at 1600 × 1200, 1× and 2×): **0.7–1.7% of the target radius (about 3–6 mm on an 80 cm board); every score correct**, including the ring-3 knife next to the 3/2 line.

**Assumes** something sticking out of the board that's mostly grey steel. A flat or coloured object (a pen taped to paper) won't give the right end.

## The Knives

**Nigel's knives (2026-10-08, photo):** all-steel throwing knives: one flat piece of brushed stainless steel; spear-point blade **~10 cm**; flat handle **~10 cm** with a row of **see-through holes** (three small, one larger at the end). No separate dark handle.

**What it means for detection:**
- A stuck knife shows as **bright grey steel**, not a dark bar. It takes on the light: dark grey when its face is turned from the sun, bright with highlights when facing it, tinted by sky or grass. It can't be found by "dark object on the board".
- The board **shows through the handle's holes**, so a stuck knife isn't one solid region in a before/after difference.
- About **2.5 cm** of blade is in the wood when stuck, so ~7.5 cm of blade plus the 10 cm handle stick out.
- The renderer models all of this (`SyntheticScene._bladeAndHandle`: tapered blade profile, holes).

## Board Size

**Nigel's boards are about 75–85 cm across** (2026-10-08; answers open question Q2). The rendered test views use **80 cm**, with the rings in the reference photo's proportions: the outer scoring ring is about 74 cm across, larger than IKTHOF's 50 cm. **Camera about 2 m from the board, off to the side at about 45°** (Nigel, 2026-10-08); the renders use this. **Throwing distance 4 m; 3 throws per round; knives first, axes later** (Nigel, 2026-10-08).

## Score Against the Painted Rings, Not Ideal Ones

Measured on the reference board, the painted edges are at **0.219, 0.395, 0.620** (relative to the 0.8 edge), not 0.2 / 0.4 / 0.6. A knife near a line can score differently depending on which you use. So scoring must use the **fitted** ring ellipses. The rendered test views' answers (`truth.json`) already do.

**How (Task 4, `TargetMapping`):** along the line from the bull's centre through an image point, find the painted edges either side of it (each its own fitted ellipse, so perspective is handled) and interpolate between their **ideal** radii. A point on a painted edge maps to exactly that edge's ideal radius, so `TargetModel` (ideal radii, line-touch rule) scores the board as painted. Inside the bull: proportional. Beyond the outer edge: continues at the outer ring's rate. The approach was chosen over a single affine or homography fit because those assume the paint is at the ideal radii.

**Accuracy on the rendered views:** every knife scores correctly; entry radii are within 0.01 of the target radius (about 4 mm on an 80 cm board).

## Rendered Camera Views (Test Data)

`lib/vision/synthetic_scene.dart` ray-traces the setup:
- A log board on a three-legged stand, on grass.
- A phone camera with perspective, at any position and field of view.
- Knives (steel blade + dark handle) at any entry point, pitch and yaw.
- Sun shadows.

`PhotoBoardTexture` paints the **real reference photo** onto the board (Nigel: "target-example is the core for all the pictures"). It traces the photo's bark outline, removes the photo's own knives (refilling from the same ring further round) and uses the photo's measured ring sizes.

Each render comes with its answers: each blade's entry point (board and pixel), its score, and the ring edges in the image. That makes these test data for ring finding now and for throw detection later. They're not a substitute for real photos: lighting, lens and blur are simplified.

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

## Live Test: A Recording in Place of the Camera (2026-10-11)

**Decision:** the Live test plays a recording of a real board **as a camera**, through the same calibrate → Play screens and the same vision and game code. It's analysed live on every run; the app holds no answers ([[story-checkpoint-live-test]]).

- **`TargetCamera`** (`lib/camera/target_camera.dart`): what the screens and `ThrowWatcher` need from a camera: `frames()`, `uprightRotation` and `dispose()`. There are two implementations:
  - `LiveCamera`, the phone's back camera
  - `RecordedCamera`, a recording
- **`cameraProvider`** opens one of them, depending on `recordingChoiceProvider` (null means the live camera). `calibrationProvider` and `gameProvider` watch that choice: a calibration and a game belong to the camera they were made with, so switching starts both afresh. Leaving the Live test screen switches back to the live camera.
- **`RecordedCamera`** behaves like a camera:
  - It delivers a frame every 1/fps seconds to whoever listens: BGRA, already upright, stamped with a monotonic clock.
  - It **opens paused on the first frame**, so the board can be calibrated before anything happens.
  - Play calls `restart()`; playback stops on the last frame.
- **Recording format:** `FramePack` (`.tfrm`, `lib/camera/frame_pack.dart`) is JPEG frames at a fixed rate in one asset, decoded in pure Dart with `package:image`. That means no video plugin, so no native code or permissions.
  - Made with `tool/pack_recording.dart` (needs ffmpeg).
  - Target 1 and Target 2: 140 × 140 px, 15 fps, 2,848 frames, about 10.4 MB each.
  - **In TestFlight builds too** (Nigel, 2026-10-11), so his brother can run them.
- **Rejected:** a video plugin for decoding (native code, and no frame-pixel access in `video_player`); pre-computed results (not a test of the pipeline).

## Ring Finding on Real Boards: Colour Edges, Any Paint (2026-10-11)

**Problem:** the two Live test boards (see Live Test above) are painted in **several colours on wood**:
- board 1: dark bull, wood, red, wood, red
- board 2: red bull, wood, red, wood, dark green

On top of that, they are small (a 140 px crop, bull radius about 8.5 px) and blurred by compression. `ColourRingLocator` assumed two alternating colours, so it found neither.

**Measured truth** (colour averaged all the way round the centre, on the still at the start of each video): the boundaries are at 8.5 / 16.5 / 25–25.5 / 32.5 px, with the outer edge at 41.5–42.5 px. That's almost exactly the IKTHOF proportions: 2, 3 and 4 bull radii. The pale rim beyond, out to about 48 px, is wood (scores 0).

**Decision:** `ColourRingLocator` now reads every candidate centre two ways and keeps the better plausible fit:
1. **Two colours** (as before): A/B runs along rays.
2. **Colour edges** (`_Reading.edges`):
   - Along each ray, the colour change is measured at a scale of about 8–16% of the bull radius, so it ignores grain.
   - The bull's edge is the **strongest** edge between 0.6× and 1.5× the expected bull radius. (The first edge can be texture, or knives inside the bull.)
   - Each further boundary is the strongest edge within ±15% of 2, 3 and 4 **times that ray's own bull edge**. Measuring along the same ray cancels perspective.
   - This is colour-blind: it works whatever the paint.

**Also changed:**
- **Small images are enlarged** (bilinear) to at least 420 px first (`minWorkingSize`). Board 2 was found far more reliably at 3×.
- Each candidate keeps its **best plausible pass**, not its last: re-centring sometimes made a good fit worse.
- **Fits below 40% confidence are rejected** (`minConfidence`, reported as "Rings too unclear"). On the recordings, wrong fits scored 23–47% and right ones 46–78%.

**Result** (every 10 s through each 3-minute video):
- Target 1: 13 of 19 right, 1 wrong.
- Target 2: 8 right, 2 wrong.
- The rest are "not found", mostly when people, knives or a compression jump are in the frame.
- **Both first frames, where the Live test calibrates, are right.**

`test/vision/live_recording_locate_test.dart` guards this. Every earlier fixture (the reference photo, renders, the A4 printout) still passes.

**Rejected:**
- **Paint vs wood by colour distance.** Board 1's inner wood ring comes out pinkish: about 47 from the wood and 52 from the red, so no single cut-off separates them.
- **Picking boundaries from piles of edges across rays.** The speckled wood of board 2 drowned the piles.
- **Expected sizes from the outer estimate.** Hand-painted ring widths and a wrong bull estimate shifted the windows.
