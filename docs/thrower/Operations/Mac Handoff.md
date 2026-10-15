# Mac Handoff: Current State, App Store Setup and Committing

Written 2026-10-09 for **Claude Code on Nigel's Mac**; latest handover 2026-10-15 (section 0). Nigel will ask you to read this file. Work through it with him. CLAUDE.md and `docs/working-with-nigel.md` load automatically and their rules apply here too, above all the commit rules (below).

Related: [[Common Tasks]] → Ship a Build to TestFlight (the checklist this expands), [[Device Test Plan]], [[backlog]], [[Known Issues]].

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

| Change | Commit? |
|---|---|
| Dart / Flutter code (`lib/`) | **Only when Nigel says "commit this"** (he tests first) |
| Tests | Yes, together with the code they test |
| Config / platform (`ios/`, `android/`, `pubspec.yaml`) | Yes, **after** the "Be Careful" Review Agent checklist (`docs/agents/review-agent/review-agent.md`) passes. Show Nigel the Safety Report |
| Docs (`docs/`) | **No, leave unstaged**, unless Nigel asks |
| `.claude/`, CLAUDE.md | Yes |

**On the Mac, this will usually mean:**
- The **signing change** (`ios/Runner.xcodeproj/project.pbxproj`, team ID added) is a config change. Run the Review Agent checklist: identity unchanged (bundle ID still `nz.nrbond.thrower`), no secrets, only team lines changed. Then commit it, e.g. `iOS: set the signing team for TestFlight`.
- The **build-number bump** in `pubspec.yaml` is a config change. Commit it with the upload, e.g. `Build 1.0.0+2 for TestFlight`.
- Never commit `build/`, `.ipa` files, certificates, provisioning profiles or the tester's email.

**Every commit message ends with:**
```
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```
Branch: `main` only. Then `git push origin main`. Nigel's Windows PC pulls the same repo, so pull before starting each session, on either machine.
