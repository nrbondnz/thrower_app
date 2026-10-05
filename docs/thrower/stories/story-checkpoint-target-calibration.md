# Story Checkpoint: Target Calibration

## Story Goal

With the phone on a **static mount** off to the side of the throwing line, find the board's **painted rings** once per session (ignoring the bark edge and old cuts), let the user correct the outline if needed, then **lock** it. From then on, any point in the camera image can be converted to normalised target coordinates and scored by `TargetModel`.

This is the foundation for [[backlog|throw detection]]: that story only has to find *where the blade went in*. This one turns that position into a score.

## Complexity Score

| Factor | Score |
|---|---|
| Layers: camera (still capture), vision (ring finding, mapping), scoring (`TargetModel`), UI (overlay, adjust) | 4 |
| Branching: auto-detect succeeds / fails or needs adjusting → manual | 1 |
| More than 3 acceptance criteria | 1 |
| **Total** | **6 (Large): full Story Agent protocol** |

## Status

**IN PROGRESS (2026-10-05)**: plan approved; D1 = **pure Dart**. Task 1 complete (`f71cedc`). **Task 2 done, waiting at the checkpoint**: Nigel to point the phone at a target.

---

## Decisions Needed

### D1: How to process images

| Option | What it means | Pros | Cons |
|---|---|---|---|
| **A. Pure Dart (recommended)** | Our own colour segmentation and ellipse fitting on frame bytes, behind a `TargetLocator` interface | No native dependency, no app-size cost; tests run on Windows against fixture images; calibration is a **one-off on a single still** (static camera), so speed hardly matters | We write the maths (segmentation, ellipse fit); per-frame work in the throw-detection story may need optimising |
| B. OpenCV (`opencv_dart`) | Native OpenCV: `fitEllipse`, `findHomography`, etc. | Proven algorithms; fast | Adds tens of MB to the app; native build complexity on both platforms; harder to test on Windows |
| C. Trained ML model | Segmentation model (TFLite) | Copes best with messy real boards | Needs labelled training photos we don't have yet |

**Decided (Nigel, 2026-10-05): A.** Recommendation was A, behind the `TargetLocator` interface so B or C can replace it without touching the UI or scoring (the "architectural purity" option: the approach can be swapped). Revisit if real-board photos defeat colour segmentation.

## Technical Notes

- **Seen from an angle, concentric circles aren't concentric ellipses.** Under perspective, the rings' centres shift slightly relative to each other. Plan: start with an **affine** mapping from the outer ellipse (accurate for moderate angles), measure the error against the inner rings, and move to a full **homography** fitted to all five ring boundaries if needed (Task 4 decides, with numbers).
- **Find the paint, not the log.** Segment red against bare wood; the irregular bark edge and old cuts must not affect the fit (robust fitting, e.g. RANSAC over boundary points).
- **Safety:** adjusting the outline happens on the mounted phone, so the UI must say to do it **only when no one is throwing** (Review Agent §7).

## Traceability Matrix (baseline)

| ID | Requirement | Design ref | Implementation | Test | Status |
|---|---|---|---|---|---|
| C1 | Find the 5 painted rings in a still image, ignoring the bark edge and old cuts | Design Decisions → Target Locating | `ColourRingLocator` | `colour_ring_locator_test.dart`: reference photo + 6 synthetic scenes; `isRed`/`isWood` cases; Nigel on device | ✅ Task 1 |
| C2 | Works off-centre (the phone is beside the throwing line) | Design Decisions → Throw Detection | `ColourRingLocator` (ellipses, not circles) | synthetic 40° and 55° (tilted, knives) | ✅ Task 1 (synthetic; real angled photos still needed) |
| C3 | Show the detected outline over the live preview | Design Decisions → Target Locating (camera frame to rings) | `CalibrationScreen`, `RingOverlayPainter`, `locateInFrame`, `frameToRgb`, `LiveCamera.uprightRotation`, `CameraView` | `frame_to_rgb_test.dart` (16), `locate_in_frame_test.dart` (3), `calibration_screen_test.dart` (4) | ✅ Task 2 (Nigel to check on device, both platforms) |
| C4 | The user can adjust the outline and lock it; it stays locked for the session; re-calibrate on request | Design Decisions → Throw Detection §1 | | | ⏳ Task 3 |
| C5 | Map any image point to normalised target coordinates, accurate enough to score | Design Decisions → Vision Pipeline | | fixtures with known points | ⏳ Task 4 |
| C6 | Tell the user to calibrate only when no one is throwing | Review Agent §7 | | widget test | ⏳ Task 3 |

---

## Story Plan (APPROVED 2026-10-05)

### Task 1: Find the rings in a still photo
- **Setup:** fixtures in `test/fixtures/targets/`: `target-example.png`, renders of the printable target at several angles, and **Nigel's photos** (from the mount position, empty and with knives).
- **Work:** `TargetLocator` interface → `ColourRingLocator` (per D1). Segment red against wood, extract ring boundaries, robustly fit an ellipse to each, and check they nest. A debug screen picks a fixture or photo and draws the fitted ellipses.
- **Verify (Nigel):** open the debug screen on the example photo, the printed target and his own photos; the outlines sit on the painted ring edges.

### Task 2: Live outline over the camera preview
- **Setup:** Task 1.
- **Work:** capture a still from `CameraSource`, run the locator in a background isolate, and draw the outline over the preview.
- **Verify (Nigel):** point the mounted phone at the printed target; the outline appears and matches.

### Task 3: Adjust and lock
- **Setup:** Task 2.
- **Work:** drag handles to correct the outline; "Lock target"; the calibration is kept for the session; "Re-calibrate"; on-screen safety note. Review Agent (physical safety).
- **Verify (Nigel):** nudge a deliberately wrong outline into place, lock it, leave the screen and come back; still locked.

### Task 4: Image → target coordinates, and tap-to-score on the live view
- **Setup:** Task 3.
- **Work:** `TargetMapping` (affine first; homography if the measured error says so) converts image points to `TargetPoint`. A debug mode: tap the live preview → `TargetModel` score.
- **Verify (Nigel):** with the phone mounted at an angle, tap each ring on the preview; each tap gives that ring's score, including near the lines.

### Task 5: Traceability review and close
- **Work:** Traceability Agent; docs: System Diagram, Data Flow (frame → score), start the concept glossary (ellipse fitting, homography, RANSAC, normalised target coordinates).
- **Verify (Nigel):** matrix complete; docs describe the pipeline.

---

## Task Records

### Task 1: Find the rings in a still photo — COMPLETE
- **What changed** (unstaged):
  - `pubspec.yaml`: `image: ^4.10.1` (pure Dart decoder; no native code); `assets/debug/` registered.
  - `lib/vision/`:
    - `rgb_image.dart`, `ellipse.dart` (`Point2`, `Ellipse`, `fitEllipse`, `fitEllipseRansac`).
    - `target_locator.dart` (`TargetLocator`, `TargetFound`, `TargetNotFound` with the attempted fit for debugging).
    - `colour_ring_locator.dart`, `synthetic_target.dart`, `decode_image.dart`.
  - `lib/providers.dart`: `ringBoundaryRadiiProvider` (taken from `TargetModel`).
  - `lib/ui/debug_locator_screen.dart`: **Ring finder test** screen (chips: reference photo + 3 synthetic scenes; draws the edge points and fitted ellipses; shows confidence and time). The work runs in a background isolate via `compute`. Home has a "Ring finder test" button.
  - `assets/debug/target-example.jpg` (600 × 800, about 170 KB, in the app bundle; debug use).
  - `tool/locate_target.dart`: `dart run tool/locate_target.dart <photo>` writes `<photo>-located.png` with the fit drawn on it. **Use this on Nigel's photos.**
  - `test/fixtures/targets/target-example.jpg`.
- **Problems found and fixed while building:**
  1. The bull's sprayed edge read too large: edges now go to the midpoint of a majority filter.
  2. Oversprayed wood (226, 152, 125) counted as red, merging the bull with the next ring: the red threshold was raised to saturation ≥ 0.6 and hue < 12°, based on measured paint.
  3. A hand-painted bull isn't in exact IKTHOF proportion: the proportion check was loosened to 35% (see Design Decisions).
  4. A knife handle across the bull broke every ray: classification became three-way, and handles/shadows/slots are now gaps.
  5. The isolate failed to start (closure over widget state, caught by the widget test): switched to `compute` with top-level functions. Added to [[Known Issues]].
  6. A widget test silently tapped an off-screen chip and re-tested the previous sample: it now scrolls the chip into view and asserts that a new search started.
- **Results:**
  - Reference photo: all four painted edges traced; both knives ignored; **confidence 0.85**; about 130 ms on a PC.
  - Synthetic 55° tilted with a knife across the bull: bull edge 44.0 × 25.3 px vs 44 × 25.2 expected.
- **Test Report:**
  - New: `test/vision/ellipse_test.dart` (9), `test/vision/colour_ring_locator_test.dart` (25: `isRed` 9, `isWood` 8, 6 synthetic scenes, no-target, reference photo), `test/ui/debug_locator_screen_test.dart` (1: every synthetic sample found on screen).
  - Result: `flutter test` **70 passed**; `flutter analyze` clean.
- **Safety (Review Agent, light; no permission or platform change):**
  - ✅ The `image` package is pure Dart.
  - ⚠️ The 170 KB debug asset ships in release builds; remove it or gate it before a store build (noted for later).
  - ✅ Nothing leaves the device.
- **Doc Update Log:** Design Decisions: new **Target Locating**, Code Layout row for `lib/vision/`; [[Known Issues]]: isolate closure; [[Common Tasks]]: running `locate_target`.
- **Not done:** device check (Claude's run stalled because the phone was locked), so Nigel checks it.
- **Verify (Nigel):** Home → **Ring finder test**. Each chip should show blue ellipses on the painted edges and "Found". Also note the time shown (it's the phone's real speed). Then, as soon as there are photos of the real board: `dart run tool/locate_target.dart <photo>` (or send them to Claude to add as fixtures).
- **Nigel: "works" (2026-10-05).** Committed `f71cedc`.
- **Checkpoint saved:** 2026-10-05

### Task 2: Live outline over the camera preview — COMPLETE (awaiting Nigel's check)
- **What changed** (unstaged):
  - `lib/camera/camera_frame.dart`: `frameRotation`. `lib/camera/live_camera.dart`: `uprightRotation`.
  - `lib/vision/frame_to_rgb.dart`: BGRA / YUV420 → upright, downscaled `RgbImage`. `lib/vision/locate_in_frame.dart`: `locateInFrame` + `FrameLocateResult`.
  - `lib/ui/camera_screen.dart`: **refactor**. The lifecycle, permission and error handling moved into a reusable `CameraView` (with an `overlayBuilder` drawn as `CameraPreview`'s child); `CameraScreen` now just wraps it, with behaviour unchanged (its 7 tests still pass).
  - `lib/ui/calibration_screen.dart`: **Calibrate target** screen. "Find target" takes the next frame, runs `locateInFrame` in the background, and draws the fitted edges over the preview (blue = found, magenta = rejected attempt) with confidence and time. Home: "Calibrate target" button (top).
- **Found while testing:** whole-number downscaling turned an 800 px frame into 400 px instead of 600 (step 1.33 rounded up to 2), halving the detail. It now uses a fractional step.
- **Test Report:**
  - New: `frame_to_rgb_test.dart` (16: rotation formula ×6, BGRA with row padding, YUV420 pixel stride 2, 4 rotations, downscale, unsupported format, sideways-sensor round trip), `locate_in_frame_test.dart` (3: a synthetic target encoded as a **sideways** BGRA and YUV frame is found upright in the right place; unsupported format), `calibration_screen_test.dart` (4: status messages).
  - Result: **92 passed**; analyze clean.
  - Not unit-tested: the live screen with a real camera (needs a device).
- **Safety (Review Agent, light):** no new permissions or plugins. The camera is only read on "Find target"; frames stay in memory. ✅
- **Risks to check on the device:**
  1. **iOS frame orientation.** If the outline is rotated or mirrored relative to the preview on the iPhone, the rotation formula needs an iOS-specific case.
  2. **Preview vs stream field of view.** If the outline is the right shape but offset or scaled, the two streams crop differently.
  3. Speed on the phone (the time is shown on screen).
- **Verify (Nigel):** print the A4 target (or use the real board), mount or hold the phone **to one side**, Home → **Calibrate target** → **Find target**: blue rings should sit on the painted edges in the live preview, on **Android and iPhone**. Try straight on, from an angle, and in landscape.
- **Checkpoint saved:** 2026-10-05

---

## Plan Changes Log

- **2026-10-05:** Story created (draft plan).
- **2026-10-05:** Plan approved; D1 = pure Dart. Task 1 executed.
- **2026-10-05:** Task 1 verified and committed (`f71cedc`). Task 2 executed.

## Notes
- **Best inputs:** the printed target (`docs/thrower/reference/printable/`) for Tasks 1–2; Nigel's real board and photos from the mount position as soon as possible, because that's what matters.
