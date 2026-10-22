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
│   │ Quick draw: asks for 60 fps  │  │ minChange: 20 (JPEG noise) │  │
│   └──────────────┬───────────────┘  └─────────────┬──────────────┘  │
│                  │                                │                 │
│                  └───────────────┬────────────────┘                 │
│                                  ▼                                  │
│              CameraFrame (pixels + planes + timestamp)              │
│               via frames(): a broadcast stream                      │
└─────────────────────────────────────────────────────────────────────┘
```

Quick draw's analysis uses a third `TargetCamera`, `RecordingAnalysisFeed`: every frame of a `RecordedCamera`'s clip, in order, stamped with its place in the clip, while the picture may skip frames (see Quick Draw: a Throw per Board, and the Winner, below). The live Quick draw puts each board's crop of the `LiveCamera` through a `QueuedCamera` instead: every frame, in order, stamped when it arrived (see Quick Draw (Live): Every Frame, Cropped and Queued, below).

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

**Tap the board** (2026-10-21, [[story-checkpoint-gapped-rings]]; requirement [[Board Finding]]): when Find target can't find the rings or finds the wrong board, the user taps **Tap the board**, then the board's middle in the picture.
1. `CalibrationScreen._findAt`: the camera's next frame, at the **current zoom** (no zooming: it would move the board from under the tap).
2. Background isolate: `locateTappedInFrame` → `locateTargetAt` (a window round the tap, `ColourRingLocator` with the tap as its seed). If the usual search finds nothing plausible there, step 6 runs: ring alignment round the tap (`_alignedStarts`) → the edge reading with the size fixed.
3. `calibrationFrom` → `calibrationProvider.start`, then adjust and lock as above.

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
│   │ GameNotifier.onEvent(board) → Match → a GameSession each     │  │
│   │  stuck: entry → TargetMapping → TargetModel → score          │  │
│   │  bounce-out: 0 · fell out: that throw → 0                    │  │
│   │  board visit: closes the round · 3, 5 or 9 rounds × 3 throws │  │
│   │  1 or 2 players: board's own, or whoever's turn (PlayMode)   │  │
│   └──────────────────────────────┬───────────────────────────────┘  │
│                                  ▼                                  │
│   PlayScreen: score circles where knives went in (RoundMarks),      │
│   "0" beside the board for bounce-outs, round and game totals       │
│                                                                     │
│   When the match is over (GameNotifier._keep, once per game):       │
│     GameRecord.fromMatch(at: clockProvider, recording: Live test    │
│     name) → gameHistoryProvider.add → game_history.json (.tmp, then │
│     replace). A knife falling out after the end re-saves the same   │
│     record. A failed save → historySaveErrorProvider → a snack bar  │
│     on Play; play goes on.                                          │
│   Finish game (asks first): Match.finish → over now, a part-round   │
│     counted; two players judged on equal rounds → kept as above.    │
│   Home → History: HistoryScreen → load (newest first) → a game:     │
│     GameRecordScreen (rounds, totals, Delete); Clear history asks.  │
│   Tap a score (ScoreCorrections): watching paused → 0–5 popup →     │
│     GameNotifier.setScore / addThrow (empty slot; 0 = a miss) →     │
│     marks read the Match → resume: MotionDetector.restart; 0.5 s    │
│     later cameraShift vs the picture before ≥ 2 px → "The phone     │
│     may have moved…". A game over is kept again with the change.    │
└─────────────────────────────────────────────────────────────────────┘
```

## Quick Draw: Choosing the Boards

On Quick draw the user picks each player's board by tapping its centre (Task 2 of [[story-checkpoint-quick-draw]]; why, and the measurements, in [[Design Decisions]] → Quick Draw: Choosing the Boards by Tapping). Both Quick draw screens do it the same way: the recording's `QuickDrawScreen` and the live camera's `LiveQuickDrawScreen` share `BoardChoosing` and `BoardsOverlay` (`lib/ui/quick_draw_boards.dart`). Taps are fractions of the picture, turned into pixels only once the frame is upright (Task 1 of [[story-checkpoint-live-quick-draw]]). Two-target Play chooses its boards the same way. Since 2026-10-19 each outline can be dragged into place once both are found, and **Adjust boards** unlocks them later ([[story-checkpoint-adjust-boards]]; [[Design Decisions]] → Adjust Each Board).

```
┌─────────────────────────────────────────────────────────────────────┐
│      CHOOSING TWO BOARDS (Quick draw screens, two-target Play)      │
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
│   │ after two: Lock → lock() · Choose boards again → clear()     │  │
│   │ (the recording also rewinds to its first frame)              │  │
│   │ two found, not locked: BoardsOverlay(onAdjust:) →            │  │
│   │   BoardsEditor: drag → grabAt on each board → dragged →      │  │
│   │   replace(index, board) ("only when no one is throwing")     │  │
│   │ locked: Adjust boards → unlock() (both boards kept) →        │  │
│   │   drag → Lock again (two-target Play: watching stopped,      │  │
│   │   marks cleared, scores kept; locking watches afresh)        │  │
│   └──────────────────────────────────────────────────────────────┘  │
│   BoardsPainter: each board's rings, scaled from its own image      │
│   size, and player number (blue while choosing, green once          │
│   locked; handles: each board's two handles while adjustable)       │
└─────────────────────────────────────────────────────────────────────┘
```

**Or draw round the boards** (Quick draw only, 2026-10-21, [[story-checkpoint-quick-draw-areas]]; why in [[Design Decisions]] → Quick Draw: Draw Round the Boards): a finger drawn round each board becomes the board, timed only: an oval, or four corners if the loop has them ([[story-checkpoint-board-outlines]], 2026-10-21; [[Design Decisions]] → Quick Draw: Round or Four-Cornered Boards). The rest of the flow (dragging, Lock, the watchers, the judge) is unchanged; a drawn board's throws carry no score, so `judgedText` shows only the time and a same-frame finish is a draw.

```
┌─────────────────────────────────────────────────────────────────────┐
│           QUICK DRAW: DRAW ROUND THE BOARDS (2026-10-21)            │
│                                                                     │
│   Draw round the boards (boardsModeButton → boardsDrawnProvider:    │
│   true, kept for the session; Quick draw screens only)              │
│          │  LoopDrawer: the finger's path, drawn as it moves;       │
│          │  on lift, the loop as fractions of the picture           │
│          ▼                                                          │
│   BoardChoosing.addDrawnBoard(camera, loop)                         │
│     1. pictureSizerProvider → uprightPictureSize: the camera's next │
│        frame's upright size, at most 1920 px (as tapped boards)     │
│     2. loop × picture size = upright pixels                         │
│     3. areaBoard: the loop cut at the picture's edge →              │
│        fitEllipse(loop) → TargetCalibration (outer = the fit;       │
│        rings = the fit × 0.2 … 0.8, never scored)                   │
│        null: < 8 points, smaller radius < 3% of the shorter side,   │
│        larger > the shorter side, minor ÷ major < 0.35              │
│     4. boardOutline (2026-10-21): convexHull → the 4 hull points    │
│        enclosing the most area; kept as `outline` when the loop's   │
│        mean miss from them + 0.01 < its miss from the oval;         │
│        else round (outline null). Corners stay where drawn          │
│          │                                                          │
│          ▼                                                          │
│   found: quickDrawTargetsProvider.add(board, area: true) → areas    │
│   null: "That loop is too small or too flat for a board."           │
│   then as tapped boards: drag, Lock, Adjust boards (areas kept)     │
│   BoardsPainter: a drawn board's outline only, no rings             │
│   four-cornered: painted as its outline; Adjust boards drags its    │
│   corners (withCornerAt; a fold refused, isConvex)                  │
│   detection asks TargetCalibration.shape (BoardShape): the          │
│   watched region, crop, knife search and touch test                 │
│   QuickDrawWatcher(areas:): those players' throws timed, not scored │
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

## Quick Draw (Live): Every Frame, Cropped and Queued

On the live camera, both boards are watched at once from 1 s before the start signal's go (Task 4 of [[story-checkpoint-live-quick-draw]]; Task 2 started at Lock boards). The camera can't be asked for a frame again, so each frame's board crops are kept in a queue per board and analysed in order: a slow phone falls behind and reports late rather than skipping frames, as `RecordingAnalysisFeed` does for the recording. Crops are cut in the sensor's layout, so an Android frame (sideways) is never turned whole. Why, and the numbers, in [[Design Decisions]] → Quick Draw: the Live Camera — 60 fps, Crops and a Queue; what to check on the phones in [[Known Issues]] → Live Quick Draw: 60 fps Is Asked For, Not Guaranteed.

```
┌─────────────────────────────────────────────────────────────────────┐
│          QUICK DRAW (LIVE): EVERY FRAME, CROPPED AND QUEUED         │
│                                                                     │
│   go − 1 s: LiveCamera (liveQuickDrawCameraProvider), 60 fps        │
│   asked for (its default rate if it won't open at 60)               │
│          │  whole frames, sensor layout (Android: sideways)         │
│          ▼                                                          │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │ per board, a CroppedCamera: the upright square (4 radii,     │  │
│   │ even sides) mapped into the sensor's layout (sensorRect)     │  │
│   │ and cut there, a view (no copy); rotation fixed when made;   │  │
│   │ a frame the rectangle doesn't fit is skipped                 │  │
│   └──────────────────────────────┬───────────────────────────────┘  │
│                                  │ crops, in the sensor's layout    │
│                                  ▼                                  │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │ per board, a QueuedCamera: each crop kept as a compact       │  │
│   │ copy (compactFrame), handed on in order, one per turn of     │  │
│   │ the event loop; timestamp = arrival; past 75 MB a board      │  │
│   │ the oldest are dropped and counted                           │  │
│   └──────────────────────────────┬───────────────────────────────┘  │
│                                  │ every frame, in order (late ok)  │
│                                  ▼                                  │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │ ThrowWatcher per board, interval zero: turns the crop        │  │
│   │ upright (its uprightRotation) → MotionDetector →             │  │
│   │ classifyThrow → QuickDrawWatcher.throws (as above)           │  │
│   └──────────────────────────────┬───────────────────────────────┘  │
│                                  │ QuickDrawWatcher.states, .queues │
│                                  ▼                                  │
│   Debug builds (_WatchDebugLine): "1: watching · 2: motion ·        │
│   0.03 s behind" (· N dropped); frames/s label top left             │
│   Next round, Stop, Choose boards again: watcher disposed. The duel:│
│   next section                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Quick Draw (Live): the Duel

Once the boards are locked, **Start** runs a duel (Tasks 3–4 of [[story-checkpoint-live-quick-draw]]): the start signal, both boards watched from 1 s before go, each knife timed from go on the camera's own clock, then the result in large type with a chime. Nobody touches the phone between Start and the result. Why, and the numbers, in [[Design Decisions]] → Quick Draw: the Start Signal and Quick Draw: the Live Duel and the Result.

```
┌─────────────────────────────────────────────────────────────────────┐
│                     QUICK DRAW (LIVE): THE DUEL                     │
│                                                                     │
│   Boards locked → Start (startScheduleProvider: a new schedule,     │
│   a random pause)                                                   │
│          │                                                          │
│          ▼                                                          │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │ StartSignal: a beep (SignalSounds.beep) and a light          │  │
│   │ (_Lights) at 0, 1, 2, 3, 4 s, then a pause of 1.0–3.0 s      │  │
│   │ (startPauses, 0.2 s steps). Stop: cancelled, boards kept     │  │
│   └──────────────────────────────┬───────────────────────────────┘  │
│                                  │ onWatch, at go − 1 s             │
│                                  ▼                                  │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │ QuickDrawWatcher(queue: true) on both boards: every          │  │
│   │ frame, cropped and queued, in order (the box above)          │  │
│   └──────────────────────────────┬───────────────────────────────┘  │
│                                  │ onGo, at go                      │
│                                  ▼                                  │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │ go beep (SignalSounds.go), lights out (no GO! on screen);    │  │
│   │ goAt = camera.now: the clock the frames are stamped with     │  │
│   └──────────────────────────────┬───────────────────────────────┘  │
│                                  │ each throw timed from goAt       │
│                                  ▼                                  │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │ _checkResult every 250 ms: both throws in, or 4 s after      │  │
│   │ go (resultWindow) with every queue caught up →               │  │
│   │ judgeQuickDraw(throws, goAt): the same rule as the clip      │  │
│   └──────────────────────────────┬───────────────────────────────┘  │
│                                  │ QuickDrawVerdict                 │
│                                  ▼                                  │
│   _Result panel: "Player 2 wins" (52 pt), then each player's        │
│   line (34 pt), "2:  0.82 s · 5"; the chime (SignalSounds.result)   │
│   QuickDrawMatch.add(winner): "Round 2 of 3", "Player 2 leads 1–0"  │
│   Next round / Extra round: the watcher disposed, boards kept;      │
│   Finish match (asks) or the match over: "Player 2 wins the match"  │
└─────────────────────────────────────────────────────────────────────┘
```

## Player Names: Into the Game, History and Quick Draw

A name is a label on a seat (stage 1 of the [[Accounts Roadmap]]; requirement [[Player Names]]; why in [[Design Decisions]] → Named Players). The last names used are kept on the phone (`lib/settings/`) and fill in the setup screen; the game (`Match`) carries them, so Play, History and the kept record read the same names. Quick draw has no `Match`: it reads the names straight from `playerNamesProvider` ([[story-checkpoint-named-players]] Tasks 1–3).

```
┌─────────────────────────────────────────────────────────────────────┐
│    PLAYER NAMES: THE SETUP SCREEN → THE GAME, HISTORY, QUICK DRAW   │
│                                                                     │
│   App start: playerNamesProvider (PlayerNamesNotifier) →            │
│   PlayerNamesStore.load → player_names.json (blank if none or       │
│   unreadable; names set before it loads win)                        │
│          │                                                          │
│          ▼                                                          │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │ Setup screen (PlaySetupScreen): a field per player, filled   │  │
│   │ with the kept names; Start → playerNamesProvider.set         │  │
│   │ Quick draw: Names (NamesButton → editPlayerNames) → set      │  │
│   │ set: cleanName (trimmed, 16 characters, blank = none) →      │  │
│   │ save (FilePlayerNamesStore: .tmp, then replace; a failed     │  │
│   │ save is ignored)                                             │  │
│   └──────────────────────────────┬───────────────────────────────┘  │
│                                  │ the names (one per seat, or null)│
│                                  ▼                                  │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │ GameNotifier: each new game gets the names; a change         │  │
│   │ renames the game in place (Match.withNames), scores kept;    │  │
│   │ New game keeps them. Match.nameOf(i): the name, or           │  │
│   │ "Player i+1" (playerNumber)                                  │  │
│   └──────────────────────────────┬───────────────────────────────┘  │
│                                  │                                  │
│                                  ▼                                  │
│   Play / two-target Play: turnText, turnDetail, playerTitle,        │
│     boardMessage, boardsStateText, rowLabel ("Jo's turn")           │
│   History: GameRecord.fromMatch keeps match.names (version 2)       │
│     → resultText ("Sam wins 10–12"), GameRecordScreen headings      │
│   Quick draw (the names from playerNamesProvider, not a Match):     │
│     BoardChoosing.playerNames → choosingInstruction ("Tap the       │
│     centre of Jo's board"), verdictText(names:), matchText(m,       │
│     names), QuickDrawResultPanel(names:); board lines keep 1: / 2:  │
└─────────────────────────────────────────────────────────────────────┘
```

Signed out, nothing here leaves the phone. Signed in, the names are also backed up (see Backup, below).

## Precision and Three Targets: the Score Pad

Two games scored by hand, with no camera yet ([[story-checkpoint-more-game-types]]; requirement [[Game Type]]; why in [[Design Decisions]] → More Game Types: Precision and Three Targets). The `GameType` changes only where each knife is thrown from (Precision) or at (Three targets); the turns, rounds, corrections, Finish game and History are Play's own (`Match`, `GameSession`, `GameNotifier`).

```
┌─────────────────────────────────────────────────────────────────────┐
│     PRECISION AND THREE TARGETS: THE SETUP SCREEN → THE SCORE PAD   │
│                                                                     │
│   PlaySetupScreen: Which game? (playGame-<type>) → players, rounds  │
│   (the type's own: Precision 7, Three targets 3 / 5 / 7), names     │
│   Start → gameTypeProvider.choose · playModeProvider (2 players:    │
│   sharedTarget, taking turns) · gameLengthProvider                  │
│                                  │                                  │
│                                  ▼                                  │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │ GameNotifier.build: Match(mode, rules, names, type); a       │  │
│   │ length the type doesn't offer → type.defaultRounds; a new    │  │
│   │ type starts a new game; New game keeps it                    │  │
│   └──────────────────────────────┬───────────────────────────────┘  │
│                                  │                                  │
│                                  ▼                                  │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │ ScorePadScreen (no camera): padHeadline ("Mark's turn",      │  │
│   │ "Collect your knives", "Mark wins"); padWhere ("Round 2 of   │  │
│   │ 7: from 5 m": Match.nextDistance; "at target 2":             │  │
│   │ Match.nextTarget)                                            │  │
│   │ ScorePad 5, 4, 3, 2, 1, Miss → GameNotifier.addThrow →       │  │
│   │ Match (the same turn and round rules as Play)                │  │
│   │ ScoreCorrections: tap a slot → setScore (nothing to pause)   │  │
│   │ Finish game (asks) → finishGame · New game → newGame         │  │
│   └──────────────────────────────┬───────────────────────────────┘  │
│                                  │  the match over                  │
│                                  ▼                                  │
│   GameNotifier._keep: GameRecord.fromMatch (type; recording null:   │
│   never a Live test game) → gameHistoryProvider.add (version 3,     │
│   "type" only for Precision / Three targets) → the backup if        │
│   signed in                                                         │
│   History: howText ("Precision · 2 players, taking turns ·          │
│   7 rounds"), historyRoundLabel ("Round 2 (5 m)")                   │
└─────────────────────────────────────────────────────────────────────┘
```

## Ranked Game: Posting a Score to Game Center

The first step towards [[Rankings]] ([[story-checkpoint-game-center-scores]], 2026-10-22; why in [[Design Decisions]] → Ranked Games and Game Center). A Ranked game is Play with one player, five rounds and strict corrections; at the end of a full game, on the iPhone, its total can be posted once. Android has no `LeaderboardService`, so no Post score (backlog #21).

```
┌─────────────────────────────────────────────────────────────────────┐
│      RANKED GAME: STRICT CORRECTIONS → POST SCORE → GAME CENTER     │
│                                                                     │
│   PlaySetupScreen: Which game? → Ranked (playGame-ranked): one      │
│   player, 5 rounds; Start waits for I'm throwing from 3 m           │
│   (playRankedDistance) → gameTypeProvider.choose(ranked)            │
│                                  │                                  │
│                                  ▼                                  │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │ PlayScreen ("Ranked · 3 m", playTitle): calibrate, throws    │  │
│   │ scored by the camera as in Scoring                           │  │
│   │ ScoreCorrections: a score, an empty slot or Rounds → the     │  │
│   │ popup offers only 0 (strictNote) → Match.setScore / byHand   │  │
│   │ / addToRound; anything but 0 is refused (type.strict)        │  │
│   └──────────────────────────────┬───────────────────────────────┘  │
│                                  │  5 rounds played (not Finish     │
│                                  │  game early)                     │
│                                  ▼                                  │
│   Match.postable (Ranked, one player, over, not finished early)     │
│   GameNotifier._keep → History (GameRecord v3, type "ranked")       │
│                                  │                                  │
│                                  ▼                                  │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │ PostScorePanel (only with leaderboardServiceProvider: the    │  │
│   │ iPhone): Post score (N) → ScorePostNotifier.post:            │  │
│   │   posting → service.signIn() (Game Center's own sign-in)     │  │
│   │     false → signedOut ("Sign in to Game Center …")           │  │
│   │   → service.submit(Leaderboard.ranked3m, total)              │  │
│   │     throws → failed ("Couldn't post …", Try again)           │  │
│   │   → posted ("Posted to the leaderboard: N."): never again    │  │
│   │     for this game; ScoreCorrections locked                   │  │
│   │ View leaderboard → service.show(ranked3m): Apple's screen    │  │
│   └──────────────────────────────┬───────────────────────────────┘  │
│                                  │  GameCenterLeaderboardService    │
│                                  │  (games_services)                │
│                                  ▼                                  │
│   Apple Game Center: leaderboard ranked.3m.5x3 (recurring,          │
│   monthly): the score under the player's Game Center nickname       │
│                                                                     │
│   New game → gameProvider empty → ScorePost.ready again             │
└─────────────────────────────────────────────────────────────────────┘
```

Nothing goes to Game Center unless the player taps **Post score**: then only the total, under their Game Center nickname ([[Privacy Policy (Draft)]] → Game Center).

## App Start: Accounts (If the Build Has Them)

Stage 2 of the [[Accounts Roadmap]] ([[story-checkpoint-app-user-accounts]] Tasks 1, 2 and 4; why in [[Design Decisions]] → User Accounts Required; requirement [[Accounts and Sign-In]]). The deployed backend's settings ship as an optional asset, so a build without them (any fresh clone) starts signed out, exactly as before. Signing in happens only on Home → Account (`AccountScreen`, Amplify's screens inside an `AuthenticatedView`), never in front of the app.

```
┌─────────────────────────────────────────────────────────────────────┐
│            APP START: ACCOUNTS (ONLY IF THE BUILD HAS THEM)         │
│                                                                     │
│   main: WidgetsFlutterBinding.ensureInitialized                     │
│          │                                                          │
│          ▼                                                          │
│   loadAmplifyOutputs(rootBundle): the asset                         │
│   assets/config/amplify_outputs.json (gitignored, one per branch)   │
│          │                                                          │
│          ├── none, or empty ──▶ null                                │
│          ▼                                                          │
│   connectAccounts(outputs): Amplify.addPlugin(AmplifyAuthCognito),  │
│   AmplifyAPI too if hasBackup(outputs) (the outputs have data),     │
│   Amplify.configure(outputs) (local: no network call)               │
│          │                                                          │
│          ├── null outputs, or configure fails ──▶ null              │
│          ▼                                                          │
│   AmplifyAuthService..start(): getCurrentUser (a session kept       │
│   from last time), then the Hub's signedIn / signedOut /            │
│   sessionExpired / userDeleted → AppUser(id: Cognito sub,           │
│   displayName: email) or null → authStateChanges                    │
│          │                                                          │
│          ▼                                                          │
│   runApp(ProviderScope(overrides: authServiceProvider →             │
│   the AmplifyAuthService, only if connected; and, if hasBackup,     │
│   backupFactoryProvider → (userId) => AmplifyBackup(userId)))       │
│   ThrowerApp: Authenticator(child: app), not .builder(): the        │
│   sign-in screens only inside AccountScreen's AuthenticatedView;    │
│   ref.listen(backupStatusProvider) keeps the backup running         │
│                                                                     │
│   authServiceProvider null = signed out: the app runs as it         │
│   always has. Nothing reads it to gate scoring, Quick draw or       │
│   History.                                                          │
└─────────────────────────────────────────────────────────────────────┘
```

Separately, on the iPhone (`Platform.isIOS`), `main` also overrides `leaderboardServiceProvider` with a `GameCenterLeaderboardService` (2026-10-22); nothing contacts Game Center until **Post score** (see Ranked Game: Posting a Score to Game Center above).

Nothing leaves the phone unless the build has the settings and the user signs in: then their email and password (or their Google or Apple sign-in) go to Cognito (AWS, London `eu-west-2`), and the backup below starts.

## Backup: Sign-In Merge and Each Kept Game

Stage 2 of the [[Accounts Roadmap]] ([[story-checkpoint-app-user-accounts]] Tasks 4–5; why in [[Design Decisions]] → User Accounts Required; requirements [[Game Recording]], [[Player Names]], [[Accounts and Sign-In]]). The phone is the source of truth (offline-first): every game is kept on the phone first and the backup follows. Each user's rows are theirs alone (`allow.owner()`): `KeptGame` (`id` = `<sub>:<gameId>`, the record as the app's own JSON) and `PlayerNameList` (`id` = `<sub>`).

```
┌─────────────────────────────────────────────────────────────────────┐
│        BACKUP: SIGN-IN MERGE, EACH KEPT GAME, DELETE ACCOUNT        │
│                                                                     │
│   Sign in (AccountScreen) → authStateChanges → signedInUserProvider │
│          │                                                          │
│          ▼                                                          │
│   backupProvider: backupFactoryProvider(user.id) → Backup (games,   │
│   names, erase) = AmplifyBackup(sub); null when signed out          │
│          │                                                          │
│          ▼                                                          │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │ BackupNotifier (backupStatusProvider): BackupRunning, then   │  │
│   │ 1. PlayerNamesNotifier.syncWith(backup.names): an empty      │  │
│   │    phone takes the backup's names; else the phone's go up    │  │
│   │ 2. SyncedGameHistory.sync(): backup.list() and local.load(); │  │
│   │    only in the backup → local.add (downloaded); only on the  │  │
│   │    phone → backup.put (uploaded); merged by game id          │  │
│   │ → BackupDone(downloaded, uploaded), or BackupFailed (no      │  │
│   │   signal: the phone untouched); Back up now = backUpNow      │  │
│   └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
│   Each change while signed in (SyncedGameHistory):                  │
│     add(record) → FileGameHistory first → put (create, or update    │
│       if the row exists: a corrected game kept again)               │
│     delete(id) → local, then remove(id) · clear → local, then       │
│       remove each game. Best effort: never waits, never fails the   │
│       phone; the next sync catches up                               │
│     playerNamesProvider.set → the file, and backup.names.save       │
│                                                                     │
│   Delete account (asks first: confirmAndDeleteAccount):             │
│     deleteAccount → backup.erase() (every KeptGame, then the        │
│     PlayerNameList row) → AuthService.deleteUser (signed out).      │
│     The phone keeps its games and names. No signal: it throws,      │
│     the account stays                                               │
└─────────────────────────────────────────────────────────────────────┘
```

**Known limit:** a game deleted while signed out (or with no signal) is still in the backup, so the next sync brings it back (no tombstones).

Signed in, the kept games (scores, modes, dates, names) and the names go to AWS London, over HTTPS signed by the user's session. Signed out, nothing is sent.

## Coordinate Spaces

- **Camera frame**
  - **Where:** `CameraFrame`
  - **Notes:** Live: sensor orientation (usually sideways), 1280 × 720 at `ResolutionPreset.high`. Recording: already upright, the pack's size (322 × 322, or 720 × 1280 for Quick draw)
- **Upright image**
  - **Where:** `RgbImage` from `frameToRgb`
  - **Notes:** Rotated by the camera's `uprightRotation` (0 for a recording); calibration ellipses live here
- **Tap (Quick draw)**
  - **Where:** `BoardsOverlay` → `TapLocator`
  - **Notes:** A **fraction** of the upright picture, 0–1 each way (since 2026-10-15). `locateTappedInFrame` multiplies it by the upright image's size after `frameToRgb`, so a sideways live frame and an upright recording are treated alike
- **Drawn loop (Quick draw)**
  - **Where:** `LoopDrawer` → `BoardChoosing.addDrawnBoard` → `areaBoard`
  - **Notes:** Fractions of the picture, 0–1 each way, like a tap (2026-10-21); multiplied by `uprightPictureSize` (the next frame upright, at most 1920 px) into upright pixels, clamped into the picture, before the ellipse (and any four corners, `TargetCalibration.outline`, kept in these upright picture pixels) is fitted
- **Board crop (Quick draw)**
  - **Where:** `CroppedCamera` frames
  - **Notes:** A square of the upright picture around one board; `TargetCalibration.within` moves the rings (and a drawn board's corners) into it (subtract the crop's top-left corner); its side is `cropRadii` × the board's `shape.meanRadius`, centred on `shape.centre`. The frames themselves are cut in the camera's **sensor layout** (`sensorRect`; live Quick draw Task 2): a sideways live crop stays sideways, carrying the source's `uprightRotation` (fixed when the crop is made: each duel, 1 s before go), and is turned upright by whoever reads it; a recording's (rotation 0) is the rectangle as it is
- **Preview widget**
  - **Where:** `CalibrationEditor`
  - **Notes:** Upright image × (preview width ÷ image width); drawn as `CameraPreview`'s (or `RecordedPreview`'s) child so it lines up
- **Brightness frame**
  - **Where:** `LumaImage` from `frameToLuma`
  - **Notes:** Upright, ~320 px long side (180 × 320 portrait from a 1280 × 720 stream); motion detection and stuck/bounce classification; `WatchRegion` is in fractions so it's size-independent
- **Target**
  - **Where:** `TargetPoint`
  - **Notes:** Normalised: centre 0,0, outer edge of ring 1 at radius 1, v up; **ideal** ring radii 0.2 … 1.0
