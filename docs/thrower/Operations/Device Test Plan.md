# Device Test Plan

Real-phone checks of the target calibration and throw detection stories, for Nigel's brother to run **on an iPhone, remotely, from a TestFlight build** (2026-10-08). The interactive version records each step's result for Nigel and Claude to read:

**https://claude.ai/artifact/ScmvKRs7GPj7QfTnwxWpW2** ("Thrower Field Test"; results in its `results` collection, one document per step id: `status`, `fields`, `note`, `updated`).

The page is private until Nigel shares it. **Share it with the tester as a Contributor** (he needs a claude.ai sign-in) so his results save to it. Otherwise share it by link: he can read it, the page keeps his answers on his phone, and he sends them with **Copy results** in a message.

## iPhone Notes

- **Install via TestFlight** (the tester is remote), as an **internal tester** (Nigel, 2026-10-08: immediate access, no beta review): Nigel adds him in App Store Connect with a limited role and access to this app only, then to an internal TestFlight group ([[Common Tasks#Ship a Build to TestFlight (Remote iPhone Testers)]]). He accepts two emails (App Store Connect, then TestFlight) and installs from the TestFlight app. Step S0 records the build number.
- **Release build:** no frames/s label, error detail or frame dump (all debug-only). C1 asks whether the picture is smooth instead.
- **Evidence:** **screenshots sent with TestFlight's *Share Beta Feedback*** at F1, K1, P1 and on any failure; they arrive in App Store Connect → TestFlight → Feedback, with any crash reports.
- **Biggest iPhone risk:** frame orientation (rings rotated or mirrored relative to the preview); F1 asks this explicitly.
- Auto-Lock off while the phone is propped.

## Setup

A4 printout at 100% (`reference/printable/target-A4.pdf`), taped flat at chest height. Phone **about 50 cm away at ~45°**, propped still: that's how the app sees an 80 cm board from 2 m. **A grey pen pushed into Blu Tack** (sticking out ~10 cm) stands in for a knife. Nothing is thrown at the printout.

## Steps and What They Verify

| Part | Steps | Checks | Requirements |
|---|---|---|---|
| S: Set up | S0–S3 | print scale (100 mm bar), placement recorded | — |
| C: Camera | C1 camera prompt, picture smooth?; C2 swipe up and return | camera permission, preview, lifecycle | setup R4 |
| F: Find the target | F1 find (confidence, ms, rings line up or turned/mirrored, screenshot); F2 ×3 repeat; F3 dim light; F4 at 1 m; F5 adjust and lock; F6 tap-to-score 5…0 | ring finder, coarse-to-fine, dim-light fallback, adjust/lock, mapping | calibration C1–C6, C8 |
| W: Watching | W1 still 20 s (false motion count); W2 wave → bounced off; W3 hand held → blocked → board visit | motion detector, blocked state, classifier | throw T-R1, T-R2 |
| K: Pen knives | K1–K3: ring by eye vs app score, dot distance from the pen tip (one near a line) | entry point, scoring | T-R3, calibration C5 |
| P: Play | P1 round of 2 sticks + bounce; P2 collect → round 2; P3 fall-out (optional); P4 speed | game session, tracker, play screen | T-R4, T-R5, T-R6 |
| R: Real board (later) | R1 calibrate at 2 m / 45°; R2 two rounds, by eye vs app | the real thing | all |

Safety: with a real board, the phone and stand sit outside the throwing lane; the phone and the board are only approached when no one is throwing.

## When Results Come Back

Read them with `ArtifactData` `list` on the artifact's `results` collection, or from the pasted "Copy results" text. Also check App Store Connect → TestFlight → Feedback for his screenshots and crash reports. Record failures in [[Known Issues]] and as fixes. For a calibration failure, use his screenshot; if it needs the exact analysed frame, reproduce with a debug build attached to the Mac.
