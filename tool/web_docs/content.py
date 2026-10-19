# Content for docs/web: lanes, components, flows. Names match the code and
# docs/thrower/Architecture/Glossary.md.

LANES = {
    'ui':      ('UI', 'lib/ui'),
    'wiring':  ('Wiring', 'lib/providers.dart'),
    'camera':  ('Camera', 'lib/camera'),
    'game':    ('Game', 'lib/game'),
    'vision':  ('Vision (pure Dart)', 'lib/vision'),
    'scoring': ('Scoring (pure Dart)', 'lib/scoring'),
    'sound':   ('Sound', 'lib/sound'),
    'history': ('History and settings', 'lib/history · lib/settings'),
    'auth':    ('Auth', 'lib/auth'),
    'native':  ('Plugins and native code', 'external'),
}

# id: dict(name, lane, files, type, dek, body[paras], functions[(name, what)], flows[ids])
COMPONENTS = {
    'screens': dict(
        name='Screens', lane='ui', type='Flutter widgets',
        files=['lib/ui/home_screen.dart', 'lib/ui/play_setup_screen.dart', 'lib/ui/play_screen.dart', 'lib/ui/two_target_play_screen.dart', 'lib/ui/calibration_screen.dart',
               'lib/ui/live_test_screen.dart', 'lib/ui/quick_draw_screen.dart', 'lib/ui/live_quick_draw_screen.dart',
               'lib/ui/quick_draw_boards.dart', 'lib/ui/history_screen.dart', 'lib/ui/score_corrections.dart', 'lib/ui/instructions.dart', 'lib/ui/camera_view.dart'],
        trigger='The user, from Home',
        dek='Home leads to Play (rounds of 3, for 1 or 2 players), the History of finished games, Quick draw (two throwers on a start signal), the Instructions, the Live test recordings, Calibrate target and the Scoring test target.',
        body=[
            'Screens only draw and react: they read every other layer through Riverpod providers, so tests swap any layer for a fake.',
            '<code>CameraView</code> shows a camera preview and handles a refused permission, the app going to the background and re-opening. Both Quick draw screens choose boards the same way, through <code>quick_draw_boards.dart</code>: <code>BoardChoosing</code> (tap → find → outline), <code>BoardsOverlay</code> and <code>BoardsPainter</code>. Two-target Play does too. Once both boards are found, <code>BoardsEditor</code> lets each outline be dragged into place, with the single target\'s drag rules (<code>grabAt</code>, <code>dragged</code>); <strong>Adjust boards</strong> unlocks them later, keeping both (2026-10-19).',
            'Players can be named (2026-10-19): on the setup screen, or with <strong>Names</strong> on Quick draw before Start. A blank seat is Player 1 / Player 2. Play, History and Quick draw all show the names; Quick draw\'s per-player result lines keep "1:" / "2:", matching the board numbers on the picture.',
            'On the recording\'s Quick draw, <strong>Play</strong> shows only once the boards are locked: played unlocked, nothing would be analysed (2026-10-16).',
        ],
        functions=[
            ('HomeScreen', 'Instructions, Play, History, Quick draw, Live test, Calibrate target, Scoring test target'),
            ('PlaySetupScreen', 'after Play: 1 or 2 players; with 2, 1 target (taking turns) or 2 (at once); 3, 5 or 9 rounds; a name per player (optional, filled with the last ones); Start'),
            ('PlayScreen', 'the camera, score marks where knives went in (RoundMarks), round and game totals; for two players taking turns, whose turn it is in large type, both totals and the winner'),
            ('CalibrationScreen', 'Find target, drag the rings (CalibrationEditor), Lock'),
            ('TwoTargetPlayScreen', "two players on two targets: tap and lock both boards, each board's marks, Wait for Player 2 / Collect your knives, the winner"),
            ('LiveTestScreen', 'the recordings: Target 1, Target 2, Quick draw; Play on two targets (the Quick draw clip)'),
            ('QuickDrawScreen', 'the recorded duel: tap boards, Lock, Play, GO!, each board\'s time and the winner'),
            ('LiveQuickDrawScreen', 'the live duel: tap boards, Lock, Start, 5 lights and beeps, the long go beep, the result in large type'),
            ('ScoreCorrections', 'under Play: tap a score for a 0–5 popup, an empty slot to add a missed throw; watching paused meanwhile'),
            ('HistoryScreen · GameRecordScreen', 'the kept games, newest first, by name (resultText); a game\'s rounds; Delete; Clear history (asks first)'),
            ('NamesButton · editPlayerNames', 'Quick draw\'s Names, before Start: a field per player, the same names as Play; Save or Cancel'),
            ('BoardChoosing.playerNames', 'the names for the board texts ("Tap the centre of Jo\'s board"), Player N without'),
            ('BoardsEditor', 'both boards found, not locked: drag an outline to move, turn or stretch it (grabAt: a handle, else the board whose centre is nearest); Adjust boards unlocks, keeping both'),
            ('InstructionsScreen', 'setup, play and the safety points (instructions.dart)'),
            ('DebugTargetScreen', 'Scoring test target: tap a drawn target to see the score'),
        ],
        flows=['calibration', 'play', 'score-correction', 'game-history', 'player-names', 'choosing-boards', 'quick-draw-recording', 'live-quick-draw'],
    ),
    'providers': dict(
        name='Providers', lane='wiring', type='Riverpod providers', files=['lib/providers.dart'],
        trigger='Read and watched by the screens',
        dek='The one place the layers are wired together. Each layer sits behind a provider, so a test overrides it with a fake.',
        body=[
            '<code>cameraProvider</code> is shared by Calibrate and Play, and plays a Live test recording when <code>recordingChoiceProvider</code> picks one. The live Quick draw has its own <code>liveQuickDrawCameraProvider</code>, which asks for 60 fps and is released when the screen closes. Neither camera is retried automatically.',
            '<code>CalibrationNotifier</code> and <code>GameNotifier</code> hold the session\'s state: the locked rings, and the game\'s rounds (a <code>Match</code>: a game per player, for the mode chosen in <code>playModeProvider</code>).',
        ],
        functions=[
            ('cameraProvider / recordingChoiceProvider', 'the back camera, or a recording'),
            ('quickDrawCameraProvider', 'the Quick draw clip as a RecordedCamera'),
            ('liveQuickDrawCameraProvider', 'LiveCamera.open(fps: 60), auto-disposed'),
            ('calibrationProvider (CalibrationNotifier)', 'start, adjust, lock, unlock'),
            ('playModeProvider · gameLengthProvider', 'the setup screen\'s choices, kept for the session'),
            ('gameProvider (GameNotifier)', 'onEvent(board) → Match → a GameSession per player'),
            ('targetModelProvider · ringBoundaryRadiiProvider', 'the KATTA rings (TargetModel.katta)'),
            ('quickDrawTargetsProvider · tapLocatorProvider', 'the tapped boards, and how a tap finds one'),
            ('playTargetsProvider', "two-target Play's boards, kept for the session"),
            ('signalSoundsProvider · startScheduleProvider', 'the beeps, and a new random pause each duel'),
            ('gameHistoryProvider · historySaveErrorProvider · clockProvider', 'the kept games, a failed save, when a game finished'),
            ('playerNamesProvider (PlayerNamesNotifier) · playerNamesStoreProvider', 'the players\' names: loaded at start; set cleans and saves them; GameNotifier renames the game in place'),
            ('authServiceProvider', 'the account interface (no provider chosen yet)'),
        ],
        flows=['frame-sources', 'play', 'game-history', 'player-names', 'live-quick-draw'],
    ),
    'target-camera': dict(
        name='TargetCamera', lane='camera', type='Interface', files=['lib/camera/target_camera.dart', 'lib/camera/camera_frame.dart'],
        trigger='Every screen and watcher that needs frames',
        dek='The one camera interface. A live camera, a recording, a board crop and a queue all deliver the same CameraFrame, so nothing downstream knows which it has.',
        body=[
            'A <code>CameraFrame</code> is plain data: width, height, format (BGRA, YUV420), planes of bytes and a timestamp. Vision depends on this data type only, never on a plugin.',
            '<code>now</code> is the clock the camera stamps its frames with, so another moment, such as Quick draw\'s go, can be compared with frames on one clock.',
        ],
        functions=[
            ('frames()', 'a broadcast stream of CameraFrame, only while listened to'),
            ('uprightRotation', 'clockwise turn that makes a frame upright'),
            ('now', 'the time on the frames\' clock'),
            ('minChange', 'the smallest brightness change that counts (sensor or JPEG noise)'),
            ('zoom · maxZoom · setZoom', 'camera zoom (1× for recordings and crops)'),
        ],
        flows=['frame-sources', 'play', 'quick-draw-recording', 'live-quick-draw'],
    ),
    'live-camera': dict(
        name='LiveCamera', lane='camera', type='TargetCamera', files=['lib/camera/live_camera.dart'],
        trigger='Calibrate, Play, the live Quick draw',
        dek='The phone\'s back camera through the camera plugin, at ResolutionPreset.high, with no audio.',
        body=[
            'Android frames arrive as YUV420 in the sensor\'s layout, usually sideways; iOS frames arrive as BGRA, already upright. <code>uprightRotation</code> works out the turn from the sensor and the phone\'s orientation.',
            'The live Quick draw asks for 60 fps. If the camera won\'t open at that rate it is opened again at its default, but never after a refused permission. Frames are stamped when they reach Dart, not when they were captured (Known Issues).',
        ],
        functions=[
            ('open({fps})', 'back camera, high preset; plugin errors → CameraFailure'),
            ('frames', 'the plugin\'s image stream as CameraFrame'),
            ('uprightRotation', 'frameRotation(sensorOrientation, deviceOrientation)'),
            ('now', 'its stopwatch, which stamps each frame as it arrives'),
        ],
        flows=['frame-sources', 'calibration', 'play', 'live-quick-draw'],
    ),
    'recorded-camera': dict(
        name='RecordedCamera', lane='camera', type='TargetCamera', files=['lib/camera/recorded_camera.dart', 'lib/camera/frame_pack.dart', 'lib/camera/recording_sound.dart'],
        trigger='Live test',
        dek='A Live test recording played as a camera: a FramePack of JPEG frames, in real time, with its sound.',
        body=[
            'Frames are decoded by Flutter\'s native image codec, off the UI thread. A phone that falls behind skips to the newest frame, so the picture keeps pace with the sound.',
            'The recordings are in <code>assets/live/</code>: Target 1 and Target 2 (322 px, 15 fps), and the Quick draw clip (720 × 1280, 60 fps, with <code>quickdraw.m4a</code>). <code>Recording.go</code> is when the clip\'s countdown says go (2.8 s).',
        ],
        functions=[
            ('load(Recording)', 'the FramePack asset, plus its sound'),
            ('restart · rewind', 'play from the start · stop on the first frame'),
            ('position · playing', 'where playback is, and whether it plays'),
            ('RecordingSound', 'playFromStart, stop; ducks other apps, plays with the silent switch on'),
        ],
        flows=['frame-sources', 'quick-draw-recording'],
    ),
    'recording-analysis-feed': dict(
        name='RecordingAnalysisFeed', lane='camera', type='TargetCamera', files=['lib/camera/recording_analysis_feed.dart'],
        trigger='Quick draw on the recording, once Play is pressed',
        dek='Every frame of a recording, in order, for analysis, each stamped with its place in the clip. The picture may skip frames; analysis never does.',
        body=[
            'It decodes its own copy of each frame, one at a time, never ahead of the frame on show, so the result may come late but no frame is missed (Nigel: "analysis can come back with the actual result 1/2 second later").',
            'It starts at go − 1 s, and starts again when playback restarts.',
        ],
        functions=[
            ('frames', 'every frame from `first`, in order'),
            ('timeOf(index)', 'frame number ÷ frame rate'),
            ('analysed', 'the last frame analysed'),
            ('now', 'the playback position'),
        ],
        flows=['quick-draw-recording'],
    ),
    'cropped-camera': dict(
        name='CroppedCamera', lane='camera', type='TargetCamera', files=['lib/camera/cropped_camera.dart'],
        trigger='Quick draw, one per board',
        dek='A square of another camera\'s upright picture around one board, as a camera of its own, so single-board detection can watch one board of several.',
        body=[
            'The crop is cut in the sensor\'s own layout (<code>sensorRect</code>), so a sideways Android frame is never turned whole: only the small crop is turned, by whoever reads it. Its frames are views into the source\'s bytes, with no copying.',
            'The rotation is fixed when the crop is made, as the phone is on a stand. A frame the rectangle doesn\'t fit is skipped. All four sides are rounded to even numbers so YUV\'s half-size colour planes line up.',
        ],
        functions=[
            ('crop(frame)', 'the part at sensorRect, or null'),
            ('sensorRect(w, h, rotation)', 'the upright rectangle in the sensor\'s layout'),
            ('compactFrame(frame)', 'a tight copy of a crop, letting go of the whole frame'),
        ],
        flows=['quick-draw-recording', 'live-quick-draw'],
    ),
    'queued-camera': dict(
        name='QueuedCamera', lane='camera', type='TargetCamera', files=['lib/camera/queued_camera.dart'],
        trigger='The live Quick draw, one per board',
        dek='Every frame of a board crop, kept as a compact copy and handed on in order at the listener\'s pace. A live camera can\'t be asked for a frame again.',
        body=[
            'A phone slower than the camera falls behind and reports late, rather than skipping frames. Past 75 MB per board, the oldest frames are dropped and counted, and the result then says times may be less exact.',
        ],
        functions=[
            ('frames', 'one frame per turn of the event loop'),
            ('waiting · behind · dropped', 'how far behind analysis is'),
            ('stopTaking', 'no new frames; those queued are still analysed'),
        ],
        flows=['live-quick-draw'],
    ),
    'throw-watcher': dict(
        name='ThrowWatcher', lane='game', type='Class', files=['lib/game/throw_watcher.dart'],
        trigger='Play (one board); Quick draw (one per board)',
        dek='Watches one board\'s frames and turns motion into throw events: stuck (with its entry point), bounce-out, fell out, or a board visit.',
        body=[
            'Each frame becomes a ~320 px brightness image (<code>frameToLuma</code>) for the <code>MotionDetector</code>. While the board is still, a full-resolution "before" picture is kept, made in a background isolate.',
            'Play looks at a frame at most every 60 ms (about 15 a second). Quick draw looks at every frame, as its timing needs them all.',
        ],
        functions=[
            ('per frame', 'frameToLuma → MotionDetector.add; keep a before picture'),
            ('per episode', 'ThrowTracker.onEpisode; if stuck, the next frame is the after → findKnifeEntry'),
            ('events', 'a stream of ThrowEvent'),
            ('pause · resume · moves', 'score corrections: frames ignored, then afresh; did the phone move?'),
            ('state', 'watching, motion, settling, settled'),
        ],
        flows=['play', 'score-correction', 'quick-draw-recording', 'live-quick-draw'],
    ),
    'motion-detector': dict(
        name='MotionDetector', lane='vision', type='Class', files=['lib/vision/motion_detector.dart', 'lib/vision/luma_image.dart'],
        trigger='Each frame ThrowWatcher looks at',
        dek='Finds stretches of motion in the board\'s region (episodes): watching → motion → settling → settled, or blocked when something stands in front of the board.',
        body=[
            'A pixel counts as changed when it differs by more than 6 × the learned sensor noise, at least 12 levels. An episode ends once the board has been still for 0.3 s and looks like the board again.',
            'Its <strong>impact</strong> is the frame with the largest moving shape on the target, when the board jolts and the knife stops. Quick draw times throws by it.',
        ],
        functions=[
            ('add(frame)', 'changed share vs the previous frame → state'),
            ('MotionEpisode', 'peak, change from before, before/after frames, impact'),
            ('restart', 'after a pause: the next frame is the new reference'),
        ],
        flows=['play', 'quick-draw-recording'],
    ),
    'throw-classifier': dict(
        name='ThrowTracker and classifyThrow', lane='game', type='Class and function',
        files=['lib/game/throw_tracker.dart', 'lib/vision/throw_classifier.dart'],
        trigger='Each finished motion episode',
        dek='Decides what an episode was: a new knife stuck, a bounce-out, a known knife falling out, or someone visiting the board.',
        body=[
            'It is a board visit if someone stood there, if 10% or more of the region changed at once, or if one shape covering 3% or more of the region moved. People are 4% and up; knives are up to 2.2%. A visit closes the round, and the known knives are forgotten.',
            '<code>findNewObject</code> looks for a connected changed shape touching the target, and checks it against the knives already in the board, so a knife falling out isn\'t taken for a new one.',
        ],
        functions=[
            ('ThrowTracker.onEpisode', 'classifyThrow(knownKnives) → stuck / fell out / visit / bounce-out'),
            ('classifyThrow', 'visit tests, then findNewObject'),
        ],
        flows=['play'],
    ),
    'entry-point': dict(
        name='Entry point', lane='vision', type='Functions', files=['lib/vision/entry_point.dart'],
        trigger='A stuck knife',
        dek='Where the blade goes into the wood, which is what is scored. Not the handle, and not the shadow.',
        body=[
            'Seen face on, <code>faceOnEntry</code> takes the knife\'s shape nearest the bull. From the side, <code>GeometricEntryEstimator</code> compares the before and after pictures by colour, keeps the grey steel pixels (a shadow keeps the board\'s hue), finds the knife\'s axis, and takes the end away from the outward direction.',
            'Nigel\'s rule: "find the solid shape of the knife; score where the blade goes into the wood; a shadow comes from the knife, on the side away from the light". Improving this is the paused entry-point story.',
        ],
        functions=[
            ('findKnifeEntry', 'faceOnEntry or GeometricEntryEstimator'),
            ('outwardDirection', 'which way the handle points in the picture'),
        ],
        flows=['play'],
    ),
    'ring-locator': dict(
        name='Ring finder', lane='vision', type='Locator chain',
        files=['lib/vision/locate_in_frame.dart', 'lib/vision/coarse_to_fine_locator.dart', 'lib/vision/contrast_normalising_locator.dart',
               'lib/vision/colour_ring_locator.dart', 'lib/vision/ellipse.dart', 'lib/vision/frame_to_rgb.dart'],
        trigger='Find target (Calibrate), and each Quick draw tap',
        dek='Finds the painted rings in a frame as ellipses, one per ring edge, in a background isolate.',
        body=[
            '<code>locateInFrame</code> turns the frame upright (<code>frameToRgb</code>), then a rough pass on a shrunk picture finds the board, and a close-up pass at full resolution fits the rings. If nothing is found, each pass is tried again with the contrast stretched.',
            '<code>ColourRingLocator</code> learns the board\'s two colours from the picture (the bull\'s and the next ring\'s), casts rays out from a candidate centre, and fits an ellipse to each colour edge with RANSAC, which outvotes rays spoiled by handles or cuts.',
        ],
        functions=[
            ('locateInFrame', 'frameToRgb → buildTargetLocator().locate'),
            ('CoarseToFineLocator', 'rough pass (retry at 1200 px) → close-up pass → moved back'),
            ('ContrastNormalisingLocator', 'as-is, then normaliseContrast'),
            ('ColourRingLocator', 'learn two colours → rays → fitEllipseRansac per edge'),
        ],
        flows=['calibration', 'choosing-boards'],
    ),
    'tapped-target-locator': dict(
        name='Tapped board finder', lane='vision', type='Functions',
        files=['lib/vision/tapped_target_locator.dart', 'lib/game/quick_draw_targets.dart'],
        trigger='A tap on a board in Quick draw',
        dek='Finds the board the user tapped. There may be more boards in the picture than players, so the user picks them, Player 1 then Player 2.',
        body=[
            'The tap is a fraction of the upright picture, turned into pixels only after the frame is turned upright, so a sideways Android frame and an upright recording are treated alike.',
            'Only a square window around the tap is searched (0.45 × the picture\'s shorter side), enlarged 3×, with the tap tried first as the centre. Searching the whole picture found the wrong board: boards side by side can be painted differently.',
        ],
        functions=[
            ('locateAtTap', 'the camera\'s next frame → compute(locateTappedInFrame)'),
            ('locateTappedInFrame', 'frameToRgb → tap × size → locateTargetAt'),
            ('locateTargetAt', 'window → ColourRingLocator(seed: tap)'),
            ('boardAt', 'result → TargetCalibration or null'),
            ('QuickDrawTargets', 'the boards in tap order; add, clear, lock; replace (a dragged board), unlock (Adjust boards)'),
        ],
        flows=['choosing-boards'],
    ),
    'target-calibration': dict(
        name='TargetCalibration', lane='vision', type='Data + notifier',
        files=['lib/vision/target_calibration.dart', 'lib/providers.dart'],
        trigger='After the rings are found',
        dek='The fitted rings for the session: one ellipse per painted edge, plus the outer edge. Adjusted by dragging, then locked.',
        body=[
            'The camera doesn\'t move, so the rings are found once and locked. Taps and later throws are scored against them. Quick draw keeps one calibration per board; <code>within</code> moves the rings into a board crop\'s coordinates.',
        ],
        functions=[
            ('moved · withMajorHandleAt · withMinorHandleAt', 'drag all the rings together'),
            ('within(x, y, w, h)', 'the same rings in a crop\'s coordinates'),
            ('CalibrationNotifier', 'start, adjust (ignored when locked), lock, unlock'),
        ],
        flows=['calibration', 'choosing-boards'],
    ),
    'target-mapping': dict(
        name='TargetMapping', lane='vision', type='Class', files=['lib/vision/target_mapping.dart'],
        trigger='A tap on the locked target, or a knife\'s entry point',
        dek='Turns a pixel into normalised target coordinates: the centre at 0,0 and the outer edge of ring 1 at radius 1.',
        body=[
            'Along the ray from the bull\'s centre it finds each painted edge, and interpolates between them, so painted edge k maps to ideal radius k. A board whose paint isn\'t exactly to size still scores correctly, and a tilted board too.',
        ],
        functions=[('toTarget(pixel)', 'ray from the bull → _rayToEdge per edge → ideal radius')],
        flows=['scoring-a-point', 'play'],
    ),
    'target-model': dict(
        name='TargetModel', lane='scoring', type='Class (pure Dart)', files=['lib/scoring/target_model.dart'],
        trigger='Every score',
        dek='The board\'s rings and their scores: 5 for the inner ring down to 1 for the outer, 0 outside (KATTA, the same rings as IKTHOF).',
        body=[
            'The line-touch rule decides a blade exactly on a line: the higher ring (KATTA and IKTHOF, used today) or the lower (WATL). Per-sport rules are backlog #3.',
        ],
        functions=[('scoreAt(point, bladeHalfWidth)', 'the ring score, with a LineTouchRule'), ('TargetModel.katta()', 'ideal radii 0.2 / 0.4 / 0.6 / 0.8 / 1.0')],
        flows=['scoring-a-point', 'play', 'quick-draw-recording'],
    ),
    'game-session': dict(
        name='GameSession and Match', lane='scoring', type='Classes (pure Dart) + notifier',
        files=['lib/scoring/game_session.dart', 'lib/scoring/match.dart', 'lib/providers.dart'],
        trigger='Play, on each throw event',
        dek='A game of 3, 5 or 9 rounds of 3 throws per player. A board visit (collecting the knives) closes the round.',
        body=[
            'A bounce-out scores 0. A knife that sticks and then falls out before it is collected turns that throw into 0. Once the knives are collected, Play shows the next round straight away (backlog #12).',
            '<code>Match</code> holds a <code>GameSession</code> per player (2026-10-16). Two players on one target take turns: 3 knives, collect, then the other player, Player 1 starting every round. On two targets each board scores for its own player. The higher total wins; equal totals are a draw.',
        ],
        functions=[
            ('stuck · bounceOut · fellOut · boardVisited', 'the events'),
            ('awaitingNextRound · roundNumber · finishedRounds', 'what Play shows'),
            ('Match: playerAt · turn · winner · draw', 'whose throw it is, and who won'),
            ('Match: names · nameOf · withNames', 'the players\' names ("Player N" if blank; cleanName, 16 characters); renamed without restarting'),
            ('finish · countedRounds · countedTotals', 'Finish game: over now, a part-round counted; two players judged on equal rounds'),
            ('GameNotifier.onEvent', 'entry → TargetMapping → TargetModel → score; a finished game is kept in the history'),
            ('setScore · byHand · addToRound', 'a score set by hand (corrected), a missed throw added (0)'),
        ],
        flows=['play', 'score-correction', 'game-history', 'player-names'],
    ),
    'quick-draw-watcher': dict(
        name='QuickDrawWatcher', lane='game', type='Class', files=['lib/game/quick_draw_watcher.dart'],
        trigger='Quick draw, once the boards are locked',
        dek='Watches both boards at once, each on its own crop with the single-board throw detection at every frame, and keeps each player\'s first throw.',
        body=[
            'On the recording it reads the <code>RecordingAnalysisFeed</code>. On the live camera (<code>queue: true</code>) each crop goes through a <code>QueuedCamera</code>, so a slow phone reports late instead of missing frames.',
        ],
        functions=[
            ('start', 'per board: CroppedCamera (4 radii) + within + (QueuedCamera) + ThrowWatcher'),
            ('throws', 'each player\'s QuickDrawThrow(impact, stuck, score)'),
            ('states · queues', 'each board\'s watch state, and how far behind'),
            ('stopFeeding · dispose', 'take no new frames · stop'),
        ],
        flows=['quick-draw-recording', 'live-quick-draw'],
    ),
    'play-boards-watcher': dict(
        name='PlayBoardsWatcher', lane='game', type='Class', files=['lib/game/play_boards_watcher.dart', 'lib/game/board_crop.dart'],
        trigger='Two-target Play, once the boards are locked',
        dek='Watches both boards for a whole game of Play, each on its own crop with the single-board throw detection, and reports every event with the board it came from.',
        body=[
            "Each board is cut out with <code>cropToBoard</code> (shared with <code>QuickDrawWatcher</code>) and watched by its own <code>ThrowWatcher</code> at Play's usual pace. Each event goes to <code>GameNotifier.onEvent(board:)</code>, so a board's throws, collections and falling-out knives count only for its own player.",
        ],
        functions=[
            ('start', 'per board: cropToBoard (4 radii) + ThrowWatcher'),
            ('events', "BoardThrowEvent(board, event, the board's calibration in its crop)"),
            ('crops · states', "where each board's marks go · each board's watch state"),
        ],
        flows=['play'],
    ),
    'quick-draw-judge': dict(
        name='judgeQuickDraw and QuickDrawMatch', lane='game', type='Function + class (pure Dart)',
        files=['lib/game/quick_draw_judge.dart', 'lib/scoring/quick_draw_match.dart'],
        trigger='Once both throws are in (or time is up)',
        dek='A round\'s winner: the first knife to stick. A bounce-out or a false start loses; on the same frame the higher score wins, the same score is a draw; if nobody sticks, there\'s no winner. The live Quick draw is a match of three rounds.',
        body=[
            'Each throw is timed from go to its impact. A knife that reaches its board before go is a false start, however fast.',
            '<code>QuickDrawMatch</code> (2026-10-19, the rules of Nigel\'s brother; the European Duel Cup format) keeps each round\'s winner: all three rounds are thrown, the player with more rounds won wins, extra rounds settle a level match, and Finish match ends it early (level: a draw). It sits in the scoring layer and takes only a round\'s winner, so it doesn\'t depend on the game layer.',
        ],
        functions=[
            ('judgeQuickDraw(throws, go)', '→ QuickDrawVerdict(players, winner, draw)'),
            ('JudgedThrow', 'none / falseStart / bounced / stuck; afterGo; score'),
            ('judgedText · verdictText(v, names:)', '"0.82 s · 5" · "Player 2 wins: stuck 5, 0.82 s after go." (by name: "Sam wins: …")'),
            ('QuickDrawMatch: add · finish · wins · isExtraRound · winner · draw', 'the three-round match'),
        ],
        flows=['quick-draw-recording', 'live-quick-draw', 'player-names'],
    ),
    'start-signal': dict(
        name='StartSignal', lane='game', type='ChangeNotifier', files=['lib/game/start_signal.dart'],
        trigger='Start, on the live Quick draw',
        dek='The live Quick draw\'s start, like Formula 1: 5 beeps a second apart with a light each, a random pause, then a long go beep as the lights go out.',
        body=[
            'The pause is one of 1.0, 1.2 … 3.0 s, picked at random each duel, so nobody can time it. Watching starts 1 s before go: a knife any earlier is an obvious false start.',
            '<code>goAt</code> is read on the camera\'s own clock (<code>TargetCamera.now</code>) when the go beep is asked to play, so go and the frames are compared on one clock.',
        ],
        functions=[
            ('start · stop', 'the first beep at once, then timers · cancel'),
            ('phase · lit · goAt', 'ready / countdown / go · lights on · go on the camera\'s clock'),
            ('StartSchedule', 'beepTimes, go, watchFrom; StartSchedule.random from startPauses'),
            ('onWatch · onGo', 'at go − 1 s · at go'),
        ],
        flows=['live-quick-draw'],
    ),
    'signal-sounds': dict(
        name='SignalSounds', lane='sound', type='Interface + implementation', files=['lib/sound/signal_sounds.dart', 'tool/make_signal_sounds.dart'],
        trigger='The start signal and the result',
        dek='Quick draw\'s sounds: the countdown beep, the go beep and the result chime, played with low latency.',
        body=[
            'They are small WAV files in <code>assets/sounds/</code> (about 60 KB), made by <code>tool/make_signal_sounds.dart</code>: a 1 kHz beep, a longer 1.5 kHz go, and two rising notes for the result. Each is preloaded on its own player. They duck other apps\' audio rather than stopping it, and play with the iPhone\'s silent switch on.',
        ],
        functions=[('beep · go · result', 'play a sound'), ('AssetSignalSounds', 'audioplayers, low-latency mode')],
        flows=['live-quick-draw'],
    ),
    'game-history': dict(
        name='GameHistory', lane='history', type='Interface + file store',
        files=['lib/history/game_history.dart', 'lib/history/game_record.dart'],
        trigger='A game of Play finishing; Home → History',
        dek='Finished games of Play, kept on the phone in one JSON file: when, how it was played, each player\'s round totals and names.',
        body=[
            'A <code>GameRecord</code> holds when the game finished, the mode, the length, each player\'s round totals, the players\' names (format version 2, 2026-10-19; version 1 files still read, as Player 1 / Player 2) and, for a Live test game, the recording\'s name. Totals and the winner are worked out from the rounds, never stored.',
            '<code>FileGameHistory</code> keeps them in <code>game_history.json</code> in the app\'s own support folder (<code>path_provider</code>). Each save goes to a <code>.tmp</code> file that then replaces the old one, one save at a time. A file that can\'t be read is renamed, never deleted, and the history starts afresh.',
            'Behind an interface, so a backend can keep the games instead once there are accounts (backlog #4). Nothing leaves the phone today.',
        ],
        functions=[
            ('load · add · delete · clear', 'newest first; a game is replaced by its id'),
            ('GameRecord.fromMatch · toJson · fromJson', 'a finished match as a record, with its names; format version 2 (version 1 still reads)'),
            ('GameRecord.nameOf', 'a player\'s name, or Player N'),
            ('GameHistoryException', 'a read or write failed; setAside: a damaged file was renamed'),
        ],
        flows=['game-history', 'player-names'],
    ),
    'player-names-store': dict(
        name='PlayerNamesStore', lane='history', type='Interface + file store',
        files=['lib/settings/player_names_store.dart', 'lib/providers.dart'],
        trigger='App start (load); a name set on the setup screen or with Quick draw\'s Names (save)',
        dek='The players\' names last used, kept on the phone so the setup screen fills them in next time.',
        body=[
            'A name is a label on a seat for one game (stage 1 of the Accounts Roadmap): no player list, no history of their own. Friends with their own accounts come later.',
            '<code>FilePlayerNamesStore</code> keeps them in <code>player_names.json</code> in the app\'s own support folder, beside the history, written through a <code>.tmp</code> file, one save at a time. A file that can\'t be read gives blank names; a failed save is ignored. They\'re a convenience: nothing else depends on them.',
            'It lives in its own edge folder, <code>lib/settings/</code>, because names aren\'t history. Nothing leaves the phone.',
        ],
        functions=[
            ('load · save', 'the names, one per seat (null for blank); load never throws'),
            ('playerNamesProvider (PlayerNamesNotifier)', 'two seats, blank at first, then the kept names (unless set already); set → cleanName → save'),
        ],
        flows=['player-names'],
    ),
    'auth-service': dict(
        name='AuthService', lane='auth', type='Interface only', files=['lib/auth/auth_service.dart'],
        trigger='Not used yet',
        dek='Accounts are needed, but the backend and sign-in provider aren\'t chosen yet (backlog #4). This interface keeps the place for them.',
        body=['No network calls are made today: everything, including camera frames, stays on the phone.'],
        functions=[],
        flows=[],
    ),
}

# External boxes on the overview (not clickable).
EXTERNAL = [
    ('camera plugin', 'camera 0.12.1: preview + image stream'),
    ('audioplayers', 'recording sound, signal sounds'),
    ('Flutter image codec', 'decodes the recordings\' JPEGs'),
    ('path_provider', 'the app\'s support folder (history, names)'),
]

# id: dict(title, cat ('core' | 'flow'), lane, dek, body[paras], steps[(lane, title, [lines], component_id|None, arrow_label|None)], caption, files)
FLOWS = {
    'frame-sources': dict(
        title='Frame sources: one camera interface', cat='core', lane='camera',
        dek='Every screen and watcher reads a TargetCamera. Live, recorded, cropped and queued cameras all deliver the same CameraFrame.',
        body=[
            'This is what lets the whole app run on a PC: the Live test recordings stand in for the live camera, and tests push frames into a fake. A camera\'s frames are a broadcast stream, made only while someone listens.',
            'A live frame arrives in the sensor\'s layout (on Android, usually sideways). Boards are found in the upright picture; a board crop is cut in the sensor\'s layout and turned upright only by whoever reads it.',
        ],
        steps=[
            ('native', 'camera plugin', ['back camera, ResolutionPreset.high, no audio', 'Android: YUV420, sideways · iOS: BGRA, upright'], None, 'image stream'),
            ('camera', 'LiveCamera', ['stamped on arrival (now = its stopwatch)', 'Quick draw asks for 60 fps'], 'live-camera', 'or, for the Live test'),
            ('camera', 'RecordedCamera', ['a FramePack of JPEGs, in real time, with sound', 'may skip frames to keep pace'], 'recorded-camera', 'CameraFrame'),
            ('camera', 'CroppedCamera · QueuedCamera · RecordingAnalysisFeed', ['Quick draw: one board\'s crop · every frame kept in order', '· every frame of the clip, in order'], 'target-camera', 'CameraFrame (data only)'),
            ('vision', 'Vision and the watchers', ['frameToRgb · frameToLuma: turned upright by uprightRotation'], 'ring-locator', None),
        ],
        caption='Downstream code only ever sees CameraFrame. No plugin type crosses into vision or scoring.',
        files=['lib/camera/target_camera.dart', 'lib/camera/live_camera.dart', 'lib/camera/recorded_camera.dart'],
    ),
    'scoring-a-point': dict(
        title='A point → a score', cat='core', lane='scoring',
        dek='The same mapping scores a tap on the locked target and a knife\'s entry point.',
        body=[
            'A board seen at an angle and painted not quite to size still scores correctly: the pixel is measured against the board\'s own painted edges, then placed on the ideal rings.',
        ],
        steps=[
            ('vision', 'An image pixel', ['a tap, or EntryEstimate.point'], 'entry-point', None),
            ('vision', 'TargetMapping.toTarget', ['along the ray from the bull centre,', 'interpolate between the painted edges → ideal radius'], 'target-mapping', 'TargetPoint (normalised)'),
            ('scoring', 'TargetModel.scoreAt', ['5 (bull) … 1 (outer ring), 0 outside', 'LineTouchRule decides a point on a line'], 'target-model', None),
        ],
        caption='Normalised coordinates: the centre at 0,0 and the outer edge of ring 1 at radius 1. Ideal ring radii 0.2 … 1.0.',
        files=['lib/vision/target_mapping.dart', 'lib/scoring/target_model.dart'],
    ),
    'calibration': dict(
        title='Finding and locking the target', cat='core', lane='vision',
        dek='Once per session: find the painted rings in one frame, let the user adjust them, then lock them.',
        body=[
            'The phone is on a static mount, so the rings found once stay right for the session. The search runs in a background isolate, so the preview doesn\'t stutter.',
        ],
        steps=[
            ('ui', 'Find target', ['CalibrationScreen'], 'screens', 'frames().first'),
            ('camera', 'TargetCamera', ['the next frame'], 'target-camera', 'compute (background isolate)'),
            ('vision', 'locateInFrame', ['frameToRgb: upright, full resolution', 'rough pass at 600 px (retry 1200) → close-up pass', 'as-is, then with the contrast stretched', 'ColourRingLocator: two colours → rays → RANSAC ellipses'], 'ring-locator', 'found, or the rejected attempt'),
            ('wiring', 'calibrationProvider', ['start → adjust (drag the rings) → lock', 'kept for the session'], 'target-calibration', None),
        ],
        caption='If the rings are wrong, the user drags them; once locked, Play scores against them.',
        files=['lib/ui/calibration_screen.dart', 'lib/vision/locate_in_frame.dart', 'lib/providers.dart'],
    ),
    'play': dict(
        title='A throw → a score (Play)', cat='flow', lane='game',
        dek='Rounds of 3: motion on the board becomes a throw event, the throw\'s entry point becomes a score, and collecting the knives closes the round.',
        body=[
            'The motion pass is cheap (brightness at ~320 px, about 15 frames a second); full-resolution pictures and the entry search run in background isolates. Nobody needs to touch the phone while playing.',
        ],
        steps=[
            ('camera', 'TargetCamera stream', ['live, or a Live test recording'], 'target-camera', 'at most every 60 ms'),
            ('game', 'ThrowWatcher', ['frameToLuma → MotionDetector, inside the board\'s region:', 'watching → motion → settling → settled', 'keeps a full-resolution before picture'], 'throw-watcher', 'MotionEpisode'),
            ('game', 'ThrowTracker → classifyThrow', ['stuck · bounce-out · fell out · board visit'], 'throw-classifier', 'stuck'),
            ('vision', 'findKnifeEntry', ['faceOnEntry, or GeometricEntryEstimator (before, after)'], 'entry-point', 'ThrowEvent'),
            ('scoring', 'GameNotifier → Match → GameSession', ['entry → TargetMapping → TargetModel → score', 'bounce-out 0 · fell out → 0 · visit closes the round', '3, 5 or 9 rounds × 3 throws, for each player'], 'game-session', None),
            ('ui', 'PlayScreen', ['score marks where the knives went in, round and game totals'], 'screens', None),
        ],
        caption='A board visit (someone collecting knives) is recognised by size: people cover 4% of the region and up, knives up to 2.2%. On two targets, PlayBoardsWatcher runs this for each board on its own crop, and each board scores for its own player.',
        files=['lib/game/throw_watcher.dart', 'lib/game/throw_tracker.dart', 'lib/scoring/game_session.dart', 'lib/scoring/match.dart', 'lib/ui/play_screen.dart', 'lib/game/play_boards_watcher.dart', 'lib/ui/two_target_play_screen.dart'],
    ),
    'score-correction': dict(
        title='Changing a score (without jogging the camera)', cat='flow', lane='ui',
        dek='Tap a score under the picture for a 0–5 popup, or an empty slot to add a throw the camera missed. Watching pauses meanwhile; afterwards the app checks the phone didn\'t move.',
        body=[
            'This is the first control that brings someone to the phone during a game, beside the lane. The Instructions say: only when no one is throwing, tap lightly, and never move the phone closer to reach it.',
            'The marks on the picture remember which throw they are, not their score, so a changed score shows there at once, in light blue.',
        ],
        steps=[
            ('ui', 'ScoreCorrections', ['tap a score, an empty slot (–), or Rounds'], 'screens', 'pauseWatching'),
            ('game', 'ThrowWatcher.pause', ['frames ignored; the picture before kept', 'the knives in the board remembered'], 'throw-watcher', '0–5 popup'),
            ('scoring', 'GameNotifier.setScore / addThrow', ['corrected: the camera\'s result kept, the new score', 'an empty slot: 0 = missed, 1–5 = stuck'], 'game-session', 'resumeWatching'),
            ('game', 'ThrowWatcher.resume', ['MotionDetector.restart: the next frame is the reference', '0.5 s later, on a still frame: cameraShift'], 'throw-watcher', '≥ 2 px'),
            ('ui', 'Play\'s message', ['"The phone may have moved. If the green rings', 'no longer line up, calibrate again when no one is throwing."'], 'screens', None),
        ],
        caption='2 px at ~320 px: still footage shifts by up to 1 px, a harmless nudge by 1.4 px; on a typical board 2 px is a sixth to a quarter of a ring.',
        files=['lib/ui/score_corrections.dart', 'lib/game/throw_watcher.dart', 'lib/vision/camera_move.dart', 'lib/scoring/game_session.dart'],
    ),
    'game-history': dict(
        title='Keeping and viewing finished games', cat='flow', lane='history',
        dek='When a game of Play finishes it is kept on the phone, once. Home → History lists the games; a game shows every round.',
        body=[
            'Saving never holds up play: the record is handed to the history and Play carries on. If the save fails, Play says so in a snack bar.',
            'Finish game ends a game early: a round in progress counts, and two players are judged on the rounds both have played. History shows "2 of 9 rounds" and marks a round that didn\'t count.',
            'Only finished games are kept. A last-round knife that falls out after the end saves the same game again with the new score, under the time it first finished.',
        ],
        steps=[
            ('scoring', 'GameNotifier.onEvent', ['the event that leaves the Match over', 'reset or unfinished: nothing kept'], 'game-session', '_keep, once'),
            ('history', 'GameRecord.fromMatch', ['at: clockProvider (also its id)', 'recording: the Live test recording\'s name, if any'], 'game-history', 'gameHistoryProvider.add'),
            ('history', 'FileGameHistory', ['game_history.json in the support folder', 'written through .tmp, one save at a time'], 'game-history', 'failed: historySaveErrorProvider → snack bar'),
            ('ui', 'Home → HistoryScreen', ['load: newest first · "No games yet"', '"Couldn\'t load the history" + Try again'], 'screens', 'tap a game'),
            ('ui', 'GameRecordScreen', ['the result, each player\'s total and rounds', 'Delete · Clear history (asks first)'], 'screens', None),
        ],
        caption='The history stays on the phone: the app sends it nowhere, and deleting the app deletes it.',
        files=['lib/providers.dart', 'lib/history/game_record.dart', 'lib/history/game_history.dart', 'lib/ui/history_screen.dart'],
    ),
    'player-names': dict(
        title='Player names: into the game, History and Quick draw', cat='flow', lane='history',
        dek='Players can be named on Play\'s setup screen, or with Names on Quick draw. The last names used are kept on the phone; the game carries them, so Play and History show the same names.',
        body=[
            'A name is a label on a seat for one game (2026-10-19). A blank seat is Player 1 / Player 2. Renaming during a game keeps the scores; New game keeps the names.',
            'Quick draw has no game of Play behind it, so its screens read the names straight from <code>playerNamesProvider</code>, through <code>BoardChoosing.playerNames</code>.',
        ],
        steps=[
            ('ui', 'PlaySetupScreen · Quick draw\'s Names', ['a field per player, filled with the kept names', 'Start, or Save in the Names dialog (editPlayerNames)'], 'screens', 'playerNamesProvider.set'),
            ('wiring', 'PlayerNamesNotifier.set', ['cleanName: trimmed, 16 characters, blank = none'], 'providers', 'save'),
            ('history', 'FilePlayerNamesStore', ['player_names.json in the support folder', 'read back at the next start'], 'player-names-store', 'the names'),
            ('scoring', 'GameNotifier → Match.withNames', ['each new game named; a change renames it in place', 'nameOf(i): the name, or Player i+1'], 'game-session', 'Match'),
            ('ui', 'Play · History · Quick draw', ['"Jo\'s turn", "Sam wins 10–12" (GameRecord version 2)', '"Tap the centre of Jo\'s board", "Sam wins the match 2–1"'], 'screens', None),
        ],
        caption='Names stay on the phone: nothing is sent anywhere, and deleting the app deletes them.',
        files=['lib/ui/play_setup_screen.dart', 'lib/ui/quick_draw_boards.dart', 'lib/settings/player_names_store.dart', 'lib/scoring/match.dart', 'lib/history/game_record.dart', 'lib/ui/live_quick_draw_screen.dart'],
    ),
    'choosing-boards': dict(
        title='Choosing two boards by tapping (Quick draw, two-target Play)', cat='flow', lane='ui',
        dek='Tap the centre of Player 1\'s board, then Player 2\'s (by name, if the players are named), drag an outline into place if needed, then Lock boards. Both Quick draw screens and two-target Play do it the same way.',
        body=[
            'There may be more boards in the picture than players, so the user picks them. Finding boards automatically missed board 2 on half the frames of the duel clip.',
            'Once both are found, each outline can be dragged into place (only when no one is throwing: the phone stands behind the throwers). <strong>Adjust boards</strong> unlocks them later, keeping both; on two-target Play it stops watching and clears the marks, and the scores stay (2026-10-19).',
        ],
        steps=[
            ('ui', 'BoardsOverlay', ['screen point ÷ the picture\'s size on screen', '= a fraction, 0–1 each way'], 'screens', 'BoardChoosing.findBoardAt'),
            ('wiring', 'tapLocatorProvider → locateAtTap', ['the camera\'s next frame'], 'tapped-target-locator', 'compute (background isolate)'),
            ('vision', 'locateTappedInFrame', ['frameToRgb: upright (Android turned first), cap 1920 px', 'fraction × upright size = pixels', 'locateTargetAt: 0.45 window, enlarged 3×, tap as seed'], 'tapped-target-locator', 'TargetFound / TargetNotFound'),
            ('wiring', 'quickDrawTargetsProvider', ['found: add (next player) · none: "No board found there."', 'two found: Lock boards · Choose boards again: clear'], 'tapped-target-locator', 'two found, not locked'),
            ('ui', 'BoardsEditor', ['drag: grabAt on each board → dragged → replace(index, board)', 'locked: Adjust boards → unlock (both kept)'], 'screens', None),
            ('ui', 'BoardsPainter', ['each board\'s rings and player number', 'blue while choosing (with handles), green once locked'], 'screens', None),
        ],
        caption='On the recording, Play appears only once the boards are locked; on the live camera, Start does.',
        files=['lib/ui/quick_draw_boards.dart', 'lib/ui/calibration_editor.dart', 'lib/game/quick_draw_targets.dart', 'lib/vision/tapped_target_locator.dart'],
    ),
    'quick-draw-recording': dict(
        title='Quick draw on a recording: every frame, then the winner', cat='flow', lane='game',
        dek='Live test → Quick draw: a recording of a real duel. Each board is watched on its own crop at every frame from 1 s before go; each knife is timed from go; the first to stick wins.',
        body=[
            'The picture and sound play at their own pace and may skip frames on a slow phone. Analysis gets its own copy of every frame, in order, so the result can come a little after the picture, but no frame is missed.',
            'On the recording of the duel, Player 2 (Mark) wins: stuck 5, about 0.82 s after go.',
        ],
        steps=[
            ('camera', 'RecordedCamera', ['the 60 fps clip with its sound; GO! flashes at 2.8 s'], 'recorded-camera', 'Play (boards locked)'),
            ('camera', 'RecordingAnalysisFeed', ['every frame from go − 1 s, decoded in order', 'never ahead of the picture; stamped with clip time'], 'recording-analysis-feed', 'every frame, in order'),
            ('camera', 'CroppedCamera × 2', ['a square 4 × the board\'s radius around each board', 'TargetCalibration.within: rings in crop coordinates'], 'cropped-camera', 'one crop per player'),
            ('game', 'ThrowWatcher × 2 (every frame)', ['impact = the frame with the largest moving shape', 'stuck / bounce-out; stuck → entry → score'], 'throw-watcher', 'ThrowEvent'),
            ('game', 'QuickDrawWatcher.throws', ['each player\'s first throw: impact, stuck, score'], 'quick-draw-watcher', 'throws + go'),
            ('game', 'judgeQuickDraw', ['per player: none / false start / bounced / stuck', 'winner: first to stick · same frame: the higher score'], 'quick-draw-judge', None),
            ('ui', 'QuickDrawScreen', ['under each board: "0.82 s · 5", "0.85 s · bounced"', '"Player 2 wins: stuck 5, 0.82 s after go."'], 'screens', None),
        ],
        caption='The answer key for the clip is docs/thrower/reference/live-camera/quickdraw.json; a test runs the clip through the live path and checks it.',
        files=['lib/ui/quick_draw_screen.dart', 'lib/camera/recording_analysis_feed.dart', 'lib/game/quick_draw_watcher.dart', 'lib/game/quick_draw_judge.dart'],
    ),
    'live-quick-draw': dict(
        title='Live Quick draw: start signal to result', cat='flow', lane='game',
        dek='Home → Quick draw: lock the boards, a starter taps Start, 5 beeps and lights, a random pause, the go beep, then the result in large type with a chime.',
        body=[
            'Nobody touches the phone between Start and the result, and the result is large enough to read from the throwing line, so no one walks up to a phone beside two live lanes. Neither the chime nor the result means the lanes are clear.',
            'The camera can\'t be asked for a frame again, so each frame\'s board crops are queued and analysed in order. A slow phone reports late; past 75 MB a board, frames are dropped and the result says so.',
        ],
        steps=[
            ('ui', 'Start (boards locked)', ['startScheduleProvider: a new random pause'], 'screens', None),
            ('game', 'StartSignal', ['a beep and a light at 0, 1, 2, 3, 4 s', 'then a pause of 1.0–3.0 s (0.2 s steps) · Stop cancels'], 'start-signal', 'onWatch, at go − 1 s'),
            ('camera', 'LiveCamera → CroppedCamera → QueuedCamera', ['60 fps asked for · each board cut in the sensor\'s layout', 'every crop kept in order (75 MB a board)'], 'queued-camera', 'every frame, in order'),
            ('game', 'QuickDrawWatcher(queue: true)', ['ThrowWatcher per board, every frame'], 'quick-draw-watcher', 'onGo, at go'),
            ('sound', 'go beep (long, higher) · lights out', ['nothing shown for go: the beep is the signal', 'goAt = camera.now: the clock frames are stamped with'], 'signal-sounds', 'each throw timed from goAt'),
            ('game', 'judgeQuickDraw(throws, goAt)', ['both throws in, or 4 s after go with the queues caught up', '(15 s at the latest)'], 'quick-draw-judge', 'QuickDrawVerdict'),
            ('ui', 'Result panel + chime', ['"Player 2 wins" or "Sam wins" (52 pt), each player\'s line (34 pt)', 'the match: three rounds (QuickDrawMatch), extra rounds if level', 'Next round keeps the boards · Finish match · New match'], 'screens', None),
        ],
        caption='Untested on a phone so far: 60 fps, heat over ten duels, beep latency and reading the result from 4 m (Device Test Plan → Quick Draw Checks).',
        files=['lib/ui/live_quick_draw_screen.dart', 'lib/game/start_signal.dart', 'lib/camera/queued_camera.dart', 'lib/sound/signal_sounds.dart'],
    ),
}

CORE_CARDS = ['frame-sources', 'scoring-a-point', 'calibration']
FLOW_CARDS = ['play', 'score-correction', 'game-history', 'player-names', 'choosing-boards', 'quick-draw-recording', 'live-quick-draw']

CARD_TEXT = {
    'frame-sources': 'Live, recorded, cropped and queued cameras behind one interface, so the app runs on a PC and in tests.',
    'scoring-a-point': 'A pixel measured against the board\'s own painted edges, placed on the ideal rings, scored 5 to 0.',
    'calibration': 'Find the rings once in a background isolate, drag to adjust, lock for the session.',
    'play': 'Motion → episode → stuck or bounce-out → entry point → score; collecting the knives closes the round.',
    'score-correction': 'Tap a score for 0–5, or an empty slot for a miss; watching paused, then a check the phone didn\'t move.',
    'game-history': 'A finished game kept once in a JSON file on the phone; Home → History to look back.',
    'player-names': 'A name per seat, kept on the phone, carried by the game into Play, History and Quick draw.',
    'choosing-boards': 'Tap Player 1\'s board, then Player 2\'s: a fraction of the picture, a window search, the rings; drag an outline into place.',
    'quick-draw-recording': 'The recording of a real duel: every frame analysed in order, each knife timed from go, the winner.',
    'live-quick-draw': 'The start signal, both boards queued at 60 fps from 1 s before go, the result in large type.',
}

NOTES = [
    ('Layer rules', [
        '<code>lib/vision</code> and <code>lib/scoring</code> have no Flutter imports: they run in background isolates and in tests on a PC.',
        'Vision depends only on the camera layer\'s data type, <code>CameraFrame</code>, never on a plugin.',
        'Plugins stay behind interfaces (<code>TargetCamera</code>, <code>RecordingSound</code>, <code>SignalSounds</code>), so tests feed recorded frames and fake sound.',
    ]),
    ('Off the UI thread', [
        'Frame conversion, ring finding and the entry search run through <code>compute</code>, with top-level functions and plain data.',
        'The motion pass stays on the UI thread: brightness only, at ~320 px.',
    ]),
    ('On the phone only', [
        'No backend yet and no network calls: camera frames never leave the phone, and nor do the game history and the player names (files in the app\'s own folder).',
        'The camera records no sound today. Recording and sharing (backlog #11) would change that, and needs the Review Agent.',
    ]),
]
