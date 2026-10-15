# Data Flow: Camera Frame → Calibration → Score

How one frame becomes a calibration, and how a throw becomes a score. Built by [[story-checkpoint-target-calibration]] and [[story-checkpoint-throw-detection]]; recordings by [[story-checkpoint-live-test]]. Drawn in the same box style as the [[System Diagram]] (2026-10-14).

## Where Frames Come From

Every screen and the throw detection use a `TargetCamera`. Both kinds deliver the same `CameraFrame`, so nothing downstream knows which one it has.

```
┌─────────────────────────────────────────────────────────────────────┐
│                      FRAME SOURCES (TargetCamera)                   │
│                                                                     │
│   ┌──────────────────────────────┐  ┌────────────────────────────┐  │
│   │ LiveCamera (camera plugin)   │  │ RecordedCamera (Live test) │  │
│   │ back camera, 1280×720        │  │ FramePack: JPEG frames     │  │
│   │ ResolutionPreset.high        │  │ native codec → BGRA        │  │
│   │ Android: YUV420, sideways    │  │ already upright            │  │
│   │ iOS: BGRA                    │  │ T1/T2: 322 px, 15 fps      │  │
│   │ uprightRotation: from sensor │  │ Quick draw: 720×1280,      │  │
│   │ minChange: 12 (+ noise)      │  │  60 fps, + sound           │  │
│   │                              │  │ minChange: 20 (JPEG noise) │  │
│   └──────────────┬───────────────┘  └─────────────┬──────────────┘  │
│                  │                                │                 │
│                  └───────────────┬────────────────┘                 │
│                                  ▼                                  │
│              CameraFrame (pixels + planes + timestamp)              │
│               via frames(): a broadcast stream                      │
└─────────────────────────────────────────────────────────────────────┘
```

Quick draw's analysis uses a third `TargetCamera`, `RecordingAnalysisFeed`: every frame of a `RecordedCamera`'s clip, in order, stamped with its place in the clip, while the picture may skip frames (see Quick Draw: a Throw per Board, and the Winner, below).

## A Frame → a Calibration

```
┌─────────────────────────────────────────────────────────────────────┐
│                     CALIBRATION (CalibrationScreen)                 │
│                                                                     │
│   User taps "Find target"                                           │
│          │                                                          │
│          ▼                                                          │
│   ┌─────────────┐   frames().first                                  │
│   │TargetCamera │──────────────────┐                                │
│   └─────────────┘                  ▼                                │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │ background isolate: locateInFrame(frame, rotation, radii)    │  │
│   │  1. frameToRgb: convert + rotate upright, full resolution    │  │
│   │  2. CoarseToFineLocator: rough pass at 600 px (retry 1200)   │  │
│   │     → crop around the board → close-up pass, full res        │  │
│   │  3. each pass: as-is, then ContrastNormalisingLocator        │  │
│   │  4. ColourRingLocator: learn 2 colours → rays → RANSAC       │  │
│   │     ellipses (fitEllipse), one per painted ring edge         │  │
│   └──────────────────────────────┬───────────────────────────────┘  │
│                                  │ FrameLocateResult                │
│                                  │ (found, or the rejected attempt) │
│                                  ▼                                  │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │ calibrationProvider                                          │  │
│   │  start(TargetCalibration) ─▶ adjust (user drags rings /      │  │
│   │  handles, optional) ─▶ lock()        kept for the session    │  │
│   └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

## A Point → a Score

The same mapping scores a tap on the locked target and a knife's entry point.

```
┌─────────────────────────────────────────────────────────────────────┐
│                     MAPPING (TargetMapping → TargetModel)           │
│                                                                     │
│   image pixel (a tap, or EntryEstimate.point)                       │
│          │                                                          │
│          ▼                                                          │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │ TargetMapping(calibration).toTarget(pixel)                   │  │
│   │  along the ray from the bull centre, interpolate between     │  │
│   │  the painted edges → ideal radius (painted edge k ↦ ideal k) │  │
│   └──────────────────────────────┬───────────────────────────────┘  │
│                                  │ TargetPoint (normalised)         │
│                                  ▼                                  │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │ TargetModel.scoreAt(point): 5 (bull) … 1 (outer ring), 0     │  │
│   │ outside; LineTouchRule decides a point exactly on a line     │  │
│   └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

## A Throw → a Score (Play)

```
┌─────────────────────────────────────────────────────────────────────┐
│                     THROW DETECTION (ThrowWatcher)                  │
│                                                                     │
│   CameraFrame stream                                                │
│          │  at most every 60 ms (ThrowWatcher.interval)             │
│          ▼                                                          │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │ UI thread: frameToLuma (~320 px, upright)                    │  │
│   │  → MotionDetector, inside the board's WatchRegion:           │  │
│   │    watching → motion → settling → settled                    │  │
│   │ while watching: keep a full-res BEFORE picture, refreshed    │  │
│   │  every 1 s (compute: uprightFullRgb)                         │  │
│   └──────────────────────────────┬───────────────────────────────┘  │
│                                  │ MotionEpisode (settled)          │
│                                  ▼                                  │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │ ThrowTracker.onEpisode → classifyThrow (knows the knives     │  │
│   │ already in the board)                                        │  │
│   └───────┬──────────────────────┬──────────────────────┬────────┘  │
│           │ stuck, board         │ stuck, side-on       │ other     │
│           │ seen face on         │ (isFaceOn false)     │           │
│           ▼                      ▼                      │           │
│   ┌───────────────┐  ┌──────────────────────────────┐   │           │
│   │ faceOnEntry   │  │ next frame → full-res AFTER  │   │           │
│   │ (knife shape, │  │ (compute) → findKnifeEntry:  │   │           │
│   │ nearest the   │  │ GeometricEntryEstimator      │   │           │
│   │ bull)         │  │ (before, after) (compute)    │   │           │
│   └───────┬───────┘  └──────────────┬───────────────┘   │           │
│           └───────────┬─────────────┘                   │           │
│                       │ EntryEstimate                   │ bounce-out│
│                       ▼                                 │ fell out  │
│   ThrowEvent(stuck, entry, knifeId)                     │ board     │
│                       │                                 │ visit,    │
│                       │      ThrowEvent(kind, knifeId) ◀┘ scene     │
│                       ▼                ▼                  changed   │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │ GameNotifier.onEvent → GameSession                           │  │
│   │  stuck: entry → TargetMapping → TargetModel → score          │  │
│   │  bounce-out: 0 · fell out: that throw → 0                    │  │
│   │  board visit: closes the round · 9 rounds × 3 throws         │  │
│   └──────────────────────────────┬───────────────────────────────┘  │
│                                  ▼                                  │
│   PlayScreen: score circles where knives went in (RoundMarks),      │
│   "0" beside the board for bounce-outs, round and game totals       │
└─────────────────────────────────────────────────────────────────────┘
```

## Quick Draw: Choosing the Boards

On Quick draw the user picks each player's board by tapping its centre (Task 2 of [[story-checkpoint-quick-draw]]; why, and the measurements, in [[Design Decisions]] → Quick Draw: Choosing the Boards by Tapping). Both Quick draw screens do it the same way: the recording's `QuickDrawScreen` and the live camera's `LiveQuickDrawScreen` share `BoardChoosing` and `BoardsOverlay` (`lib/ui/quick_draw_boards.dart`). Taps are fractions of the picture, turned into pixels only once the frame is upright (Task 1 of [[story-checkpoint-live-quick-draw]]).

```
┌─────────────────────────────────────────────────────────────────────┐
│       QUICK DRAW: CHOOSING THE BOARDS (both Quick draw screens)     │
│                                                                     │
│   User taps the centre of Player 1's board, then Player 2's         │
│          │  BoardsOverlay: screen point ÷ the picture's size on     │
│          │  screen = a fraction, 0–1 each way (not pixels)          │
│          ▼                                                          │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │ BoardChoosing.findBoardAt → tapLocatorProvider               │  │
│   │ → locateAtTap: the camera's next frame                       │  │
│   │ background isolate (compute): locateTappedInFrame            │  │
│   │  1. frameToRgb: upright RGB, at most 1920 px (a live         │  │
│   │     Android frame arrives sideways and is turned first)      │  │
│   │  2. tap fraction × the upright picture's size = pixels       │  │
│   │  3. locateTargetAt: square window around the tap,            │  │
│   │     0.45 × the picture's shorter side, enlarged 3×           │  │
│   │  4. ColourRingLocator: centres tried = the tap (seed),       │  │
│   │     then the colour regions under and around it, then        │  │
│   │     the largest regions → rings (as in Calibration)          │  │
│   │  5. CoarseToFineLocator.moved: back to picture coordinates   │  │
│   └──────────────────────────────┬───────────────────────────────┘  │
│                                  │ TargetFound / TargetNotFound     │
│                                  ▼ boardAt → TargetCalibration?     │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │ found: quickDrawTargetsProvider.add (next player's board)    │  │
│   │ none: "No board found there."; tap again                     │  │
│   │ after two: Lock boards → lock()   ·   Start again → clear()  │  │
│   │ (the recording also rewinds to its first frame)              │  │
│   └──────────────────────────────────────────────────────────────┘  │
│   BoardsPainter: each board's rings, scaled from its own image      │
│   size, and player number (blue while choosing, green once          │
│   locked)                                                           │
└─────────────────────────────────────────────────────────────────────┘
```

## Quick Draw: a Throw per Board, and the Winner

Once the boards are locked, Play watches each board on its own crop with the single-board throw detection, at every frame of the clip, then judges the race (Tasks 3 and 4 of [[story-checkpoint-quick-draw]]). The watchers don't look at the picture's frames: a phone that can't keep up skips some of those. They get every frame, in order, from `RecordingAnalysisFeed`, so the result can come a little after the picture. Why, and the measurements, in [[Design Decisions]] → Quick Draw: Timing and Scoring Each Board, Quick Draw: Analysing Every Frame, Reporting Late, and Quick Draw: Go, False Starts and the Winner.

```
┌─────────────────────────────────────────────────────────────────────┐
│           QUICK DRAW: A THROW PER BOARD, AND THE WINNER             │
│                                                                     │
│   Play with the boards locked: RecordedCamera (60 fps clip)         │
│          │  the picture and sound: their own pace, may skip         │
│          ▼                                                          │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │ RecordingAnalysisFeed: its own copy of EVERY frame, decoded  │  │
│   │ in order, never ahead of the picture (may finish late);      │  │
│   │ timestamp = timeOf(index) = frame number ÷ 60 (clip time);   │  │
│   │ starts again from frame 0 when playback restarts             │  │
│   └──────────────────────────────┬───────────────────────────────┘  │
│                                  │ every frame, in order            │
│                                  ▼                                  │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │ per board, a CroppedCamera: a square 4 × the board's radius  │  │
│   │ around it, frames as views into the same bytes (no copy);    │  │
│   │ TargetCalibration.within: the rings in crop coordinates      │  │
│   └──────────────────────────────┬───────────────────────────────┘  │
│                                  │ one crop per player              │
│                                  ▼                                  │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │ ThrowWatcher per crop, interval zero: every frame            │  │
│   │  - MotionDetector: episode, and its impact = the frame with  │  │
│   │    the largest moving shape on the target                    │  │
│   │  - classifyThrow (visitArea 3%): stuck / bounce-out          │  │
│   │  - stuck: findKnifeEntry → TargetMapping → scoreAt           │  │
│   └──────────────────────────────┬───────────────────────────────┘  │
│                                  │ ThrowEvent                       │
│                                  ▼                                  │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │ QuickDrawWatcher.throws: each player's first throw only,     │  │
│   │ QuickDrawThrow(impact, stuck, score); later ones ignored     │  │
│   └──────────────────────────────┬───────────────────────────────┘  │
│                                  │ throws + Recording.go (2.8 s)    │
│                                  ▼                                  │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │ judgeQuickDraw(throws, go) → QuickDrawVerdict                │  │
│   │  - per player: none / falseStart (impact before go) /        │  │
│   │    bounced / stuck; afterGo = impact − go; score             │  │
│   │  - winner: the first to stick; same frame = draw;            │  │
│   │    nobody stuck = no winner                                  │  │
│   └──────────────────────────────────────────────────────────────┘  │
│   BoardsPainter: boardLines → judgedText under each board:          │
│   "0.82 s · 5", "0.85 s · bounced", "false start"                   │
│   Bottom line: "Watching…" / "Analysing… 0.4 s behind the           │
│   picture." → verdictText: "Player 2 wins: stuck 5, 0.82 s after    │
│   go. Player 1 bounced out."                                        │
│   GO! flashes 0.7 s at go (from the picture's position)             │
└─────────────────────────────────────────────────────────────────────┘
```

## Coordinate Spaces

| Space | Where | Notes |
|---|---|---|
| Camera frame | `CameraFrame` | Live: sensor orientation (usually sideways), 1280 × 720 at `ResolutionPreset.high`. Recording: already upright, the pack's size (322 × 322, or 720 × 1280 for Quick draw) |
| Upright image | `RgbImage` from `frameToRgb` | Rotated by the camera's `uprightRotation` (0 for a recording); calibration ellipses live here |
| Tap (Quick draw) | `BoardsOverlay` → `TapLocator` | A **fraction** of the upright picture, 0–1 each way (since 2026-10-15). `locateTappedInFrame` multiplies it by the upright image's size after `frameToRgb`, so a sideways live frame and an upright recording are treated alike |
| Board crop (Quick draw) | `CroppedCamera` frames | A square of the upright picture around one board; `TargetCalibration.within` moves the rings into it (subtract the crop's top-left corner) |
| Preview widget | `CalibrationEditor` | Upright image × (preview width ÷ image width); drawn as `CameraPreview`'s (or `RecordedPreview`'s) child so it lines up |
| Brightness frame | `LumaImage` from `frameToLuma` | Upright, ~320 px long side (180 × 320 portrait from a 1280 × 720 stream); motion detection and stuck/bounce classification; `WatchRegion` is in fractions so it's size-independent |
| Target | `TargetPoint` | Normalised: centre 0,0, outer edge of ring 1 at radius 1, v up; **ideal** ring radii 0.2 … 1.0 |
