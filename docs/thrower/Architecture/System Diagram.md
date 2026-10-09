# System Diagram

Thrower App runs entirely on the phone (no backend yet; see [[Design Decisions]] → User Accounts Required). Four layers, each depending only on the ones below it. The UI reaches every layer through Riverpod providers (`lib/providers.dart`), so tests can swap any layer for a fake.

```mermaid
flowchart TB
  subgraph UI["UI (lib/ui)"]
    Home[HomeScreen]
    Cal[CalibrationScreen<br/>CalibrationEditor · CalibrationControls]
    Cam[CameraScreen · CameraView]
    Dbg[DebugTargetScreen · DebugLocatorScreen]
  end
  subgraph Providers["Wiring (lib/providers.dart)"]
    P1[liveCameraProvider]
    P2[calibrationProvider]
    P3[targetModelProvider · ringBoundaryRadiiProvider]
    P4[authServiceProvider]
  end
  subgraph Camera["Camera (lib/camera)"]
    LC["LiveCamera: camera plugin, back camera, no audio"]
    CF[CameraFrame · CameraSource · frameRotation]
  end
  subgraph Vision["Vision (lib/vision) - pure Dart"]
    LIF[locateInFrame]
    F2R[frameToRgb]
    BTL[buildTargetLocator]
    C2F[CoarseToFineLocator]
    CNL[ContrastNormalisingLocator]
    CRL[ColourRingLocator]
    TC[TargetCalibration]
    TM[TargetMapping]
    SYN["SyntheticTarget · SyntheticScene · PhotoBoardTexture<br/>(test data)"]
  end
  subgraph Scoring["Scoring (lib/scoring) - pure Dart"]
    TMod[TargetModel · TargetPoint · LineTouchRule]
  end
  subgraph Game["Game (lib/game, lib/scoring/game_session.dart)"]
    TW["ThrowWatcher: camera → MotionDetector → ThrowTracker → entry"]
    TT["ThrowTracker - pure"]
    GS["GameSession - pure: rounds of 3"]
  end
  Auth["Auth (lib/auth): AuthService interface, no provider yet"]

  Home --> Play[PlayScreen] & Cal & Cam & Dbg
  Play --> TW --> TT
  Play --> GS
  Cal --> P1 & P2 & P3
  Cam --> P1
  P1 --> LC --> CF
  Cal -- "compute()" --> LIF --> F2R & BTL
  BTL --> C2F --> CNL --> CRL
  Cal --> TC --> TM --> TMod
  P3 --> TMod
  P4 --> Auth
```

**Rules:**
- `lib/vision` and `lib/scoring` have **no Flutter imports**. They run in background isolates and in tests on a PC.
- Vision depends on the camera layer's **data** types (`CameraFrame`) only, never on the camera plugin.
- Heavy work (frame conversion, ring finding) runs off the UI thread via `compute`, using top-level functions and plain data. See [[Known Issues]] → Isolate Fails.

See [[Data Flow]] for one frame's path to a score, and [[Glossary]] for the component → function tree and terms.
