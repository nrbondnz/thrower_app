# Glossary: Components, Functions and Concepts

Three kinds of thing (Docs Agent §5): **components** (system elements), the **functions** they perform (parent → child), and **concepts** (terms that mean something on their own and may be used by several components). Names match the code.

## Component → Function Tree

- **`LiveCamera`** (`lib/camera/live_camera.dart`)
  - `open`: back camera, `ResolutionPreset.high`, no audio; plugin errors → `CameraFailure`
  - `frames`: broadcast stream of `CameraFrame`, only while listened to
  - `uprightRotation`: `frameRotation(sensorOrientation, deviceOrientation)`
- **`RecordedCamera`** (`lib/camera/recorded_camera.dart`): a Live test recording played as a camera
  - `load(Recording)`: the `FramePack` asset, plus an `AssetRecordingSound` if the recording has `audio`
  - `restart`: play from the start (sound too); `rewind`: stop and wait on the first frame (sound stopped)
  - `playbackTime(timestamp)`: how far into the recording a frame was delivered (null before playback starts); Quick draw's times
  - **`RecordingSound`** (`lib/camera/recording_sound.dart`): `playFromStart`, `stop`, `dispose`; `AssetRecordingSound` (`audioplayers`; `audioContext`: ducks other apps, ignores the silent switch). A failing sound is reported; frames play on
- **`CroppedCamera`** (`lib/camera/cropped_camera.dart`): a part of another camera's picture as a camera of its own (upright sources only)
  - `frames` → `crop`: each frame as a view into the source's bytes (BGRA, YUV; `x`, `y` rounded down to even)
- **`QuickDrawScreen`** (`lib/ui/quick_draw_screen.dart`): `quickDrawCameraProvider` → full-screen `RecordedPreview`, Play / Play again → `restart`
  - tap (image pixels) → `tapLocatorProvider` → `boardAt` → `quickDrawTargetsProvider.add`; Lock boards → `lock`; Start again → `clear` + `rewind`
  - Play with the boards locked → a fresh `QuickDrawWatcher`; Start again / leaving → `dispose`
  - **`BoardsPainter`**: each board's rings and its player number (blue while choosing, green once locked); `results`: each player's line under their board
  - `throwText(QuickDrawThrow, camera)`: "3.62 s · 5" / "3.65 s · bounced" (impact via `playbackTime`); null before the throw is in
- **`QuickDrawTargets`** (`lib/game/quick_draw_targets.dart`): the boards in tap order, `players` (2), `complete`, `locked`; `QuickDrawTargetsNotifier` (`lib/providers.dart`): `add`, `clear`, `lock`
  - `locateAtTap`: the camera's next frame → `compute(locateTappedInFrame)`; `boardAt`: result → `TargetCalibration` or null
- **`QuickDrawWatcher`** (`lib/game/quick_draw_watcher.dart`): `start`: per board a `CroppedCamera` (`cropRadii` 4) + `TargetCalibration.within` + `ThrowWatcher(interval: zero)`
  - `throws`: each player's first stuck or bounce-out event as a **`QuickDrawThrow`** (`impact` = `MotionEpisode.impact`, `stuck`, `score` via `TargetMapping` → `TargetModel.scoreAt`); `dispose`
- **`locateTappedInFrame`** (`lib/vision/tapped_target_locator.dart`): `frameToRgb` (upright, cap 1920 px) → `locateTargetAt` per tap, in tap order
  - **`locateTargetAt`**: window 0.45 × the shorter side around the tap → `ColourRingLocator` (`seed` = the tap, enlarged 3×) inside `ContrastNormalisingLocator` → `CoarseToFineLocator.moved` back to the whole picture
- **`locateInFrame`** (`lib/vision/locate_in_frame.dart`)
  - `frameToRgb`: YUV420/BGRA → RGB, rotate upright, cap 1920 px
  - `buildTargetLocator(...).locate`
  - debug: `describeFrame`, `debugFramePng`
- **`CoarseToFineLocator`** (`lib/vision/coarse_to_fine_locator.dart`)
  - rough pass → `retry` at 1200 px if nothing → crop 1.8 × radius at full resolution → close-up pass → `moved` back (public: `locateTargetAt` uses it too)
- **`ContrastNormalisingLocator`**
  - `locate` as-is → if not found, `normaliseContrast` → `locate` again
- **`ColourRingLocator`** (`lib/vision/colour_ring_locator.dart`)
  - `_paletteLabels` (k-means), then candidate centres: `seed` first if set, then `_regionCentresNear(seed)` (`_regionAt` under and around it), then `_candidateCentres` (largest single-colour regions)
  - `_learnColours`: colour A (bull), colour B (next ring)
  - `_fitFrom`: rays → A/B runs (gaps skipped) → boundary points
  - `fitEllipseRansac` per boundary; `_implausible` sanity check; confidence
- **`TargetCalibration`** (`lib/vision/target_calibration.dart`)
  - `moved`, `withMajorHandleAt`, `withMinorHandleAt` (all rings together); `within(x, y, w, h)`: the same rings in a crop's coordinates
- **`CalibrationNotifier`** (`lib/providers.dart`)
  - `start`, `adjust` (ignored when locked), `lock`, `unlock`
- **`TargetMapping`** (`lib/vision/target_mapping.dart`)
  - `toTarget`: ray from the bull centre → `_rayToEdge` per painted edge → interpolate to the ideal radius
- **`ThrowWatcher`** (`lib/game/throw_watcher.dart`): `interval`: frames closer together are skipped (default 60 ms, ~15 a second; Quick draw zero)
  - per frame: `frameToLuma` → `MotionDetector.add`; while still, keep a full-resolution before (`uprightFullRgb`)
  - per episode: `ThrowTracker.onEpisode`; if stuck, the next frame is the after → `findKnifeEntry`; emits `ThrowEvent`
- **`MotionDetector`** (`lib/vision/motion_detector.dart`)
  - `add`: changed share vs the previous frame (noise-adaptive threshold) → watching / motion / settling / **blocked** → `MotionEpisode` (peak, change from before, before/after frames, `impact` / `impactFrame` via `_noteImpact`)
- **`ThrowTracker`** (`lib/game/throw_tracker.dart`)
  - `onEpisode`: `classifyThrow(knownKnives)` → stuck (new knife id) / fell out (known id) / board visit (forget all) / bounce-out / scene changed
- **`classifyThrow`** (`lib/vision/throw_classifier.dart`)
  - board visit: `wasBlocked`, `peakChange` ≥ 10% (`visitPeak`), or `peakArea` ≥ 3% of the region (`visitArea`; 2% until 2026-10-14)
  - `findNewObject`: connected changed shape touching the target; size vs 0.25% of the target area; overlap with known knives
- **`GeometricEntryEstimator`** (`lib/vision/entry_point.dart`)
  - colour-changed shape → steel pixels → principal axis → entry at the end away from `outwardDirection`
- **`GameSession`** (`lib/scoring/game_session.dart`) / **`GameNotifier`** (`lib/providers.dart`)
  - `stuck`, `bounceOut`, `fellOut`, `boardVisited`; rounds of 3; `onEvent` maps entries to scores
- **`TargetModel`** (`lib/scoring/target_model.dart`)
  - `scoreAt(point, bladeHalfWidth)` with a `LineTouchRule`
- **Test data**: `SyntheticTarget` (flat, affine), `SyntheticScene` (3D ray tracer), `PhotoBoardTexture` (reference photo as the board face, knives removed); tools `render_camera_views`, `locate_target`, `printable_target`

## Concepts

| Term | Meaning | Used by |
|---|---|---|
| **Normalised target coordinates** | Position on the target with the centre at 0,0 and the outer edge of ring 1 at radius 1 (v up). Scores are defined here. | `TargetPoint`, `TargetModel`, `TargetMapping`, `SyntheticScene` |
| **Ideal vs painted rings** | Ideal: IKTHOF radii 0.2 / 0.4 / 0.6 / 0.8 / 1.0. Painted: where the paint actually is (reference board 0.219 / 0.395 / 0.620 / 0.8). Scoring maps painted edge k to ideal k. | `TargetMapping`, `render_camera_views` |
| **Line-touch rule** | How a blade touching the line between rings scores: higher (IKTHOF), lower (WATL), or by majority of blade (IATF, backlog). | `TargetModel` |
| **Ellipse fitting** | Finding the ellipse that best passes through a set of points. Here: Halíř–Flusser's stable form of Fitzgibbon's direct least-squares fit. A circle seen at an angle is (nearly) an ellipse. | `fitEllipse`, `ColourRingLocator` |
| **RANSAC** | Fit to many small random samples, keep the fit most points agree with, refit on those. Outvotes bad points (rays spoiled by handles or cuts). | `fitEllipseRansac` |
| **Coarse-to-fine** | Find roughly on a shrunk image, then look closely at a full-resolution crop. Needed because the board is small in the frame. | `CoarseToFineLocator` |
| **Contrast stretch** | Map the darkest/brightest 1% of brightness to black/white, same map on all channels (hue kept). A fallback for dim or flat light. | `normaliseContrast`, `ContrastNormalisingLocator` |
| **Two-colour rings** | The target is any two alternating colours (A = bull, B = next), learned per image rather than fixed. | `ColourRingLocator` |
| **Upright rotation** | Clockwise rotation turning a sideways sensor frame upright: (sensor − device + 360) % 360. | `frameRotation`, `frameToRgb` |
| **Calibration lock** | The fitted rings fixed for the session (the camera doesn't move); taps and later throws are scored against them. | `CalibrationNotifier`, `CalibrationScreen` |
| **Board visit** | Someone at the board (collecting knives), not a throw: they stood there, ≥ 10% of the region changed at once, or one shape ≥ 3% of the region moved (people are 4%+, knives up to 2.2%). Ends the round. | `classifyThrow`, `ThrowTracker`, `GameSession` |
| **Episode** | One stretch of motion in the board's region, from the first change until the board has been still for 0.3 s and looks like the board again. One throw, one bounce, or one visit to the board. | `MotionDetector`, `ThrowTracker` |
| **Reference frame / blocked** | The board as last seen settled. Still frames that differ from it by more than 8% mean something is in front of the board (blocked), not settled. | `MotionDetector` |
| **Noise-adaptive threshold** | A pixel counts as changed when it differs by more than 6 × the sensor noise (learned while still), at least 12 levels. | `MotionDetector` |
| **Known knives** | Shapes of the knives already in the board, so a knife disappearing (falling out) isn't mistaken for a new one. Forgotten when someone collects them. | `ThrowTracker`, `classifyThrow` |
| **Colour vs brightness change** | Shaded steel can match red paint's brightness, so the full-resolution entry search compares colour (largest channel difference); motion detection uses brightness (cheap, enough to see change). | `GeometricEntryEstimator`, `MotionDetector` |
| **Steel vs shadow** | A knife's shadow is new too, but keeps the board's hue; the knife is grey (low saturation). | `GeometricEntryEstimator` |
| **Entry point (how a knife is scored)** | Where the blade goes into the wood. Nigel's rule (2026-10-13): "find the solid shape of the knife; score where the blade goes into the wood; a shadow comes from the knife, on the side away from the light". Not the handle, and not the end of the shadow nearest the bull. | `faceOnEntry`, `GeometricEntryEstimator`, [[story-checkpoint-entry-point]] |
| **Quick draw** | Two throwers, one board each, both in one camera view, throwing together after a countdown. The first knife to stick wins; a bounce-out loses ([[story-checkpoint-quick-draw]]). So far: the Live test clip, played full screen with its sound, the boards chosen by tapping, and each board's impact time and result. | `QuickDrawScreen`, `quickDrawRecording`, `quickDrawCameraProvider`, `QuickDrawTargets`, `QuickDrawWatcher` |
| **Impact (frame)** | When a knife reached the board: the frame, within a motion episode, with the largest moving shape on the target (the board jolts and the knife stops at once). Not the episode's start: seen from behind the thrower, a knife in flight is over the board all the way in. Quick draw times throws by it. | `MotionEpisode.impact` / `impactFrame`, `QuickDrawThrow.impact` |
| **Board crop** | A square of the picture around one board, treated as a camera of its own, so single-board detection can watch one board of several at full detail. | `CroppedCamera`, `TargetCalibration.within`, `QuickDrawWatcher` |
| **Seed (tap) centre** | Where the user says a board's centre is, by tapping it. Tried first as the centre, then snapped to the colour regions under and around it (the bull, or the ring tapped, is centred on the board). Lets the user pick which boards count when more are in the picture. | `ColourRingLocator.seed`, `locateTargetAt` |
| **Ducking** | Turning other apps' audio down while ours plays, rather than stopping it. | `AssetRecordingSound.audioContext` |
| **Outward direction** | Which way "out of the board" points in the picture: from the outer ring's ellipse centre towards the bull's centre (a tilted circle's centre appears shifted towards the far side). The handle lies that way; the entry is the other end. | `outwardDirection`, `GeometricEntryEstimator` |
| **Ray tracing (test renders)** | Colouring each pixel by following a ray from the camera into a 3D scene; gives photo-like test images with exact answers. | `SyntheticScene` |
