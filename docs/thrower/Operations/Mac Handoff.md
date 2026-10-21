# Mac Handoff: Current State, App Store Setup and Committing

Written 2026-10-09 for **Claude Code on Nigel's Mac**; latest handover 2026-10-19 (section 0000); since build 9, section 000000 (2026-10-21). Nigel will ask you to read this file. Work through it with him. CLAUDE.md and `docs/working-with-nigel.md` load automatically and their rules apply here too, above all the commit rules (below).

Related: [[Common Tasks]] → Ship a Build to TestFlight (the checklist this expands), [[Device Test Plan]], [[backlog]], [[Known Issues]].

---

## 000000. Since Build 9 (2026-10-21): for a Future Build 10

Build 9 went out from the Mac on 2026-10-21 (`2b14cab`, "Build 1.0.0+9 for TestFlight"). Nothing below needs doing until Nigel wants build 10; then section 00's steps with **`1.0.0+10`**, and add the build to the External testers group.

### What's in it since build 9 (from the PC, pushed to `main`)
- **Round or four-cornered boards** in Quick draw ([[story-checkpoint-board-outlines]], Nigel 2026-10-21): a board drawn round by finger becomes an oval if it looks round, or **four corners** if it looks square or rectangular, the corners where they were drawn (as the camera sees the board). Throw detection watches the board's own shape, so a knife in a corner counts. Corners can be dragged in Adjust boards (an outline can't be folded). Commits `f378009`, `bdf39f1`, `f645b09`.
- **No new plugins, permissions or assets.** `flutter test`: 948 pass on the PC (2026-10-21).

### Then
Checks to send: [[Device Test Plan]] → Drawn Board Checks → Round or Four-Cornered Boards (**QA8–QA14**), with whatever of QA0–QA7 is still to do from build 9.

---

## 00000. Accounts on the Mac (2026-10-19): before any build with sign-in

From [[story-checkpoint-app-user-accounts]]. Build 9 can still go out without accounts: without the settings file, the app runs signed out exactly as before.
1. `git pull`, then `npm install` (once) and `flutter pub get`. **`cd ios && pod install`**: Amplify adds pods (iOS 15 is fine; Amplify needs 13).
2. **The backend's settings for the build:** `AWS_REGION=eu-west-2 npx ampx generate outputs --app-id d1yhmpx84pdvnh --branch main --out-dir assets/config` (gitignored; [[Common Tasks]]). **Leave it out** for a build that should have no accounts.
3. **Xcode (in the foreground, Nigel clicking):** Runner → Signing & Capabilities → **+ Sign in with Apple**. This makes `Runner.entitlements` and `CODE_SIGN_ENTITLEMENTS` in Debug, Release and Profile; WhereWillWeVisit needed all three. Commit them.
4. Before any App Store build: the privacy policy published and linked ([[Privacy Policy (Draft)]]); the privacy labels; check the Sign in with Apple button meets Apple's style (WhereWillWeVisit was rejected under Guideline 4).

## 0000. Handover 2026-10-19: TestFlight Build 1.0.0 (9), the Quick Draw Match

**Start here** when Nigel wants build 9 (build 8 went to Beta App Review on 2026-10-19: `06104c8`, `dd40600`). Section 00 has the steps; do them with **`1.0.0+9`** in place of `+7`, commit the bump as e.g. `Build 1.0.0+9 for TestFlight (Quick draw match)`, and **add the build to the External testers group** ([[Known Issues]]: builds of the same version often skip review).

### What's in it since build 8 (from the PC, pushed to `main`)
- **Named players** ([[story-checkpoint-named-players]], 2026-10-19): a name for each player on Play's setup screen (optional, at most 16 letters, kept on the phone); Play, two-target Play, History and Quick draw use them; Quick draw has a **Names** button. The history file becomes **version 2** (names); version 1 files still read. New file `player_names.json` beside the history. **No new plugins or permissions** (`path_provider` was already there).
- **The live Quick draw is a match of three rounds** ([[story-checkpoint-quick-draw-match]], from Nigel's brother's rules): the first to stick wins a round; a bounce-out or false start loses; **the same frame → the higher score wins**, the same score → a drawn round. All three rounds are thrown; level after three → **Extra round** until one is won. **Next round**, **Finish match** (asks first), **New match**. The panel shows "Round 2 of 3", the round's winner and "Player 1 leads 1–0", then "Player 1 wins the match 2–1" in green.
- The Instructions name the scoring **KATTA** (the same rings and line rule as before; `TargetModel.katta`).
- **Adjust each board** ([[story-checkpoint-adjust-boards]], backlog #10, 2026-10-19): on Quick draw and two-target Play, either board's outline can be dragged into place before locking; **Adjust boards** unlocks them, keeping both.
- **No new plugins, permissions or assets.** `flutter test`: 766 pass on the PC.

### Also in it since then (updated 2026-10-21): Nigel wants build 9 for Mark
Nigel (2026-10-21): rather than ask Mark for better videos, give him **the latest version**. Mark's screen recordings on build 8 ([[story-checkpoint-gapped-rings]] → Follow-up): scores mostly right, but one stuck knife missed, one stuck knife called a bounce-out, and on his stencilled boards Quick draw's outlines sometimes at the wrong size (backlog #20).
- **Adjust boards** (above) is the immediate help for Mark: if an outline doesn't sit on the painted rings, drag it into place before locking.
- **More game types** ([[story-checkpoint-more-game-types]]): **Which game?** on Play's setup: Scoring, **Precision** (7 rounds from 3, 5, 7, 3, 4, 5, 7 m) and **Three targets**, both scored by hand on a score pad. History record **version 3** (written only once a new-type game is kept).
- **Tap the board** in Calibrate ([[story-checkpoint-gapped-rings]]): when Find target can't find the rings (Mark's stencilled boards), tap the board's middle; the ring finder's new fallback reads gapped rings from there. (Quick draw's own taps get the fallback too.)
- **Draw round the boards** in Quick draw ([[story-checkpoint-quick-draw-areas]], Mark's request, 2026-10-21): instead of tapping, draw a finger round each board on the screen; any knife that sticks inside counts, timed only (no score), and the same frame is a drawn round. The workaround for his boards' outlines at the wrong scale (backlog #20). Both Quick draw screens, not two-target Play. **No new plugins or permissions.** `flutter test`: 899 pass on the PC (2026-10-21).
- **Accounts** ([[story-checkpoint-app-user-accounts]]): sign-in (email, Google, Apple) and the backup, on AWS London. **A choice for Nigel:** build 9 **without** the settings file runs signed out exactly as before (simplest for Mark; no Xcode capability needed); **with** it needs section 00000 first (`pod install`, Sign in with Apple capability). Either way `pod install` is needed: the Amplify plugins are in `pubspec.yaml`.
- **Plugins since build 8:** `amplify_flutter`, `amplify_auth_cognito`, `amplify_api`, `amplify_authenticator` (pods). Permissions: none new on iOS (Android gained INTERNET for release builds). `flutter test`: 875 pass on the PC (2026-10-21).
- **Checks to send Mark** (with QM, N and A above): [[Device Test Plan]] → Board Finding Checks **BF8** (his real boards), **Drawn Board Checks** (QA0–QA7, and the real-boards line), and the Game Type Checks (GT0–GT9) if he plays them.

### Then
Nigel sends his brother [[Device Test Plan]] → **Quick Draw Match Checks** (QM0–QM6), **Named Players Checks** (N0–N6) and **Adjust Boards Checks** (A0–A5), with whatever of Q0–Q8, M0–M9, H0–H7 and C0–C7 is still to do from build 8.

---

## 000. Handover 2026-10-16: TestFlight Build 1.0.0 (8), Players and Targets

**Start here** (when Nigel wants build 8; nothing else is pending on the Mac). Section 00 below has the steps; do them with **`1.0.0+8`** in place of `+7`, and commit the bump as e.g. `Build 1.0.0+8 for TestFlight (players and targets)`.

### What's in it since build 7 (all from the PC, pushed to `main`)
- **Play for 1 or 2 players** ([[story-checkpoint-players-and-targets]]): Home → Play opens a setup screen (1 or 2 players; for 2, 1 target taking turns or 2 targets at once). Two targets: tap and lock both boards, as in Quick draw. Live test → **Play on two targets** plays the Quick draw recording that way.
- Live Quick draw: **no GO! on screen**; the long, higher beep is the signal.
- The recording's Quick draw: Play shows only once the boards are locked.
- Docs: the architecture web pages (`docs/web/`).
- **Game length** (2026-10-16): 3, 5 or 9 rounds on the setup screen.
- **Game history** (2026-10-17, [[story-checkpoint-game-history]]): finished games of Play are kept on the phone; Home → **History**. **Finish game** on Play ends a game after fewer rounds. **Score corrections** ([[story-checkpoint-score-corrections]]): tap a score on Play for a 0–5 popup, or an empty slot to add a missed throw; afterwards the app checks the phone didn't move. `path_provider` is now listed in `pubspec.yaml`, but it was already in the app through `audioplayers` at the same version (2.1.6), so **no Podfile or native change**: `pod install` should report nothing new.
- **No new plugins, permissions or assets.** `flutter test`: 667 pass on the PC (`git pull`, then `flutter test` as in section 00).

### Then
Nigel sends his brother [[Device Test Plan]] → **Players and Targets Checks** (M0–M9) and **History Checks** (H0–H7) and **Score Corrections Checks** (C0–C7), as well as the Quick Draw Checks (Q0–Q8, still to do). Q3 now asks about the long beep only.

---

## 00. Handover 2026-10-15 (evening): TestFlight Build 1.0.0 (7) for the Live Quick Draw

Section 0 below is the morning's handover (the recording's Quick draw on Nigel's iPhone), kept as history. Section 000 above is the latest.

### Why
The **live** Quick draw is built (story [[story-checkpoint-live-quick-draw]], all 5 tasks), but Nigel can't test the live camera himself: **his brother tests it on his iPhone from TestFlight**. So this build goes to the **Field testers** group. Nothing else is pending on the Mac.

### What's in it (all from the PC, pushed to `main`)
- **Home → Quick draw** (new button; **Play** is still rounds on one target): the live camera full screen; tap Player 1's bull, then Player 2's, **Lock boards**; a starter taps **Start**: 5 beeps with 5 lights, a random 1.0–3.0 s pause, the long, higher "go" beep as the lights go out (no GO! on screen since 2026-10-16: build 7 still shows it); both boards analysed on every frame from 1 s before go (60 fps asked for); the result in large type with a chime ("Player 2 wins", each time after go and score); **Next duel**, **Stop**, **Choose boards again** (renamed from "Start again").
- Backlog #12: Play shows the next round as soon as the knives are collected.
- **No new plugins or permissions.** `pubspec.yaml` adds only the asset folder `assets/sounds/` (three WAVs, ~60 KB, from `tool/make_signal_sounds.dart`); `audioplayers` was already there, so **`ios/Podfile.lock` shouldn't change** (if it does, look before committing). The camera now asks for 60 fps (`LiveCamera.open(fps: 60)`), a Dart-side setting.
- `flutter test`: **471 pass** on the PC.

### Steps (iOS work in the foreground, in Xcode: `docs/dont-ask-again.md`)
1. **Claude:** `git pull` (expect the live Quick draw commits on top of `da00c7e`), `flutter pub get`, `flutter test` (471; the replay tests take ~2–3 min).
2. **Optional, Nigel:** a quick **debug** run on his own iPhone from Xcode before uploading: Home → Quick draw opens the camera, and **Start** plays the beeps (the review found and fixed a bug where they'd never play; this is the first time they run on a phone). Debug builds also show the frames/s label and the per-board debug line.
3. **Claude:** bump `pubspec.yaml` to **`version: 1.0.0+7`** (`+6` was the last upload), then `flutter build ios --config-only --release`, then `open ios/Runner.xcworkspace`.
4. **Nigel, in Xcode:** destination **Any iOS Device (arm64)** → **Product → Archive** → Organizer → **Distribute App → App Store Connect → Upload**.
5. **Claude:** confirm from the Xcode logs (`$TMPDIR/*.xcdistributionlogs`) and App Store Connect (processing, then available to **Field testers**); commit the bump, e.g. `Build 1.0.0+7 for TestFlight (live Quick draw)`, and `git push origin main`.
6. **Nigel:** check the brother is in **TestFlight → Field testers** in the **new** team (QCQ64RLD77; see [[Known Issues]] → the old-team note), then send him the checklist: [[Device Test Plan]] → **Quick Draw Checks** (Q0–Q8). Two A4 printouts side by side and pens are enough for Q0–Q7; **Q8, real knives, has its own safety rules** (separate lanes, a third person as starter, nobody forward until both have thrown).

### Worth knowing
- **A TestFlight build is a release build:** no frames/s label or debug line, so the checklist only asks what he can see: do the two times differ, can the beeps be heard at the throwing line, is the result readable from 4 m, does the phone get hot over 10 duels, and does it say "Some frames were skipped" on a result.
- **Sound on iOS:** the first beep may start a little late (iOS has no low-latency player mode); "go" is timed when the go beep is asked to play, so both throwers' times include the same delay. Q3 asks whether the lights going out and the beep line up.
- **Not for the App Store yet:** the Live test recordings (~87 MB, people in the footage): [[backlog]] #6.

### Next (either machine)
When the brother's results come back: record them in [[story-checkpoint-live-quick-draw]] and [[Known Issues]], fix what fails, then archive the story. After that: backlog #11 **Record and share** (decisions already taken there).

---

## 0. Handover 2026-10-15: Try Quick Draw on the iPhone

**Start here.** Sections 1–3 below are from 2026-10-09: the TestFlight setup and commit rules still apply, but section 1's "current state" is out of date. This section is what's new.

### What's changed since 2026-10-09
- **Live test** (Home → *Live test*): plays recordings of two real boards (Nigel's video) in place of the camera, through the normal calibrate → Play screens. Target 1 / Target 2. Archived story: [[story-checkpoint-live-test]].
- **Quick draw** (Live test → *Quick draw*), story [[story-checkpoint-quick-draw]], **Tasks 1–3 of 5 done**:
  - Two throwers, one board each, throwing at the same time after a countdown. The clip (`assets/live/quickdraw.tfrm`, 720 × 1280 at **60 fps**, with sound `quickdraw.m4a`) plays full screen, system bars hidden.
  - Tap the centre (bull) of **Player 1's board**, then **Player 2's**: each is outlined and numbered. **Lock boards**, then **Play**.
  - While it plays, each board gets its time (seconds into the clip) and result underneath: right board (Player 2, Nigel's brother Mark) about **"3.62 s · 5"**, left board (Player 1) about **"3.65 s · bounced"**. The knives land **2 frames (about 33 ms) apart** on the video (the answer key, `docs/thrower/reference/live-camera/quickdraw.json`).
  - The winner, false starts and timing from "go" (2.8 s into the clip) are **Task 4, not built yet**.
- **New native plugin: `audioplayers` ^6.8.1** (plays the clip's sound). No new permissions or `Info.plist` keys. It needs iOS 13 (the project targets 15.0). The sound **ducks** other audio (music gets quieter, not stopped) and plays with the **silent switch on**, so the countdown is heard.
- Commits: `6ec8721` (code, tests, clip) and `022e35b` (docs), plus this handover. `flutter test`: **373 pass** on the PC.

### Steps
1. **Claude:** `git pull` (check `git log --oneline -4` shows `6ec8721` and `022e35b`), `flutter pub get`, `flutter test` (expect 373 passing; the replay tests take ~2 min).
2. **Claude:** `flutter build ios --config-only --debug` or let the first run do it: CocoaPods installs the audio plugin's pod and **`ios/Podfile.lock` changes**. That's expected.
3. **Nigel, in Xcode** (settled rule: iOS work is done visibly in Xcode; see `docs/dont-ask-again.md`): `open ios/Runner.xcworkspace`, choose his iPhone, **Run** (a **debug** build: the frames-per-second label only shows in debug builds). Or `flutter run` with Xcode open.
4. **Nigel, on the iPhone:** Home → *Live test* → *Quick draw* → tap the left bull, then the right bull → *Lock boards* → *Play*. Note:
   - the **frames/s label** (top right of the picture) while it plays: the Samsung A06 managed **11–12**, so some runs gave both players the same time;
   - whether the two times **differ** (they should, by about 0.03 s, if it keeps up with 60 fps);
   - the scores under each board (right: 5; left: bounced);
   - the **sound**: heard with the silent switch on; music playing in another app gets quieter, then comes back.
5. **Claude:** record the results in [[story-checkpoint-quick-draw]] (Task 3 notes) and [[Known Issues]] → Quick Draw: Dropped Frames Make Times Coarser.
6. **Claude:** commit the changed **`ios/Podfile.lock`** after a quick "Be Careful" check (only the audioplayers / path_provider pods added; the Task 1 Safety Report in the story file already passed the plugin). E.g. `iOS: Podfile.lock for audioplayers`. Then `git push origin main`.

### Worth knowing
- **Debug builds are slower than release.** The frame rate in a debug build (where the label shows) understates what a release build does: the Dart that watches each board runs unoptimised. Both boards see the same frames, so the **order** is always fair; a slow phone can only turn a win into a tie.
- **No TestFlight upload is needed for this.** If one is wanted later, the next build number is **`1.0.0+6`** (`+5` was uploaded from the Mac on 2026-10-14). Release builds have no frames/s label.
- **Not ready for the App Store:** the Live test recordings are ~87 MB, and the Quick draw clip shows people (full frame, with voices). Fine for internal TestFlight; see [[backlog]] #6 before any public build.
- **Taps:** aim for the bull. Taps 15–30 px off the centre sometimes miss the green-and-red board; *Start again* clears and rewinds ([[Known Issues]] → Quick Draw: a Board Isn't Found).

### Results on the Mac (2026-10-15), handed back to the PC
- Steps 1–3 done: `flutter test` **373 pass** on the Mac; the debug build ran on the iPhone from Xcode. `ios/Podfile.lock` (adds only the `audioplayers_darwin` pod) committed by Nigel as `a454bf7`. `pubspec.yaml` is at **`1.0.0+5`**, so the next TestFlight build is **`+6`** (not `+5` as above).
- **iPhone, Quick draw:** about **42 frames a second**, and the two players "quite often" got the same time.
- **Decision (Nigel):** leave the playback frame rate; the analysis may come back late ("1/2 second later") if every frame is analysed and timed by its place in the clip. Written up as the first part of **Task 4** in [[story-checkpoint-quick-draw]] (Plan Changes Log 2026-10-15) and in [[Known Issues]] → Quick Draw: Dropped Frames Make Times Coarser.
- **Live game, not this story:** 60 fps capture and capture timestamps, added to [[backlog]] #9.
- **Times on screen are clip time, not time from "go":** Nigel saw "3.69 s" and expected about 1.2 s. The line under each board counts from the clip's start (2.8 s before "go"); from go it's about **0.85–0.9 s** (Nigel's by-ear go at 161.3 s; the 1.2 s was the Mac's early guess at go). Task 4 must show time from go everywhere (story, Task 4).

**Handover to the PC (2026-10-15):** Nigel picks up **Task 4** of [[story-checkpoint-quick-draw]] there. Start with `git pull` (latest docs commits: `3c51166`, `0c23a84`, plus this one), then read Task 4 in the story file. It now starts with two additions from today: (1) **analyse every frame in order, timed by its place in the clip, and report late** (playback may still skip frames); (2) **show times from "go"**, not clip time. Then the planned work: false start, the winner rule, the results line. No Xcode or TestFlight work is pending on the Mac; the next TestFlight build would be `1.0.0+6`.

### Next (either machine)
**Task 4** of [[story-checkpoint-quick-draw]]: times from "go", a false start if a knife lands before "go", the winner (the first knife to **stick**; a bounce-out loses; both bounce = no winner), and a results line. In the final, live-camera version the app counts down itself, Formula 1 style (5 beeps, a random pause, a long beep for go): [[backlog]] #9.

---

## 1. Current State (2026-10-09)

**What the app does today.** It's a Flutter app for iOS and Android, bundle ID `nz.nrbond.thrower`, version `1.0.0+1`, private repo `nrbondnz/thrower_app` on branch `main`. The phone sits on a static mount about 2 m from the board at about 45° to the side.
1. **Calibrate:** *Find target* locates the 5 painted rings (any two alternating colours). The user can drag to adjust, then locks it.
2. **Play:** the app watches the board. For each throw it decides *stuck*, *bounce-out* (0), *board visit* (someone collecting knives, which ends the round), *fell out* (that throw becomes 0) or *view changed*. For a stuck knife it finds where the blade went in and scores 5 (inner ring) down to 1. A round is 3 throws.

**Stories:**

| Story | State |
|---|---|
| Setting up the throwing app | Done (archived) |
| Target calibration | Done (archived) |
| Throw detection and scoring | Done (archived) |
| Next | None active. Choose from [[backlog]] (scoring rules, accounts, game modes, store hygiene, axes) |

**Tested on a device** (Android, Samsung A06, with the A4 printout of the target):
- Target finding works: 5 out of 5.
- Throw watching was flaky. The phone was propped on a sofa arm, and tiny camera movements read as "someone at the board". **Fixed in `b4a754a`**: frames are re-aligned before comparing, so camera nudges are ignored, and a knife or pen placed by hand now scores. That fix hasn't been re-tested on the phone yet.

**Never tested on a device:**
- **iOS at all.** This is the main reason to get TestFlight going: frame orientation on the iPhone is unverified.
- A **real board with real knives.** Nigel has neither yet, and the A4 printout with a pen only goes so far. Everything about real throws has only been checked on rendered test sequences (`tool/render_throw_sequences.dart`).
- The fell-out rule is still assumed (a knife that falls out before collection scores 0). Nigel hasn't confirmed it.

**Waiting on:**
- a real board (75–85 cm, 5 rings) and knives, or
- Nigel's brother testing on his iPhone through **TestFlight** as an **internal tester**. He follows [[Device Test Plan]], and the results page is linked there. That needs the App Store setup in section 2.

**Code:** `flutter analyze` is clean and `flutter test` passes 211 tests (pure Dart; no device needed).

---

### Progress on the Mac (2026-10-09)
- Flutter on the Mac upgraded to **3.47.7** (Dart 3.13.5). 3.47.5 fails `pub get` against `sdk: ^3.13.5`.
- Signing: team **QCQ64RLD77** ("Nigel Bond", the paid Individual team, not the free Personal Team), automatic signing (`b560803`).
- **First iPhone test:** *Find target* drew the outline in the wrong place. iOS frames arrive already upright and were being rotated again. Fixed in `252127c` and confirmed on Nigel's iPhone. See [[Known Issues]] → iPhone: Target Outline in the Wrong Place.
- **App Store Connect:** the app record is **"Knife and Axe Thrower"** ("Thrower App" is taken by another account), Apple ID `6820805327`, bundle `nz.nrbond.thrower`. Xcode created it during *Distribute App*. The home-screen name is still "Thrower App" (`CFBundleDisplayName`).
- **Build 1.0.0 (1)** uploaded and processed. Internal group **"Field testers"** (automatic distribution) created; Nigel added. **The tester (Nigel's brother) is not invited yet**: invite him in Users and Access, then add him to the group. Build **1.0.0 (2)** (instructions, 9-round games, reset) uploaded 2026-10-09 21:25; **1.0.0 (3)** archived from the same code. Build **1.0.0 (4)** (Camera and Ring finder test screens removed) archived 2026-10-10. **Next upload must be `1.0.0+5`.**

## 2. App Store / TestFlight Setup

Some steps need **Nigel**: the Xcode GUI, logging in with his Apple ID, and the App Store Connect website. Claude can't do those. Tell him what to click, and wait for him. Steps marked **Claude** you can run yourself.

### 0. Prerequisites (check first)
- **Claude:** `xcodebuild -version` (Xcode 16 or later), `flutter --version` (Dart 3.13 or later is required by `pubspec.yaml`), `flutter doctor` (fix anything under Xcode, iOS or CocoaPods). `pod --version`, if Flutter asks for CocoaPods.
- **Nigel:** a paid **Apple Developer Program** membership on his Apple ID ($99 USD a year, *developer.apple.com → Account*). TestFlight needs it. If he doesn't have one, stop here: enrolment can take a day or two.
- **Nigel:** Xcode → *Settings → Accounts* → add his Apple ID.

### 1. Get the code
- **Claude:** `git clone https://github.com/nrbondnz/thrower_app.git` (or `git pull` if it's already cloned), then `flutter pub get`, then `flutter test` (expect all to pass).
- **Claude:** `cd ios && pod install` only if `flutter build` asks for it. Flutter normally does it.

### 2. Signing (one-time)
- **Nigel:** `open ios/Runner.xcworkspace` (the **workspace**, not the `.xcodeproj`). In Xcode: *Runner* target → *Signing & Capabilities* → tick **Automatically manage signing** → choose his **Team**. Leave the bundle ID as **`nz.nrbond.thrower`** (it's hard to change once published). Xcode registers it with Apple.
- **Claude:** `git diff ios/Runner.xcodeproj/project.pbxproj` should show `DEVELOPMENT_TEAM = XXXXXXXXXX;` lines added, and nothing else. The team ID isn't a secret.
- Optional sanity check: plug in Nigel's iPhone, if he has one, and run `flutter run --release`.

### 3. App record (one-time)
- **Nigel:** [App Store Connect](https://appstoreconnect.apple.com) → *Apps* → **+** → *New App*:
  - platform iOS
  - a name (it must be unique on the App Store, so try "Thrower App" or a variant; it can change later)
  - primary language English
  - bundle ID `nz.nrbond.thrower` (it appears in the list once step 2 is done)
  - SKU `thrower-app`

### 4. Add the tester (one-time)
The tester is **an internal tester** (decided 2026-10-08), so he gets each build straight away, with no Beta App Review.
1. **Nigel:** *Users and Access* → **+** → the tester's name and email → role **Customer Support** (the most limited) → *Apps*: **this app only** → *Invite*. **Don't write the tester's email into the repo**; Nigel has it.
2. The tester accepts the invitation email.
3. **Nigel:** *TestFlight* → *Internal Testing* → **+** → create a group, e.g. "Field testers", with **automatic distribution** on → add the tester.

### 5. Build and upload (every build)
1. **Claude:** bump the build number in `pubspec.yaml`: `version: 1.0.0+N`, where N is one higher than the last upload. The first upload can stay `+1`.
2. **Claude:** `flutter build ios --config-only --release` (refreshes the version Xcode uses), then `open ios/Runner.xcworkspace`. **All Xcode work happens in the foreground in Xcode** so Nigel can follow it (Nigel, 2026-10-10; see `docs/dont-ask-again.md`).
3. **Nigel**, in Xcode: destination **Any iOS Device (arm64)** → **Product → Archive** → Organizer → **Distribute App → App Store Connect → Upload**. If it fails on signing, step 2 isn't done.
4. Wait 10–30 minutes for *Processing* in App Store Connect. Export compliance is already answered in `Info.plist` (`ITSAppUsesNonExemptEncryption = NO`).
5. With automatic distribution on, the tester gets a TestFlight email. He installs Apple's **TestFlight** app and then Thrower App from it.

### Gotchas
- A TestFlight build is a **release** build: no debug extras (frames/s label, error detail, frame dumps, the watch log).
- `NSMicrophoneUsageDescription` is in `Info.plist` only because the camera plugin links audio APIs and App Store Connect flags that. The app never records sound.
- Builds expire after 90 days.
- "No profiles for 'nz.nrbond.thrower' were found": signing isn't set up. Go back to step 2, and make sure Xcode is signed in with the right Apple ID.

---

## 3. Committing (Nigel's Rules)

- **Dart / Flutter code (`lib/`)**
  - **Commit?:** **Only when Nigel says "commit this"** (he tests first)
- **Tests**
  - **Commit?:** Yes, together with the code they test
- **Config / platform (`ios/`, `android/`, `pubspec.yaml`)**
  - **Commit?:** Yes, **after** the "Be Careful" Review Agent checklist (`docs/agents/review-agent/review-agent.md`) passes. Show Nigel the Safety Report
- **Docs (`docs/`)**
  - **Commit?:** **No, leave unstaged**, unless Nigel asks
- **`.claude/`, CLAUDE.md**
  - **Commit?:** Yes

**On the Mac, this will usually mean:**
- The **signing change** (`ios/Runner.xcodeproj/project.pbxproj`, team ID added) is a config change. Run the Review Agent checklist: identity unchanged (bundle ID still `nz.nrbond.thrower`), no secrets, only team lines changed. Then commit it, e.g. `iOS: set the signing team for TestFlight`.
- The **build-number bump** in `pubspec.yaml` is a config change. Commit it with the upload, e.g. `Build 1.0.0+2 for TestFlight`.
- Never commit `build/`, `.ipa` files, certificates, provisioning profiles or the tester's email.

**Every commit message ends with:**
```
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```
Branch: `main` only. Then `git push origin main`. Nigel's Windows PC pulls the same repo, so pull before starting each session, on either machine.
