# Story Checkpoint: Record and Share

## Story Goal
Both modes are **recorded** and can be **shared with the phone's share sheet**, with the **scoring overlays drawn on**: the rings, each throw's score, the times, the winner. Nigel, 2026-10-15: "start on record and share". Backlog #11. Builds on [[story-checkpoint-live-quick-draw]] (built; its device check by Nigel's brother is still to come).

## Complexity Score
8 (Large): UI → camera → game → a new native video layer on both platforms (4), the microphone permission (1), a new native plugin and Gradle dependencies (1), two modes with different clips (1), more than 3 acceptance criteria (1).

## Status
PAUSED before starting (2026-10-15). Nigel: "I need to get my brother to test before we go further". So this waits for his brother's live Quick draw check ([[Device Test Plan]] → Quick Draw Checks, on TestFlight 1.0.0+7). After that: Nigel approves the plan and answers the three open questions below. No code yet.

## Decisions (Nigel, 2026-10-15, from backlog #11)
- Overlays are **composited after recording**: the camera's own video plus a timeline of scoring events, drawn on when sharing by **AVFoundation on iOS** and **Media3 on Android**. **No FFmpeg.**
- **Play records each throw as a short clip.**
- **Sound from the microphone.** This is a new permission: Android's `RECORD_AUDIO` is removed on purpose today, and the iOS microphone text says the app records no sound. Both change, so the Review Agent runs first.
- Sharing uses the phone's share sheet (`share_plus`).
- **Privacy:** recordings of people stay on the phone until the user shares them.

## What the Code Allows (checked 2026-10-15)
- `camera` 0.12.1: `startVideoRecording(onAvailable:)` records **and** streams frames for scoring, on iOS (`camera_avfoundation` 0.10.3+1) and Android (`camera_android_camerax` 0.7.5+1). **But the recording and the frame stream start and stop together**, and `stopVideoRecording` stops the stream. So a recording can't be started and stopped per throw without a gap in scoring. Hence open question 1.
- `LiveCamera` opens with `enableAudio: false` today. Recording sound means opening with `enableAudio: true`, which asks for the microphone. If the user says no, the video is recorded without sound; the camera still works.
- **iOS share sheet → "Save Video"** needs `NSPhotoLibraryAddUsageDescription` in `Info.plist`. Without it the app is closed by iOS when that's tapped. It's added in Task 1, with the Review Agent.
- **The Swift side can only be compiled on the Mac.** This PC can write it but not build it, so each task with native iOS code ends with a Mac handover step (build, run on Nigel's iPhone). The Kotlin side builds here.

## Open Questions (for Nigel, with recommendations)
1. **How Play gets a clip per throw.** **Recommended: record the whole game as one video, and cut each throw's clip from it when sharing** (from about 2 s before the knife lands to 1.5 s after). Scoring never stops, and the clips are cut exactly. The cost is phone storage: about 100 MB per 10 minutes at 720p and 60 fps, deleted when you leave Play. *The alternative,* starting and stopping a recording around each throw, can't work: the camera plugin stops the scoring frames whenever it stops recording, and nobody knows when the next throw is coming.
2. **Where the overlay is drawn.** **Recommended (architectural): draw it once, in Dart, with the same painters as the screen** (`BoardsPainter`, `TargetPainter`, the result panel). Each event becomes a transparent picture with a start and end time. The native side only places timed pictures over the video, trims it and saves it, so it's about 150 lines each in Swift and Kotlin. It can be tested here and looks the same on both phones. *Easy-looking alternative:* draw the text and rings natively in Swift and in Kotlin. That's two copies of the drawing to keep matching, and neither can be tested without a phone.
3. **How long recordings are kept.** **Recommended: until you leave the screen.** Quick draw keeps this visit's duels, so you can share any of them; Play keeps the current game. Nothing goes to Photos or anywhere else unless you share it. A saved-recordings list could come later.

## Acceptance Criteria
1. Quick draw records each duel from **Start** to the result, with sound, while still timing every frame. Play records the game.
2. After a duel, **Share** opens the share sheet with a video showing the boards' outlines, the lights and **GO!**, each thrower's time and score as their knife lands, and the result.
3. In Play, any throw can be shared as a **short clip**: its score appears as the knife lands, with the round so far.
4. If the microphone is refused, the video has no sound and everything else works. If the camera can't record (an old phone), scoring still works and **Share** isn't offered.
5. Recordings stay in the app's own storage until shared, and are deleted when the screen closes.
6. Same on iOS (AVFoundation) and Android (Media3), with no FFmpeg.
7. The in-app instructions say that sound and video are recorded, and ask throwers to check that others in the shot don't mind being filmed before sharing.

---

## Task 1: Record while scoring, and share the plain video
- **Status:** NOT STARTED
- **Setup:** the live Quick draw story is built.
- **Work:**
  - `LiveCamera` gains `startRecording()` / `stopRecording() → RecordedVideo`. Recording starts the frame stream with `startVideoRecording(onAvailable:)`, so the frames keep coming. It also records when the video started on the camera's clock (`now`), which later lines up the overlay events with the video.
  - The camera opens with sound; if the microphone is refused, it records without sound.
  - Platform config: `RECORD_AUDIO` back in `AndroidManifest.xml`. In `Info.plist`, an honest `NSMicrophoneUsageDescription` and a new `NSPhotoLibraryAddUsageDescription`. `share_plus` in `pubspec.yaml`. **Review Agent first.**
  - Quick draw records from Start to the result. A plain **Share** (no overlay yet) after the result.
- **Verify:** on a phone, run a duel, tap Share, and send the video to yourself. It has the beeps on its sound track, and the result still comes as before.
- **Next:** Task 2.

## Task 2: The overlay timeline, drawn in Dart
- **Status:** NOT STARTED
- **Work:**
  - `ShareTimeline` (pure Dart): the events with their times on the video's clock. For Quick draw: the boards locked, each light, go, each throw (impact, time, score or bounced), the result. For Play: each throw and the round totals.
  - `OverlayFrames`: each overlay state drawn with the existing painters into a transparent picture (PNG) at the video's size, with a start and an end time.
- **Verify (no phone needed):** Live test → Quick draw (the recording of Mark's duel) gets a **Preview share** toggle that draws the sharing overlay over the playback. Check it against the real duel on this PC: Player 2's 0.82 s appears as his knife lands.
- **Next:** Task 3.

## Task 3: Put the overlay on the video, natively (iOS and Android)
- **Status:** NOT STARTED
- **Work:**
  - `VideoComposer` (a Dart interface) on a `MethodChannel`: `compose(video, from, to, layers) → file`.
  - iOS (`AppDelegate.swift`): `AVMutableComposition` (trim) plus `AVVideoCompositionCoreAnimationTool`, with one `CALayer` per picture shown for its time span.
  - Android (`MainActivity.kt`): Media3 `Transformer` with `ClippingConfiguration` and a `BitmapOverlay` per picture, adding the `media3-transformer` and `media3-effect` dependencies in Gradle. **Review Agent.**
  - A fake composer for tests.
- **Verify:** Quick draw's Share now sends the video with the overlay drawn on. Android here first; iOS after the Mac build.
- **Next:** Task 4.

## Task 4: Quick draw sharing, finished
- **Status:** NOT STARTED
- **Work:**
  - "Preparing video…" while the composer runs, and Share stays usable during it.
  - If composing fails, offer the plain video instead.
  - The visit's duels listed, so any of them can be shared.
  - Recordings deleted when the screen closes.
  - What happens when the phone runs low on storage.
- **Verify:** three duels, share the second; leave and come back, and the recordings are gone.
- **Next:** Task 5.

## Task 5: Play: a clip per throw
- **Status:** NOT STARTED
- **Work:**
  - Play records the game. Each scored throw keeps its time on the video's clock.
  - Tapping a throw's score (in the round line or the game list) offers **Share this throw**: a clip from 2 s before impact to 1.5 s after, with the rings, the score as it lands and the round so far.
  - The recording is deleted when Play closes.
- **Verify:** a few throws on a printout; share the second throw's clip and watch its score appear as it lands.
- **Next:** Task 6.

## Task 6: Instructions, docs, device checks, traceability
- **Status:** NOT STARTED
- **Work:**
  - The in-app instructions: what's recorded, sharing, and asking others in the shot before sharing.
  - Updates to Design Decisions, the Glossary, the diagrams, Known Issues and Common Tasks.
  - Device Test Plan → **Record and Share Checks** for Nigel and his brother.
  - A Mac handover for the Swift build and TestFlight.
  - The Traceability Agent.
- **Verify:** Nigel reads the instructions in the app; the checks are ready for the next TestFlight build.

---

## Plan Changes Log
- **2026-10-15:** Planned. Waiting for Nigel's approval and answers to the three open questions.
- **2026-10-15:** Paused until Nigel's brother has tested live Quick draw.

## Notes
- **Clock alignment:** the video's start is taken as the camera clock when recording starts. Frames are stamped when they reach Dart (Known Issues), so the overlay may be a frame or two off the picture. That's fine for a score appearing; it doesn't change the times shown, which come from the frames.
- **iOS audio session:** recording sound changes the phone's audio settings, which could send the start beeps to the earpiece instead of the speaker, or stop them ducking other apps. This goes on the device checks in Task 1.
- **Not in this story:** saving recordings between visits, uploads, and live streaming.
