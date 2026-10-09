# Data Flow: Camera Frame → Calibration → Score

As built by the target calibration story ([[story-checkpoint-target-calibration]]). Throw detection (next story) will feed the same mapping with a blade's entry point instead of a tap.

```mermaid
sequenceDiagram
  actor User
  participant Screen as CalibrationScreen
  participant Cam as LiveCamera
  participant Iso as background isolate (compute)
  participant State as calibrationProvider
  participant Map as TargetMapping
  participant Score as TargetModel

  User->>Screen: Find target
  Screen->>Cam: frames().first
  Cam-->>Screen: CameraFrame (1280×720 YUV420 / BGRA)
  Screen->>Iso: locateInFrame(frame, uprightRotation, ring radii)
  Note over Iso: frameToRgb: convert + rotate upright, full resolution<br/>CoarseToFine: rough pass (600 px, retry 1200 px if nothing)<br/>→ crop around the board at full resolution → close-up pass<br/>each pass: as-is, then contrast-stretched if not found<br/>ColourRingLocator: learn 2 colours → rays → RANSAC ellipses
  Iso-->>Screen: FrameLocateResult (found, or rejected attempt)
  Screen->>State: start(TargetCalibration)
  User->>Screen: drag rings / handles (optional)
  Screen->>State: adjust(...)
  User->>Screen: Lock target
  Screen->>State: lock()
  User->>Screen: tap the picture
  Screen->>Map: toTarget(tap pixel)
  Note over Map: along the ray from the bull centre,<br/>interpolate between the painted edges<br/>→ ideal radius (painted edge k ↦ ideal k)
  Map-->>Screen: TargetPoint
  Screen->>Score: scoreAt(point)
  Score-->>Screen: 5…0
```

## A Throw → a Score (Play)

As built by [[story-checkpoint-throw-detection]].

```mermaid
sequenceDiagram
  participant Cam as LiveCamera (stream)
  participant W as ThrowWatcher
  participant D as MotionDetector
  participant T as ThrowTracker
  participant Iso as background isolate
  participant G as GameNotifier → GameSession

  loop every frame (processed at most every 60 ms)
    Cam->>W: CameraFrame
    W->>D: frameToLuma (~320 px, upright)
    Note over W: while still: keep a full-res before picture (every 1 s, via compute)
  end
  D-->>W: MotionEpisode (settled, and the board looks like the board again)
  W->>T: onEpisode → classifyThrow(known knives)
  alt stuck
    W->>Iso: next frame → full-res after picture, then GeometricEntryEstimator(before, after)
    Iso-->>W: EntryEstimate (blade entry pixel)
    W->>G: ThrowEvent(stuck, entry, knifeId) → TargetMapping → TargetModel → score
  else bounce-out / fell out / board visit / scene changed
    W->>G: ThrowEvent(kind, knifeId)
  end
  Note over G: rounds of 3, fell out → that throw 0, board visit closes the round
```

## Coordinate Spaces

| Space | Where | Notes |
|---|---|---|
| Camera frame | `CameraFrame` | Sensor orientation (usually sideways), 1280 × 720 at `ResolutionPreset.high` |
| Upright image | `RgbImage` from `frameToRgb` | Rotated by `LiveCamera.uprightRotation`; calibration ellipses live here |
| Preview widget | `CalibrationEditor` | Upright image × (preview width ÷ image width); drawn as `CameraPreview`'s child so it lines up |
| Brightness frame | `LumaImage` from `frameToLuma` | Upright, ~320 px long side (180 × 320 portrait from a 1280 × 720 stream); motion detection and stuck/bounce classification; `WatchRegion` is in fractions so it's size-independent |
| Target | `TargetPoint` | Normalised: centre 0,0, outer edge of ring 1 at radius 1, v up; **ideal** ring radii 0.2 … 1.0 |
