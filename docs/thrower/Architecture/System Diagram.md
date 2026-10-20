# System Diagram

Thrower App runs on the phone. The only parts that reach a backend are sign-in and the backup of kept games and player names (AWS Amplify, stage 2 of the [[Accounts Roadmap]]), and only when the build has the backend's settings and the user signs in; see [[Design Decisions]] → User Accounts Required. Requirements: [[Accounts and Sign-In]], [[Game Recording]], [[Player Names]]. The layers each depend only on the ones below them. The UI reaches every layer through Riverpod providers (`lib/providers.dart`), so tests can swap any layer for a fake. Drawn in the same box style as WhereWillWeVisit's System Diagram (2026-10-14).

```
┌─────────────────────────────────────────────────────────────────────┐
│                       PHONE (iOS / Android)                         │
│       on a static mount, out of the line of throw, facing board     │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                        UI  (lib/ui)                           │  │
│  │  HomeScreen ─┬─ InstructionsScreen                            │  │
│  │              ├─ AccountScreen (only with accounts): sign-in   │  │
│  │              │    (AuthenticatedView), backup line, Back up   │  │
│  │              │    now, Sign out, Delete account (asks first)  │  │
│  │              ├─ HistoryScreen ── GameRecordScreen             │  │
│  │              ├─ PlaySetupScreen (game, players, rounds, names)│  │
│  │              ├─ ScorePadScreen (Precision, Three targets):    │  │
│  │              │    ScorePad 5–1 · Miss, no camera; turns       │  │
│  │              ├─ PlayScreen ── CameraView · RoundMarks         │  │
│  │              │    └ ScoreCorrections (tap a score: 0–5 popup) │  │
│  │              ├─ LiveQuickDrawScreen ── CameraView (live)      │  │
│  │              │    Start → _Lights · go beep · _Result (large) │  │
│  │              ├─ CalibrationScreen ── CalibrationEditor        │  │
│  │              ├─ LiveTestScreen ─┬─ CalibrationScreen, Play    │  │
│  │              │                  └─ QuickDrawScreen            │  │
│  │              │                       └─ RecordedPreview       │  │
│  │              └─ DebugTargetScreen                             │  │
│  │  quick_draw_boards (Quick draw screens, two-target Play):     │  │
│  │    BoardChoosing (tap → find → outline) · BoardsOverlay       │  │
│  │    Quick draw: or draw round each (LoopDrawer → areaBoard;    │  │
│  │      timed only) · boardsModeButton                           │  │
│  │    ── BoardsPainter · boardLines · quickDrawLine              │  │
│  │    BoardsEditor (drag each outline; Adjust boards → unlock)   │  │
│  │    playerNames (Play's names) · NamesButton ─▶                │  │
│  │      editPlayerNames (Names dialog, before Start)             │  │
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
│  │    (add · replace · lock · unlock · clear; areas: drawn)      │  │
│  │  boardsDrawnProvider (Quick draw: draw round the boards)      │  │
│  │  pictureSizerProvider (uprightPictureSize, at most 1920 px)   │  │
│  │  liveQuickDrawCameraProvider (live Quick draw's own, 60 fps)  │  │
│  │  signalSoundsProvider           startScheduleProvider         │  │
│  │  playModeProvider (1 or 2 players, 1 or 2 targets)            │  │
│  │  gameTypeProvider (Scoring, Precision, Three targets)         │  │
│  │  playTargetsProvider (two-target Play's boards, session-long) │  │
│  │  gameHistoryProvider (kept games: SyncedGameHistory)          │  │
│  │    · historySaveErrorProvider                                 │  │
│  │  clockProvider (when a game finished)                         │  │
│  │  playerNamesProvider (PlayerNamesNotifier: the names,         │  │
│  │    saved on change, backed up signed in) ◀──                  │  │
│  │    playerNamesStoreProvider                                   │  │
│  │  signedInUserProvider ◀── authServiceProvider                 │  │
│  │  backupProvider (the signed-in user's Backup, or null)        │  │
│  │    ◀── backupFactoryProvider (main: AmplifyBackup)            │  │
│  │  backupStatusProvider (BackupNotifier: sync on sign-in;       │  │
│  │    backUpNow) · deleteAccountProvider (backup, then account)  │  │
│  └──────┬──────────────────┬──────────────────┬──────────┬───────┘  │
│         │                  │                  │          │          │
│         ▼                  ▼                  ▼          ▼          │
│  ┌─────────────┐  ┌─────────────────┐  ┌────────────┐ ┌──────────┐  │
│  │   CAMERA    │  │      GAME       │  │  SCORING   │ │   AUTH   │  │
│  │ lib/camera  │  │    lib/game     │  │lib/scoring │ │ lib/auth │  │
│  │             │  │                 │  │ pure Dart  │ │          │  │
│  │TargetCamera │  │ ThrowWatcher    │  │            │ │AuthServ- │  │
│  │ ├LiveCamera │─▶│  ├MotionDetector│  │TargetModel │ │ice: the  │  │
│  │ ├Recorded-  │  │  ├ThrowTracker  │─▶│ scoreAt    │ │interface │  │
│  │ │ Camera    │  │  └classifyThrow │  │GameSession │ │ └Amplify-│  │
│  │ │ ├FramePack│  │ findTarget      │  │ rounds of 3│ │  AuthSer-│  │
│  │ │ └Recording│  │ QuickDrawTargets│  │ 3, 5 or 9  │ │  vice:   │  │
│  │ │  Sound    │  │ QuickDrawWatcher│  │ rounds     │ │  Cognito │  │
│  │ ├Recording- │  │  └ThrowWatcher×2│  │GameType:   │ │  sign-in;│  │
│  │ │ Analysis- │  │ judgeQuickDraw  │  │ Scoring,   │ │  id = sub│  │
│  │ │ Feed      │  │  go, false start│  │ Precision, │ │null: no  │  │
│  │ ├Cropped-   │  │  → winner       │  │ Three tar- │ │settings, │  │
│  │ │ Camera    │  │ StartSignal     │  │ gets       │ │signed out│  │
│  │ │           │  │  beeps, lights, │  │ Match.type │ │connect-  │  │
│  │ │           │  │  goAt = now     │  │            │ │Accounts  │  │
│  │ │           │  └────────┬────────┘  └────────────┘ └──────────┘  │
│  │ └Queued-    │           │                  ▲                     │
│  │  Camera     │           │                  │                     │
│  │ now: frames'│           │                  │                     │
│  │ clock (go)  │           │                  │                     │
│  │CameraFrame  │           │                  │                     │
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
│                 │  cameraShift (did the phone move? 2 px)         │ │
│                 └─────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌──────────────────────── SOUND (lib/sound) ─────────────────────┐ │
│  │ SignalSounds (interface) ◀── StartSignal, LiveQuickDrawScreen  │ │
│  │  └AssetSignalSounds: assets/sounds/ beep · go · result (WAV,   │ │
│  │    made by tool/make_signal_sounds.dart); signalSoundsProvider │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌─────────────────────── HISTORY (lib/history) ──────────────────┐ │
│  │ GameHistory (interface) ◀── GameNotifier (a finished game),    │ │
│  │   HistoryScreen (list, delete, clear)                          │ │
│  │  └SyncedGameHistory (gameHistoryProvider): the phone first,    │ │
│  │    then the backup if signed in; sync() merges by id           │ │
│  │    ├FileGameHistory: game_history.json in the app's support    │ │
│  │    │ folder; GameRecord v3 (when, mode, type, rounds,          │ │
│  │    │ round totals, names): the source of truth                 │ │
│  │    └RemoteGameStore (interface: list, put, remove) ◀──         │ │
│  │      AmplifyBackup (lib/auth): KeptGame rows; also the names'  │ │
│  │      PlayerNamesStore (PlayerNameList); erase                  │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌────────────────────── SETTINGS (lib/settings) ─────────────────┐ │
│  │ PlayerNamesStore (interface: load, save) ◀──                   │ │
│  │   playerNamesProvider (loads at start, saves on change; signed │ │
│  │   in, also to AmplifyBackup; syncWith on sign-in)              │ │
│  │  └FilePlayerNamesStore: player_names.json in the app's         │ │
│  │    support folder: the names last used (blank if unreadable)   │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌───────────────────────── NATIVE CODE ──────────────────────────┐ │
│  │ camera (LiveCamera: back camera, image stream, no audio;       │ │
│  │   Quick draw asks for 60 fps)                                  │ │
│  │ audioplayers (RecordingSound: Live test clip; SignalSounds:    │ │
│  │   Quick draw beeps and chime, low latency; play only)          │ │
│  │ Flutter engine image codec (decodeFrameNatively), not a plugin │ │
│  │ path_provider (FileGameHistory, FilePlayerNamesStore: the      │ │
│  │   app's support folder)                                        │ │
│  │ amplify_flutter, amplify_auth_cognito (AmplifyAuthService:     │ │
│  │   Cognito sign-in; configured only if the settings exist)      │ │
│  │ amplify_authenticator (AccountScreen's sign-in screens)        │ │
│  │ amplify_api (AmplifyBackup: GraphQL; added only if the         │ │
│  │   deployed backend has a data API: hasBackup)                  │ │
│  └────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
          │  AmplifyAuthService → Cognito (sign-in); AmplifyBackup →
          │  the data API (the user's own games and names). Only if the
          ▼  build has the settings and the user signs in
┌─────────────────────────────────────────────────────────────────────┐
│            BACKEND  (AWS Amplify Gen 2, London eu-west-2)           │
│                                                                     │
│  amplify/backend.ts ── defineBackend({auth, data}); sign-in         │
│    domain per branch: throwerapp (main), throwerapp-dev (dev)       │
│  amplify/auth/resource.ts ── defineAuth: Cognito user pool,         │
│    email, Google, Sign in with Apple (six secrets in SSM);          │
│    return link throwerapp://callback/, throwerapp://signout/        │
│  amplify/data/resource.ts ── defineData (user pool), owner-only     │
│    (allow.owner()): KeptGame (id = <sub>:<gameId>, gameId,          │
│    finishedAt, record: the app's GameRecord JSON) and               │
│    PlayerNameList (id = <sub>, names)                               │
│                                                                     │
│  Deployed by Amplify Hosting from GitHub (amplify.yml:              │
│    ampx pipeline-deploy): main = production, dev = development      │
│  Hosting frontend: web_public/ (holding page; the privacy policy)   │
│  Its settings: amplify_outputs.json, one per branch, copied to      │
│    assets/config/ in the app (gitignored)                           │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                     CALIBRATION FLOW (once per session)             │
│                                                                     │
│   User taps "Find target", or "Tap the board" then the board        │
│          │                                                          │
│          ▼                                                          │
│   ┌─────────────┐  frame   ┌──────────────────────────────────────┐ │
│   │TargetCamera │─────────▶│  background isolate (compute)        │ │
│   │  .frames()  │          │  locateInFrame: upright RGB, coarse  │ │
│   └─────────────┘          │  pass, close-up pass, ring ellipses  │ │
│                            │  (a tap: locateTappedInFrame round   │ │
│                            │  it; ring alignment if nothing else) │ │
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
│   │ Match: a GameSession per player, by board or by turn         │  │
│   │ Match.names / nameOf: the players' names ("Player N" if      │  │
│   │   blank); renamed in place (withNames) when they change      │  │
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
│   Quick draw (recording): boards chosen by tapping, impact time     │
│   and result under each board, every frame analysed, times          │
│   after go, false start and winner (story complete). The live       │
│   game is Home → Quick draw: LiveQuickDrawScreen on the live        │
│   camera (liveQuickDrawCameraProvider, 60 fps asked), boards chosen │
│   the same way (quick_draw_boards; or drawn round, timed only),     │
│   then each board watched on                                        │
│   every frame (CroppedCamera → QueuedCamera → ThrowWatcher) from    │
│   1 s before the start signal's go; the result in large type        │
│   (see Data Flow)                                                   │
└─────────────────────────────────────────────────────────────────────┘
```

**Rules:**
- `lib/vision` and `lib/scoring` have **no Flutter imports**. They run in background isolates and in tests on a PC.
- Vision depends on the camera layer's **data** types (`CameraFrame`) only, never on a plugin.
- Plugins stay in the edge layers, behind interfaces (`TargetCamera`, `RecordingSound`, `SignalSounds`; `path_provider` behind `GameHistory` and `PlayerNamesStore`; Amplify behind `AuthService`, and the backup behind `RemoteGameStore` and `PlayerNamesStore`), so tests feed recorded frames, fake sound and temporary folders.
- Heavy work (frame conversion, ring finding, the entry search) runs off the UI thread via `compute`, using top-level functions and plain data. See [[Known Issues]] → Isolate Fails.

**Precision and Three targets** (2026-10-20, [[story-checkpoint-more-game-types]]) skip the camera, game and vision layers: `ScorePadScreen` feeds hand-tapped scores straight into `GameNotifier` → `Match` (with its `GameType`), and from there into History like any game ([[Data Flow]] → Precision and Three Targets: the Score Pad).

See [[Data Flow]] for one frame's path to a score, and [[Glossary]] for the component → function tree and terms.
