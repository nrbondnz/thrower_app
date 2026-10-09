# Glossary: Components, Functions and Concepts

Three kinds of thing (Docs Agent §5): **components** (system elements), the **functions** they perform (parent → child), and **concepts** (terms that mean something on their own and may be used by several components). Names match the code.

## Component → Function Tree

- **`LiveCamera`** (`lib/camera/live_camera.dart`)
  - `open`: back camera, `ResolutionPreset.high`, no audio; plugin errors → `CameraFailure`
  - `frames`: broadcast stream of `CameraFrame`, only while listened to
  - `uprightRotation`: `frameRotation(sensorOrientation, deviceOrientation)`
- **`locateInFrame`** (`lib/vision/locate_in_frame.dart`)
  - `frameToRgb`: YUV420/BGRA → RGB, rotate upright, cap 1920 px
  - `buildTargetLocator(...).locate`
  - debug: `describeFrame`, `debugFramePng`
- **`CoarseToFineLocator`** (`lib/vision/coarse_to_fine_locator.dart`)
  - rough pass → `retry` at 1200 px if nothing → crop 1.8 × radius at full resolution → close-up pass → move back
- **`ContrastNormalisingLocator`**
  - `locate` as-is → if not found, `normaliseContrast` → `locate` again
- **`ColourRingLocator`** (`lib/vision/colour_ring_locator.dart`)
  - `_candidateCentres`: palette (k-means) → largest single-colour regions
  - `_learnColours`: colour A (bull), colour B (next ring)
  - `_fitFrom`: rays → A/B runs (gaps skipped) → boundary points
  - `fitEllipseRansac` per boundary; `_implausible` sanity check; confidence
- **`TargetCalibration`** (`lib/vision/target_calibration.dart`)
  - `moved`, `withMajorHandleAt`, `withMinorHandleAt` (all rings together)
- **`CalibrationNotifier`** (`lib/providers.dart`)
  - `start`, `adjust` (ignored when locked), `lock`, `unlock`
- **`TargetMapping`** (`lib/vision/target_mapping.dart`)
  - `toTarget`: ray from the bull centre → `_rayToEdge` per painted edge → interpolate to the ideal radius
- **`ThrowWatcher`** (`lib/game/throw_watcher.dart`)
  - per frame: `frameToLuma` → `MotionDetector.add`; while still, keep a full-resolution before (`uprightFullRgb`)
  - per episode: `ThrowTracker.onEpisode`; if stuck, the next frame is the after → `findKnifeEntry`; emits `ThrowEvent`
- **`MotionDetector`** (`lib/vision/motion_detector.dart`)
  - `add`: changed share vs the previous frame (noise-adaptive threshold) → watching / motion / settling / **blocked** → `MotionEpisode` (peak, change from before, before/after frames)
- **`ThrowTracker`** (`lib/game/throw_tracker.dart`)
  - `onEpisode`: `classifyThrow(knownKnives)` → stuck (new knife id) / fell out (known id) / board visit (forget all) / bounce-out / scene changed
- **`classifyThrow`** (`lib/vision/throw_classifier.dart`)
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
| **Episode** | One stretch of motion in the board's region, from the first change until the board has been still for 0.3 s and looks like the board again. One throw, one bounce, or one visit to the board. | `MotionDetector`, `ThrowTracker` |
| **Reference frame / blocked** | The board as last seen settled. Still frames that differ from it by more than 8% mean something is in front of the board (blocked), not settled. | `MotionDetector` |
| **Noise-adaptive threshold** | A pixel counts as changed when it differs by more than 6 × the sensor noise (learned while still), at least 12 levels. | `MotionDetector` |
| **Known knives** | Shapes of the knives already in the board, so a knife disappearing (falling out) isn't mistaken for a new one. Forgotten when someone collects them. | `ThrowTracker`, `classifyThrow` |
| **Colour vs brightness change** | Shaded steel can match red paint's brightness, so the full-resolution entry search compares colour (largest channel difference); motion detection uses brightness (cheap, enough to see change). | `GeometricEntryEstimator`, `MotionDetector` |
| **Steel vs shadow** | A knife's shadow is new too, but keeps the board's hue; the knife is grey (low saturation). | `GeometricEntryEstimator` |
| **Outward direction** | Which way "out of the board" points in the picture: from the outer ring's ellipse centre towards the bull's centre (a tilted circle's centre appears shifted towards the far side). The handle lies that way; the entry is the other end. | `outwardDirection`, `GeometricEntryEstimator` |
| **Ray tracing (test renders)** | Colouring each pixel by following a ray from the camera into a 3D scene; gives photo-like test images with exact answers. | `SyntheticScene` |
