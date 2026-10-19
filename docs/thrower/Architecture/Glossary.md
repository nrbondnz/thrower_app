# Glossary: Components, Functions and Concepts

Three kinds of thing (Docs Agent §5): **components** (system elements), the **functions** they perform (parent → child), and **concepts** (terms that mean something on their own and may be used by several components). Names match the code.

## Component → Function Tree

- **`TargetCamera`** (`lib/camera/target_camera.dart`): the camera interface the screens and game use (`frames`, `uprightRotation`, zoom, `minChange`)
  - `now`: the time on the clock this camera stamps its frames with (`CameraFrame.timestamp`), so another moment (Quick draw's go) can be compared with frames; each implementation's is under it below
- **`LiveCamera`** (`lib/camera/live_camera.dart`)
  - `open({fps})`: back camera, `ResolutionPreset.high`, no audio; `fps` asks for a frame rate (the live Quick draw: 60), and if the camera won't open at it, it's opened again at its default (never for a refused permission); plugin errors → `CameraFailure`
  - `frames`: broadcast stream of `CameraFrame`, only while listened to
  - `uprightRotation`: `frameRotation(sensorOrientation, deviceOrientation)`
  - `now`: its stopwatch, the one that stamps each frame as it arrives in Dart
- **`RecordedCamera`** (`lib/camera/recorded_camera.dart`): a Live test recording played as a camera
  - `load(Recording)`: the `FramePack` asset, plus an `AssetRecordingSound` if the recording has `audio`
  - `restart`: play from the start (sound too); `rewind`: stop and wait on the first frame (sound stopped)
  - `Recording.go`: when the recording's countdown says go, from its start (`quickDrawRecording`: 2.8 s); null for recordings without one
  - `now`: its playback clock (the one frames are stamped with)
  - **`RecordingSound`** (`lib/camera/recording_sound.dart`): `playFromStart`, `stop`, `dispose`; `AssetRecordingSound` (`audioplayers`; `audioContext`: ducks other apps, ignores the silent switch). A failing sound is reported; frames play on
- **`RecordingAnalysisFeed`** (`lib/camera/recording_analysis_feed.dart`): **every** frame of a `RecordedCamera`'s recording, in order, for analysis (Quick draw)
  - `frames`: decodes its own copy of each frame, one at a time, up to the frame on show (never ahead of the picture); only while listened to; starts again from frame 0 when playback restarts
  - `timeOf(index)`: a frame's place in the recording (frame number ÷ frame rate), its `timestamp`
  - `analysed`: the last frame analysed (-1 before the first)
  - `now`: the playback position (its frames are stamped with their place in the recording)
  - `dispose`: stops following the camera (doesn't dispose it)
- **`CroppedCamera`** (`lib/camera/cropped_camera.dart`): a part of another camera's **upright** picture as a camera of its own, cut in the sensor's layout (any rotation)
  - `frames` → `crop`: each frame's part at `sensorRect`, as a view into the source's bytes (BGRA, YUV); null (the frame is skipped) if the rectangle doesn't fit; `x`, `y`, `width`, `height` rounded down to even
  - `sensorRect(frameWidth, frameHeight, rotation)`: the upright rectangle in the sensor's layout (the inverse of `frameToRgb`'s turn)
  - `uprightRotation`: the source's, **fixed when the crop is made** (the live Quick draw: each duel, 1 s before go), so the crop is turned upright by whoever reads it
  - **`compactFrame(frame)`**: a tight copy of a cropped frame's own pixels, letting go of the whole source frame
  - `now`: the source's
- **`QueuedCamera`** (`lib/camera/queued_camera.dart`): every frame of another camera (a board crop), kept as a compact copy and handed on in order, at its listener's pace (the live Quick draw)
  - `frames`: one frame per turn of the event loop; listens to the source only while listened to; timestamps kept (arrival)
  - `waiting` (frames queued), `behind` (newest arrived − last handed on), `dropped`
  - `maxBytes`: 75 MB by default; past it the oldest frames are dropped and counted
  - `dispose`: stops listening and clears the queue (the source isn't its to dispose)
  - `now`: the source's
- **`QuickDrawScreen`** (`lib/ui/quick_draw_screen.dart`), the recording (Live test → Quick draw): `quickDrawCameraProvider` → full-screen `RecordedPreview`, Play / Play again → `restart`
  - `_GoFlash`: "GO!" over the picture for 0.7 s from `Recording.go`, while playing (follows `RecordedCamera.position`)
  - `_progress`: the bottom line while a locked game plays: "Watching…", "Analysing… 0.4 s behind the picture." (more than 0.2 s behind), then `verdictText` once both throws are in or the whole clip is analysed
  - boards chosen with `BoardChoosing` and `BoardsOverlay` (`tapsOff` while playing); Lock boards → `lock`; Choose boards again → `clear` + `rewind`; **Adjust boards** (`quickDrawAdjust`, locked and not playing) → stop watching + `unlock` + `rewind`
  - Play with the boards locked → a fresh `RecordingAnalysisFeed` and a `QuickDrawWatcher` on it; Choose boards again / leaving → `dispose` both
- **`LiveQuickDrawScreen`** (`lib/ui/live_quick_draw_screen.dart`), Home → Quick draw: `CameraView(camera: liveQuickDrawCameraProvider)` full screen, system bars hidden
  - boards chosen with `BoardChoosing` and `BoardsOverlay`; Lock boards → `lock`; Choose boards again → `_endDuel` + `clear`; **Adjust boards** (`quickDrawAdjust`, not while a round is on) → `unlock` (boards and match kept)
  - `_start` (Start, once locked): a `StartSignal` (`startScheduleProvider`, `signalSoundsProvider`, `clock` = `camera.now`); `onWatch` (go − 1 s) → a `QuickDrawWatcher(queue: true)` on both boards; `onGo` → `_checkResult` every 250 ms (nothing shown at go: the beep is the signal)
  - `_checkResult`: once both throws are in, or `resultWindow` (4 s) after go with every queue caught up → `judgeQuickDraw(throws, goAt)`, the `result` chime, `_Result`
  - `_endDuel`: stops the signal, watcher and result; **Stop** (countdown) and **Next round** / **Extra round** (result) → `_nextRound` (boards kept)
  - `_match` (a `QuickDrawMatch`): each result → `add(verdict.winner)`; **Finish match** → `confirmFinishMatch` → `finish`; **New match** → `_newMatch`; `roundLabel`, `matchText(m, names)` ("Player 2 leads 1–0", "Player 2 wins the match 2–1"; by name, "Sam leads 2–0")
  - `_line`: "Boards locked. Throwers ready? Tap Start: …", "Wait for the long beep…", "Watching…"
  - `_Lights`: the 5 start lights, red as each beep sounds (countdown only)
  - `QuickDrawResultPanel(verdict, match, names:)`: the result panel, readable from the throwing line: the round (`roundLabel`), `headline` ("Player 2 wins" / "Player 2 wins on score" / "A draw" / "No winner", 52 pt; by name, "Sam wins"), each player's `judgedText` (34 pt; still "1:" / "2:", matching the board numbers on the picture) and `matchText` (44 pt, green, at the end); scales down to fit
  - **`NamesButton`** whenever no round is under way (hidden once Start is tapped)
  - `_WatchDebugLine` (debug builds, while watching): each board's state and how far behind, "1: watching · 2: motion · 0.03 s behind" ("· N dropped" if any)
- **`quick_draw_boards.dart`** (`lib/ui/`): shared by both Quick draw screens
  - **`BoardChoosing`** (mixin on the screen's state): `findBoardAt(camera, tap)` → `tapLocatorProvider` → `boardAt` → `quickDrawTargetsProvider.add`; `searching`, `missed`; **`playerNames`** (the names from `playerNamesProvider`, "Player N" without one; also two-target Play's); `choosingInstruction` ("Tap the centre of Player 1's board." / "… of Jo's board.", "No board found there. …", "Both boards found. Drag an outline to fit its rings if needed (only when no one is throwing), then lock them.")
  - **`NamesButton`** (Quick draw's **Names**, before Start, on both Quick draw screens) → **`editPlayerNames(context, ref)`**: a dialog (`_NamesDialog`, which owns its fields so they outlive its closing animation) with a field per player, filled with the current names; Save → `playerNamesProvider.set`; Cancel changes nothing
  - **`BoardsOverlay`**: `BoardsPainter` over the picture; taps → **fractions** of the picture's width and height (`onTap`), ignored while `tapsOff`; `throws` → `boardLines`; **`onAdjust`** (set while both boards are found and not locked) → the `BoardsEditor` in place of taps
  - **`BoardsEditor`** (2026-10-19, [[story-checkpoint-adjust-boards]]): both boards draggable; a touch → `grabAt` on each board (a handle beats a body; between bodies, the board whose centre is nearest) → `dragged` → `onAdjust(player, board)`
  - **`BoardsPainter`**: each board's rings, scaled from its own image size, and its player number (blue while choosing, green once locked); `results`: each player's line under their board; `handles`: each board's two handles (while adjustable)
  - `boardLines(throws, go)`: the line under each board, via `judgeQuickDraw` → `judgedText` ("0.82 s · 5", "0.85 s · bounced", "false start"); null before the throw is in
  - `quickDrawLine(text)`: the instruction or result line at the bottom
- **`CameraView`** (`lib/ui/camera_view.dart`): a camera's preview with errors, release in the background and re-open handled; `camera:` the provider to show (default `cameraProvider`; Quick draw: `liveQuickDrawCameraProvider`); `overlayBuilder`
- **`liveQuickDrawCameraProvider`** (`lib/providers.dart`): the live Quick draw's own `LiveCamera`, `open(fps: 60)` (auto-disposed, never retried automatically); not `cameraProvider`
- **`StartSignal`** (`lib/game/start_signal.dart`, a `ChangeNotifier`): the live Quick draw's start signal, like Formula 1
  - `start`: the first beep at once, then timers: a beep and a light each `gap`; `onWatch` at `watchFrom`; at `go`: `goAt` = `clock()`, `sounds.go`, lights out, `onGo(goAt)`
  - `phase` (**`StartPhase`**: `ready`, `countdown`, `go`), `lit` (0–5), `goAt` (go on the camera's clock)
  - `stop`: cancels the timers, back to `ready`; `dispose`
  - **`StartSchedule`**: `pause`, `beeps` (5), `gap` (1 s); `beepTimes` (0–4 s), `go` (last beep + pause), `watchFrom` (go − `quickDrawLeadIn`); `StartSchedule.random` picks the pause from **`startPauses`** (1.0–3.0 s in 0.2 s steps)
  - `startScheduleProvider` (`lib/providers.dart`): a new random schedule for each duel; tests fix the pause
- **`SignalSounds`** (`lib/sound/signal_sounds.dart`): Quick draw's sounds (interface; tests use a fake): `beep`, `go`, `result`, `dispose`
  - **`AssetSignalSounds`**: `assets/sounds/` `beep.wav`, `go.wav`, `result.wav`, each on its own `audioplayers` player, loaded once, low-latency, `AssetRecordingSound.audioContext` (ducks, ignores the silent switch)
  - `signalSoundsProvider` (`lib/providers.dart`, auto-disposed)
  - made by **`tool/make_signal_sounds.dart`**: sine tones with 5 ms fades, written as WAV (mono, 16-bit, 22.05 kHz)
- **`QuickDrawTargets`** (`lib/game/quick_draw_targets.dart`): the boards in tap order, `players` (2), `complete`, `locked`; `QuickDrawTargetsNotifier` (`lib/providers.dart`): `add`, `clear`, `lock`, **`replace(index, board)`** (a dragged board; ignored once locked), **`unlock`** (Adjust boards: keeps both boards)
  - **`TapLocator`**: (camera, tap as a fraction of the upright picture) → `TappedTargetsResult`; `tapLocatorProvider`
  - `locateAtTap`: the camera's next frame → `compute(locateTappedInFrame)`; `boardAt`: result → `TargetCalibration` or null
- **`QuickDrawWatcher`** (`lib/game/quick_draw_watcher.dart`), on the `RecordingAnalysisFeed` (since Task 4; was the picture's frames), or on the live camera with `queue: true`: `start`: per board a `CroppedCamera` (`cropRadii` 4, side rounded to even) + `TargetCalibration.within` (the crop's size) + (`queue`: a `QueuedCamera`) + `ThrowWatcher(interval: zero)`
  - `states`: each board's `WatchState`; `queues`: each board's `QueuedCamera` (when `queue`)
  - `throws`: each player's first stuck or bounce-out event as a **`QuickDrawThrow`** (`impact` = `MotionEpisode.impact`, `stuck`, `score` via `TargetMapping` → `TargetModel.scoreAt`); `dispose`
- **`judgeQuickDraw(throws, go)`** (`lib/game/quick_draw_judge.dart`): a round's winner rule → a **`QuickDrawVerdict`** (`players`, `winner`, `draw`, `byScore`: the same frame, decided by the higher score)
  - per player a **`JudgedThrow`**: `result` (**`QuickDrawResult`**: `none`, `falseStart`, `bounced`, `stuck`), `afterGo` (impact − go), `score` (stuck only)
  - `winner`: the stuck player with the smallest `afterGo`; equal times → `draw`; nobody stuck → null
  - `judgedText(JudgedThrow)`: "0.82 s · 5", "0.85 s · bounced", "false start", "no throw" (`afterGoText`: "0.82 s")
  - `verdictText(QuickDrawVerdict, names:)`: "Player 2 wins: stuck 5, 0.82 s after go. Player 1 bounced out." / "A draw: …" / "No winner. …" By name with `names` ("Sam wins: …"), "Player N" without one
- **`locateTappedInFrame`** (`lib/vision/tapped_target_locator.dart`): `frameToRgb` (upright, cap 1920 px) → each tap's fraction × the upright size = pixels → `locateTargetAt` per tap, in tap order
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
- **`CalibrationEditor`** (`lib/ui/calibration_editor.dart`): the single target's outline, dragged (`handleReach` 32 px); the drag rules, shared with `BoardsEditor`:
  - **`grabAt(calibration, point, reach)`** → **`CalibrationGrab`** (`move`, `major`, `minor`) or null: the nearer handle within reach, unless the finger is nearer the centre (small targets); else `move` if inside the outer ring (× 1.1)
  - **`dragged(calibration, grab, delta:, at:)`**: `moved`, `withMajorHandleAt` or `withMinorHandleAt`
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
  - `awaitingNextRound` (knives collected, game not over), `roundNumber` (the next round once collected), `finishedRounds` (the collected rounds); used by Play's `roundText` / `gameText`
- **`Match`** (`lib/scoring/match.dart`) / **`PlayMode`** / **`playModeProvider`** (`lib/providers.dart`) / **`PlaySetupScreen`** (`lib/ui/play_setup_screen.dart`)
  - `PlayMode`: `solo`, `sharedTarget` (2 players taking turns), `twoTargets` (2 players at once); chosen on the setup screen after Play
  - `gameLengthProvider` (`GameLengthNotifier`, `choices` 3 / 5 / 9, default 9): the rounds in a game, also chosen there
  - Finish game: `GameSession.finish` / `finished` / `finishedEarly`; `Match.finish`, `finishedEarly`, `countedRounds`, `countedTotals` (winner and draw on equal rounds); `GameNotifier.finishGame`; Play's `gameOverText`, `confirmFinishGame`
  - `Match`: a `GameSession` per player; `stuck` / `bounceOut` / `boardVisited` take the `board`; `playerAt(board)`, `turn`, `turnThrows`, `turnComplete`, `nextTurn`, `nextThrowStartsRound`, `takesThrowAt`, `fellOut(player, …)`, `isOver`, `winner`, `draw`
  - Play's two-player panel (`lib/ui/play_screen.dart`, `PlayersPanel`): `turnText` ("Player 1's turn" / "Collect your knives" / "Wait for Player 2" / "Player 2 wins" / "A draw"), `turnDetail`, `playerTitle`, `playerDetail`, `matchFooter`; `eventMessage`, `paintRoundMarks`
- **Named players** ([[story-checkpoint-named-players]]): `Match.names`, `nameOf`, `withNames`; `cleanName` (`maxNameLength` 16), `playerNumber` (`lib/scoring/match.dart`); **`PlayerNamesStore`** / **`FilePlayerNamesStore`** (`lib/settings/player_names_store.dart`: `load`, `save`); **`playerNamesProvider`** (`PlayerNamesNotifier`: `set`; `playerNamesStoreProvider`); `GameNotifier` renames the game in place (`withNames`); shown by `PlaySetupScreen` (`playName0`/`1` fields), `turnText`, `turnDetail`, `playerTitle`, `boardMessage(player, …)`, `boardMovedMessage(player)`, `boardsStateText(states, names)`, `rowLabel` (score-correction rows), History's `resultText`; Quick draw (Task 3): `BoardChoosing.playerNames`, `choosingInstruction`, `NamesButton` / `editPlayerNames`, `verdictText(names:)`, `matchText(m, names)`, `QuickDrawResultPanel(names:)`
- **`GameRecord`** (`lib/history/game_record.dart`) / **`GameHistory`**, **`FileGameHistory`**, **`GameHistoryException`** (`lib/history/game_history.dart`) / **`gameHistoryProvider`**
  - `GameRecord.fromMatch(match, at:, recording:)`; `names`, `nameOf` (version 2); `totals`, `winner`, `draw`, `liveTest`, `finishedEarly`, `countedRounds`, `countedTotals`; `toJson` / `fromJson` (`version` 1, `FormatException` if unreadable)
  - `load` (newest first) · `add` · `delete(id)` · `clear`; one file, `game_history.json`, written through a `.tmp` file, one save at a time; a damaged file is set aside (`setAside`)
  - kept by `GameNotifier.onEvent` → `_keep` when the match is over: once (`_finishedAt`, `_kept`), re-saved if a knife falls out after the end; `clockProvider` (the finish time), `historySaveErrorProvider` (a failed save; Play's snack bar)
- **`ScoreCorrections`** (`lib/ui/score_corrections.dart`) / **`CorrectionHost`**
  - per player: the round in progress as slots (`shownRound`); a score → `showScorePicker` (`scoreChoices`: 0 and the rings) → `GameNotifier.setScore`; the first empty slot (when `Match.nextThrowerAt` is this player) → `addThrow` → `CorrectionHost.addedByHand`; **Rounds** → `_RoundList` → `_RoundEditor` (`setScore`, `addToRound`); every popup between `CorrectionHost.pauseWatching` and `resumeWatching`
  - the rule: `ThrowRecord.corrected`, `byHand`, `withScore`, `ThrowResult.missed`; `GameSession.setScore`, `byHand`, `hasRoomIn`, `addToRound`; `Match.setScore`, `byHand`, `addToRound`, `ThrowSlot`, `throwAt`, `lastThrowAt`, `nextThrowerAt`
  - marks: `RoundMarks` holds `ThrowSlot`s (`addByHand`); `paintRoundMarks(match:)`, `markColour`
  - pausing: `ThrowWatcher.pause` / `resume` / `moves` (`moveCheckDelay` 0.5 s), `PlayBoardsWatcher.pause` / `resume` / `moves`, `MotionDetector.restart`
- **`cameraShift`** / **`phoneMoved`** / **`phoneMovedShift`** (`lib/vision/camera_move.dart`): `bestShift` over the board's region, up to ±8 px; 2 px or more is a move; Play's `phoneMovedMessage`, two targets' `boardMovedMessage`
- **`HistoryScreen`** / **`GameRecordScreen`** (`lib/ui/history_screen.dart`)
  - `HistoryScreen`: `load` → the list, newest first; "No games yet"; "Couldn't load the history" + Try again; **Clear history** (asks first) → `clear`
  - `GameRecordScreen`: `howText`, `resultText`, each player's rounds and total; **Delete** → `delete(id)`, back to the list
  - text: `whenText` ("16 Oct, 14:32"), `howText` ("2 players, 1 target · 5 rounds · Live test: Target 1"), `resultText` ("Player 1 wins 61–58", "A draw 15–15", "Total 37"), `summaryText` (a list line)
- **`PlayBoardsWatcher`** (`lib/game/play_boards_watcher.dart`) / **`cropToBoard`** (`lib/game/board_crop.dart`) / **`TwoTargetPlayScreen`** (`lib/ui/two_target_play_screen.dart`) / **`playTargetsProvider`**
  - `start`: per board `cropToBoard` (also used by `QuickDrawWatcher`) + `ThrowWatcher`; `events` → `BoardThrowEvent(board, event, calibration)`; `crops`, `states`
  - the screen: `BoardChoosing.addBoard` → `playTargetsProvider`; camera to 1×; `BoardMarksPainter`; `boardMessage`; `boardsStateText`; **Adjust boards** (`playAdjustBoards`) → `_adjustBoards`: stops watching, clears the marks, `unlock` (scores stay; locking again watches afresh)
- **`QuickDrawMatch`** (`lib/scoring/quick_draw_match.dart`): a Quick draw match of three rounds ([[story-checkpoint-quick-draw-match]])
  - `add(winner)` (null: a drawn round), `finish()`; `results`, `wins`, `leader`, `roundNumber`, `isExtraRound`, `isOver`, `winner`, `draw`, `scoreText`
- **`TargetModel`** (`lib/scoring/target_model.dart`)
  - `scoreAt(point, bladeHalfWidth)` with a `LineTouchRule`
- **Test data**: `SyntheticTarget` (flat, affine), `SyntheticScene` (3D ray tracer), `PhotoBoardTexture` (reference photo as the board face, knives removed); tools `render_camera_views`, `locate_target`, `printable_target`

## Concepts

| Term | Meaning | Used by |
|---|---|---|
| **Normalised target coordinates** | Position on the target with the centre at 0,0 and the outer edge of ring 1 at radius 1 (v up). Scores are defined here. | `TargetPoint`, `TargetModel`, `TargetMapping`, `SyntheticScene` |
| **Ideal vs painted rings** | Ideal: IKTHOF radii 0.2 / 0.4 / 0.6 / 0.8 / 1.0. Painted: where the paint actually is (reference board 0.219 / 0.395 / 0.620 / 0.8). Scoring maps painted edge k to ideal k. | `TargetMapping`, `render_camera_views` |
| **Line-touch rule** | How a blade touching the line between rings scores: higher (KATTA, IKTHOF), lower (WATL), or by majority of blade (IATF, backlog). | `TargetModel` |
| **KATTA scoring** | The scoring the app uses (Nigel's brother, 2026-10-19: "prevalent in the UK"): KATTA UK's European face, 5 rings 10 / 20 / 30 / 40 / 50 cm across scoring 5 / 4 / 3 / 2 / 1, a blade cutting a line taking the higher ring, only a stuck tip scoring. The same as IKTHOF's octagons. | `TargetModel.katta`, the Instructions' Scoring section |
| **Ellipse fitting** | Finding the ellipse that best passes through a set of points. Here: Halíř–Flusser's stable form of Fitzgibbon's direct least-squares fit. A circle seen at an angle is (nearly) an ellipse. | `fitEllipse`, `ColourRingLocator` |
| **RANSAC** | Fit to many small random samples, keep the fit most points agree with, refit on those. Outvotes bad points (rays spoiled by handles or cuts). | `fitEllipseRansac` |
| **Coarse-to-fine** | Find roughly on a shrunk image, then look closely at a full-resolution crop. Needed because the board is small in the frame. | `CoarseToFineLocator` |
| **Contrast stretch** | Map the darkest/brightest 1% of brightness to black/white, same map on all channels (hue kept). A fallback for dim or flat light. | `normaliseContrast`, `ContrastNormalisingLocator` |
| **Two-colour rings** | The target is any two alternating colours (A = bull, B = next), learned per image rather than fixed. | `ColourRingLocator` |
| **Upright rotation** | Clockwise rotation turning a sideways sensor frame upright: (sensor − device + 360) % 360. | `frameRotation`, `frameToRgb` |
| **Sensor layout vs upright** | A live frame arrives as the sensor lays it out (on Android, usually sideways); upright is how the user sees it. Boards are found and tapped in the upright picture; a board crop maps its upright rectangle back into the sensor's layout and is cut there, so only the small crop is ever turned. The crop's rotation is fixed when the crop is made, at the start of each duel's watching (the phone is on a stand). | `CroppedCamera.sensorRect`, `frameToRgb`, `frameToLuma`, `ThrowWatcher` |
| **Calibration lock** | The fitted rings fixed for the session (the camera doesn't move); taps and later throws are scored against them. | `CalibrationNotifier`, `CalibrationScreen` |
| **Grab (drag-to-adjust)** | What a touch on an outline picks up: the long-axis handle (turn and stretch), the short-axis handle (stretch), or the body (move); all rings move together. A handle wins only when the finger is nearer it than the centre, so the middle of a small outline still moves it. Requirement: [[Two Targets]]. | `grabAt`, `CalibrationEditor`, `BoardsEditor` |
| **Turn** | Two players on one target: one player's knives (3, or fewer if collected early), from their first throw until they're collected or the next player's knife lands. Player 1 starts every round. | `Match` |
| **Board visit** | Someone at the board (collecting knives), not a throw: they stood there, ≥ 10% of the region changed at once, or one shape ≥ 3% of the region moved (people are 4%+, knives up to 2.2%). Ends the round. | `classifyThrow`, `ThrowTracker`, `GameSession` |
| **Episode** | One stretch of motion in the board's region, from the first change until the board has been still for 0.3 s and looks like the board again. One throw, one bounce, or one visit to the board. | `MotionDetector`, `ThrowTracker` |
| **Reference frame / blocked** | The board as last seen settled. Still frames that differ from it by more than 8% mean something is in front of the board (blocked), not settled. | `MotionDetector` |
| **Noise-adaptive threshold** | A pixel counts as changed when it differs by more than 6 × the sensor noise (learned while still), at least 12 levels. | `MotionDetector` |
| **Known knives** | Shapes of the knives already in the board, so a knife disappearing (falling out) isn't mistaken for a new one. Forgotten when someone collects them. | `ThrowTracker`, `classifyThrow` |
| **Colour vs brightness change** | Shaded steel can match red paint's brightness, so the full-resolution entry search compares colour (largest channel difference); motion detection uses brightness (cheap, enough to see change). | `GeometricEntryEstimator`, `MotionDetector` |
| **Steel vs shadow** | A knife's shadow is new too, but keeps the board's hue; the knife is grey (low saturation). | `GeometricEntryEstimator` |
| **Entry point (how a knife is scored)** | Where the blade goes into the wood. Nigel's rule (2026-10-13): "find the solid shape of the knife; score where the blade goes into the wood; a shadow comes from the knife, on the side away from the light". Not the handle, and not the end of the shadow nearest the bull. | `faceOnEntry`, `GeometricEntryEstimator`, [[story-checkpoint-entry-point]] |
| **Quick draw** | Two throwers, one board each, both in one camera view, throwing together after a countdown. The first knife to stick wins; a bounce-out loses ([[story-checkpoint-quick-draw]]). Two versions: the Live test clip (played full screen with its sound, the boards chosen by tapping, every frame analysed, each board's time after go and result, and the winner), and the live camera from Home → Quick draw ([[story-checkpoint-live-quick-draw]]: choose and lock the boards, Start, the start signal, both boards watched on every frame at 60 fps from 1 s before go, then the result in large type). Since 2026-10-19 the live one is a **Quick draw match**. | `QuickDrawScreen`, `LiveQuickDrawScreen`, `StartSignal`, `quickDrawRecording`, `quickDrawCameraProvider`, `liveQuickDrawCameraProvider`, `BoardChoosing`, `QuickDrawTargets`, `QuickDrawWatcher`, `RecordingAnalysisFeed`, `QueuedCamera`, `judgeQuickDraw` |
| **Quick draw match** | Three rounds of Quick draw (Nigel's brother, 2026-10-19; the European Duel Cup format). A round goes to the first knife to stick; on the same frame, the higher score; the same score, or no knife stuck, is a drawn round. All three are thrown even at 2–0; the player with more rounds won wins. Level after three → **extra rounds**, one at a time, until one is won. **Finish match** ends it on the rounds won so far (level: a draw). [[story-checkpoint-quick-draw-match]] | `QuickDrawMatch`, `judgeQuickDraw` (`byScore`), `LiveQuickDrawScreen`, `QuickDrawResultPanel` |
| **False start** | In Quick draw, a knife that reaches its board before "go" (exactly at go is not). It loses, however fast. Boards are watched from 1 s before go, so one thrown earlier isn't timed (it's already in the board): an obvious false start. | `judgeQuickDraw` (`QuickDrawResult.falseStart`), `quickDrawLeadIn` |
| **Start signal** | How the live Quick draw says go, like Formula 1 (Nigel and Mark): 5 beeps a second apart, a light with each, a random pause (one of 1.0–3.0 s in 0.2 s steps, so nobody can time it), then a long, higher go beep as the lights go out. Nothing is shown for go (Nigel, 2026-10-16). | `StartSignal`, `StartSchedule`, `startPauses`, `SignalSounds`, `LiveQuickDrawScreen` |
| **Go (camera clock)** | The moment of go, read on the clock the camera stamps its frames with (`TargetCamera.now`), so it's compared with impacts on one clock. Taken when the go beep is asked to play; the sound's start delay is the same for both throwers, so the winner is fair even if absolute times are a little off. | `StartSignal.goAt`, `TargetCamera.now`, `judgeQuickDraw` |
| **Result window** | How long after go the live Quick draw waits for throws (4 s), once analysis has caught up, before giving the result anyway, so a thrower who doesn't throw doesn't hang the duel. The result comes sooner once both throws are in. | `LiveQuickDrawScreen.resultWindow` |
| **Time after go** | How long from "go" to the knife reaching the board (its impact). What Quick draw shows and judges by; not the time into the clip. | `JudgedThrow.afterGo`, `Recording.go` |
| **Analysis feed / report late** | Analysis gets every frame of a recording, in order, timed by its place in the clip, on its own path, while the picture may skip frames to keep up with the sound. Analysis never runs ahead of the picture, so the result can come a little after the moment it shows (Nigel, 2026-10-15: "1/2 second later"). | `RecordingAnalysisFeed`, `QuickDrawScreen` |
| **Frame queue / report late (live)** | A live camera can't be asked for a frame again, so each frame's board crops are kept (compact copies) and analysed in order; a phone slower than the camera falls behind ("s behind" in debug builds) instead of skipping frames. Capped at 75 MB a board, past which the oldest are dropped and counted ([[story-checkpoint-live-quick-draw]] Task 2). | `QueuedCamera`, `QuickDrawWatcher.queue`, `LiveQuickDrawScreen` |
| **Impact (frame)** | When a knife reached the board: the frame, within a motion episode, with the largest moving shape on the target (the board jolts and the knife stops at once). Not the episode's start: seen from behind the thrower, a knife in flight is over the board all the way in. Quick draw times throws by it. | `MotionEpisode.impact` / `impactFrame`, `QuickDrawThrow.impact` |
| **Board crop** | A square of the picture around one board, treated as a camera of its own, so single-board detection can watch one board of several at full detail. On a live camera it's cut in the sensor's layout (see Sensor layout vs upright). | `CroppedCamera`, `TargetCalibration.within`, `QuickDrawWatcher` |
| **Seed (tap) centre** | Where the user says a board's centre is, by tapping it. Tried first as the centre, then snapped to the colour regions under and around it (the bull, or the ring tapped, is centred on the board). Lets the user pick which boards count when more are in the picture. The tap is a fraction of the upright picture, turned into pixels after the frame is turned upright. | `ColourRingLocator.seed`, `locateTargetAt`, `BoardsOverlay` |
| **Ducking** | Turning other apps' audio down while ours plays, rather than stopping it. | `AssetRecordingSound.audioContext`, `AssetSignalSounds` |
| **Outward direction** | Which way "out of the board" points in the picture: from the outer ring's ellipse centre towards the bull's centre (a tilted circle's centre appears shifted towards the far side). The handle lies that way; the entry is the other end. | `outwardDirection`, `GeometricEntryEstimator` |
| **Ray tracing (test renders)** | Colouring each pixel by following a ray from the camera into a 3D scene; gives photo-like test images with exact answers. | `SyntheticScene` |
| **Named player** | A name on a seat for one game ("Mark" in place of "Player 2"): a label, nothing more (Nigel, 2026-10-19). Blank is "Player N". The last names used are kept on the phone to fill in next time. Not a **friend** (another app user with a linked account: stage 3 of the [[Accounts Roadmap]]). Requirement: [[Player Names]]. | `Match.nameOf`, `GameRecord.nameOf`, `playerNamesProvider`, `PlayerNamesStore`, `BoardChoosing.playerNames`, `NamesButton` |
| **Kept game (game history)** | A finished game of Play saved on the phone: when it finished, how it was played (mode, rounds), each player's round totals, and the Live test recording if it was played on one. Only finished games are kept, once each; totals and the winner are worked out from the rounds. | `GameRecord`, `GameNotifier`, `FileGameHistory`, `HistoryScreen` |
| **Finished early / counted rounds** | A game ended with Finish game before its last round. A round in progress counts with the throws made so far; with two players the result is judged on the counted rounds, as many as both have played, and a round beyond them is shown but not counted. | `GameSession`, `Match`, `GameRecord`, `PlayersPanel`, `HistoryScreen` |
| **Score set by hand (corrected throw)** | A throw whose score a player changed (a dispute) or a throw added because the camera didn't see it: 0 is a miss (`missed`), 1–5 a stuck knife. It keeps what the camera saw; only the score is the player's. | `ThrowRecord`, `GameSession`, `Match`, `ScoreCorrections`, `paintRoundMarks` |
| **Camera shift (phone moved)** | How far the whole picture moved between two frames over the board, found as the shift that best lines them up. A knife or a person changes part of the picture and gives no shift; a jogged phone moves all of it. 2 px or more at ~320 px means the locked rings may no longer line up. | `cameraShift`, `ThrowWatcher.moves`, `PlayBoardsWatcher` |
