# System Diagram

Thrower App runs entirely on the phone (no backend yet; see [[Design Decisions]] → User Accounts Required). The layers each depend only on the ones below them. The UI reaches every layer through Riverpod providers (`lib/providers.dart`), so tests can swap any layer for a fake. Drawn in the same box style as WhereWillWeVisit's System Diagram (2026-10-14).

```
┌─────────────────────────────────────────────────────────────────────┐
│                       PHONE (iOS / Android)                         │
│       on a static mount, out of the line of throw, facing board     │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                        UI  (lib/ui)                           │  │
│  │  HomeScreen ─┬─ InstructionsScreen                            │  │
│  │              ├─ PlayScreen ── CameraView · RoundMarks         │  │
│  │              ├─ CalibrationScreen ── CalibrationEditor        │  │
│  │              ├─ LiveTestScreen ─┬─ CalibrationScreen, Play    │  │
│  │              │                  └─ QuickDrawScreen            │  │
│  │              │                       ├─ RecordedPreview       │  │
│  │              │                       └─ BoardsPainter         │  │
│  │              └─ DebugTargetScreen                             │  │
│  └───────────────────────────────┬───────────────────────────────┘  │
│                                  │ ref.watch / ref.read             │
│                                  ▼                                  │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │               WIRING  (lib/providers.dart)                    │  │
│  │  cameraProvider ◀── recordingChoiceProvider                   │  │
│  │  quickDrawCameraProvider        calibrationProvider           │  │
│  │  gameProvider (GameNotifier)    targetModelProvider           │  │
│  │  ringBoundaryRadiiProvider      authServiceProvider           │  │
│  │  quickDrawTargetsProvider       tapLocatorProvider            │  │
│  └──────┬──────────────────┬──────────────────┬──────────┬───────┘  │
│         │                  │                  │          │          │
│         ▼                  ▼                  ▼          ▼          │
│  ┌─────────────┐  ┌─────────────────┐  ┌────────────┐ ┌──────────┐  │
│  │   CAMERA    │  │      GAME       │  │  SCORING   │ │   AUTH   │  │
│  │ lib/camera  │  │    lib/game     │  │lib/scoring │ │ lib/auth │  │
│  │             │  │                 │  │ pure Dart  │ │          │  │
│  │TargetCamera │  │ ThrowWatcher    │  │            │ │AuthServ- │  │
│  │ ├LiveCamera │─▶│  ├MotionDetector│  │TargetModel │ │ice:      │  │
│  │ ├Recorded-  │  │  ├ThrowTracker  │─▶│ scoreAt    │ │interface │  │
│  │ │ Camera    │  │  └classifyThrow │  │GameSession │ │only, no  │  │
│  │ │ ├FramePack│  │ findTarget      │  │ rounds of 3│ │provider  │  │
│  │ │ └Recording│  │ QuickDrawTargets│  │ 9 rounds   │ │yet       │  │
│  │ │  Sound    │  │ QuickDrawWatcher│  │            │ │          │  │
│  │ ├Recording- │  │  └ThrowWatcher×2│  │            │ │          │  │
│  │ │ Analysis- │  │ judgeQuickDraw  │  │            │ │          │  │
│  │ │ Feed      │  │  go, false start│  │            │ │          │  │
│  │ └Cropped-   │  │  → winner       │  │            │ │          │  │
│  │  Camera     │  └────────┬────────┘  └────────────┘ └──────────┘  │
│  │CameraFrame  │           │                  ▲                     │
│  └──────┬──────┘           ▼                  │                     │
│         │       ┌─────────────────────────────┴───────────────────┐ │
│         │       │            VISION  (lib/vision)  pure Dart      │ │
│         │       │  frameToRgb · frameToLuma        (conversion)   │ │
│         └──────▶│  locateInFrame ─▶ CoarseToFineLocator           │ │
│     CameraFrame │     ─▶ ContrastNormalisingLocator               │ │
│     (data only) │     ─▶ ColourRingLocator ─▶ fitEllipse (rings)  │ │
│                 │  locateTappedInFrame ─▶ locateTargetAt          │ │
│                 │    (Quick draw taps) ─▶ ColourRingLocator.seed  │ │
│                 │  TargetCalibration ─▶ TargetMapping ─▶ point    │ │
│                 │  findNewObject · faceOnEntry ·                  │ │
│                 │    GeometricEntryEstimator          (the knife) │ │
│                 └─────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌───────────────────────── NATIVE CODE ──────────────────────────┐ │
│  │ camera (LiveCamera: back camera, image stream, no audio)       │ │
│  │ audioplayers (RecordingSound: Live test clip sound, play only) │ │
│  │ Flutter engine image codec (decodeFrameNatively), not a plugin │ │
│  └────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
          │
          ▼   (deferred: no network calls today)
┌─────────────────────────────────────┐
│   Backend + accounts: not chosen    │
│   (backlog #4)                      │
└─────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                     CALIBRATION FLOW (once per session)             │
│                                                                     │
│   User taps "Find target"                                           │
│          │                                                          │
│          ▼                                                          │
│   ┌─────────────┐  frame   ┌──────────────────────────────────────┐ │
│   │TargetCamera │─────────▶│  background isolate (compute)        │ │
│   │  .frames()  │          │  locateInFrame: upright RGB, coarse  │ │
│   └─────────────┘          │  pass, close-up pass, ring ellipses  │ │
│                            └──────────────────┬───────────────────┘ │
│                                               ▼                     │
│                     ┌───────────────────────────────────────────┐   │
│                     │ calibrationProvider: start → adjust (drag │   │
│                     │ rings) → lock.  Kept for the session.     │   │
│                     └───────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                     PLAY FLOW (a throw → a score)                   │
│                                                                     │
│   TargetCamera stream (live ~15 fps, or a recording)                │
│          │                                                          │
│          ▼                                                          │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │ ThrowWatcher (UI thread, every 60 ms; Quick draw: all)       │  │
│   │  - MotionDetector on ~320 px luma inside the board region:   │  │
│   │    watching → motion → settling → settled                    │  │
│   │  - full-resolution before/after copies (background isolate)  │  │
│   │  - classifyThrow: stuck / bounce-out / fell out / visit      │  │
│   │  - findKnifeEntry → faceOnEntry or GeometricEntryEstimator   │  │
│   └──────────────────────────────┬───────────────────────────────┘  │
│                                  │ ThrowEvent                       │
│                                  ▼                                  │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │ GameNotifier: TargetMapping → TargetModel.scoreAt → 5…0      │  │
│   │ GameSession: 9 rounds × 3 throws; a visit closes the round   │  │
│   └──────────────────────────────┬───────────────────────────────┘  │
│                                  ▼                                  │
│   PlayScreen: score marks on the board (RoundMarks), totals         │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                  LIVE TEST + QUICK DRAW (recordings)                │
│                                                                     │
│   assets/live/*.tfrm (JPEG frames) + quickdraw.m4a (sound)          │
│          │                                                          │
│          ▼                                                          │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │ RecordedCamera: a TargetCamera that plays a FramePack in     │  │
│   │ real time; paused on frame 0 until restart(); decodes with   │  │
│   │ the native codec, skipping frames if it falls behind;        │  │
│   │ RecordingSound starts/stops with it                          │  │
│   └───────────────┬───────────────────────────────┬──────────────┘  │
│                   │                               │                 │
│                   ▼                               ▼                 │
│   ┌───────────────────────────────┐ ┌───────────────────────────┐   │
│   │ Target 1 / Target 2           │ │ Quick draw                │   │
│   │ 322 px crops, 15 fps          │ │ full frame 720×1280,      │   │
│   │ via cameraProvider →          │ │ 60 fps, with sound        │   │
│   │ same Calibration + Play flow  │ │ quickDrawCameraProvider → │   │
│   │ answer key: truth.json        │ │ QuickDrawScreen           │   │
│   │                               │ │ tap boards 1, 2 → lock    │   │
│   │                               │ │ Play: GO! at 2.8 s;       │   │
│   │                               │ │ RecordingAnalysisFeed     │   │
│   │                               │ │ (every frame, in order) → │   │
│   │                               │ │ QuickDrawWatcher →        │   │
│   │                               │ │ judgeQuickDraw: time      │   │
│   │                               │ │ after go · score, winner  │   │
│   │                               │ │ answer key: quickdraw.json│   │
│   └───────────────────────────────┘ └───────────────────────────┘   │
│                                                                     │
│   Quick draw: boards chosen by tapping (Task 2); impact time and    │
│   result under each board (Task 3); every frame analysed, times     │
│   after go, false start and winner (Task 4). Still to come:         │
│   docs, traceability, in-app instructions (Task 5)                  │
└─────────────────────────────────────────────────────────────────────┘
```

**Rules:**
- `lib/vision` and `lib/scoring` have **no Flutter imports**. They run in background isolates and in tests on a PC.
- Vision depends on the camera layer's **data** types (`CameraFrame`) only, never on a plugin.
- Plugins stay in the camera layer, behind interfaces (`TargetCamera`, `RecordingSound`), so tests feed recorded frames and fake sound.
- Heavy work (frame conversion, ring finding, the entry search) runs off the UI thread via `compute`, using top-level functions and plain data. See [[Known Issues]] → Isolate Fails.

See [[Data Flow]] for one frame's path to a score, and [[Glossary]] for the component → function tree and terms.
