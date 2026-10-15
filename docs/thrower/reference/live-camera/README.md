# Live Camera: Real Boards

Two real boards on A-frame stands outdoors at dusk, with knives being thrown and collected, filmed by a phone from the throwing area. Nigel supplied the video.

- **Original** (2026-10-12, `IMG_1628.mov`): portrait 1080 × 1920, 60 fps, 3 min 9.9 s, about 24 Mb/s. Each board is about 245 px across.
- **Copy** (2026-10-11): the same video after a messaging app had compressed it to 464 × 832 at 834 kb/s. Each board was about 106 px across, with a compression "pulse" about once a second. The answer key and the first version of the Live test came from it. It's the same timeline (no offset), and it's the original scaled by 2.31 across and 2.295 down.

| File | Board | Crop in the original (w:h:x:y) | Crop in the copy |
|---|---|---|---|
| `1.mp4` | Left: red rings on wood, dark bull | `322:322:118:535` | `140:140:50:232` |
| `2.mp4` | Right: green and red rings on pale wood | `322:322:723:549` | `140:140:312:238` |

Both files are cut from the **original** (since 2026-10-12): H.264 (CRF 23) with the original audio, made with `ffmpeg -vf crop=…`, about 10 MB each. The copy's crops are in git history. The source `.mov` isn't kept in the repo.

The app's recordings (`assets/live/target1.tfrm`, `target2.tfrm`) are the same crops, packed at 15 fps with JPEG `q:v` 12: 2,848 frames of 322 × 322 px, 25.9 MB each (see [[Common Tasks]] → Make a Live Test Recording).

The **Quick draw** clip (`assets/live/quickdraw.tfrm`, 2026-10-14) is different: the **whole picture**, both boards, at 158.5–166.0 s of the original. Scaled to 720 × 1280 (boards ~163 px across), packed at 60 fps with JPEG `q:v` 20: 449 frames, 34.2 MB. Its sound is a separate asset, `assets/live/quickdraw.m4a` (mono AAC, 93 KB). Commands in [[Common Tasks]] → Make a Live Test Recording; why 60 fps and q20 in [[Design Decisions]] → Live Test.

Useful for: real ring colours (board 2 is a non-red board; see the [[backlog]] carry-over), real knives sticking and being collected, people walking in front, and dusk light. The camera position isn't the app's intended mount (it faces the boards from the throwing area). So use these for colours and events, not for the side-on geometry.

## Answer Key: `truth.json`

What happened on each board, round by round:
- **Throws and scores:** Nigel (2026-10-11). He first judged them from the **copy**. On 2026-10-13 he **re-scored every stuck knife from the original** ("as close as I can get"); each `zone` ends with his score, the video time and any note.
- **Times and places:** Claude, from the copy. The times hold for the original too.
- **Events:** each event has an `id`, a `kind` (`stuck`, `bounceOut` or `visit`), a `time` (s), a `score` and a `round`. A **visit** means people are at the board (collecting), which ends the round.

| Board | Rounds |
|---|---|
| 1 | 4 5 4 · bounce 2 5 · 4 5 bounce · 4 3 4 · bounce · bounce |
| 2 | 5 4 5 · 4 4 bounce · 2 bounce 4 · 5 · 4 |

The original confirms the throws and bounce-outs. For example, board 1's last bounce-out (177.0 s), invisible on the copy, is a knife hitting the top of the board and falling past the bottom. **Scores re-checked against the original** (Nigel, 2026-10-13): all of them, so no knife is left unchecked. This supersedes two corrections made earlier the same day (`b1-t12` and `b2-t02` are 4s). **Nigel's rule** (2026-10-13): "find the solid shape of the knife; score where the blade goes into the wood; a shadow comes from the knife, on the side away from the light". E.g. `b1-t12` "handle end leans into 5" but scores 4; `b2-t10` "the part sticking in is 5".

Nigel then reviewed the app's six misses. Three were his and are changed in the key: `b1-t01` → 4, `b1-t02` → 5, and `b1-t10` → 4 (hidden in the footage, but he watched the thrower pull it out of the 4 ring). The other three are app errors, with his reasons in their zones:
- `b1-t11` (2:17): 3, app 4. "You can see the solid knife shape in the 3"; the app followed its shadow.
- `b2-t02` (1:10): 4, app 5. "Always look for the solid shape of the knife; the shadow is there but it's coming from the knife, the light is to the right on this target."
- `b2-t05` (1:46): 4, app 5. "Below the blade tip there is white, not red, so it's 4."

Against this key the app scores **16 of 19** exactly (Target 1: 9 of 10; Target 2: 7 of 9). All three misses score too high: `faceOnEntry` (pixels nearest the bull) is pulled in by the shadow or by the wrong part of the knife.

Nigel's guidance on entry points (2026-10-13): *"we need the app to focus on finding the entry point. If it's obscured, it's likely the score that you can see, as the knife has gone in directly in line with the camera."* See [[story-checkpoint-entry-point]].

The Live test replay tests check the app's live analysis against this file. The review page (zoomed clips of each event, from the copy) is at https://claude.ai/artifact/1fAKaR23dR8D5DnWkC9WN6.

## Answer Key: `quickdraw.json`

For the [[story-checkpoint-quick-draw]] clip. Times are seconds from the start of the clip (`clipStart` 158.5 s); frame numbers are at 60 fps.
- **Go:** 2.8 s (161.3 s in the original). Nigel, by ear: the countdown is a quiet voice, and the words can't be picked out from the waveform.
- **Impact frames:** Claude, from the 60 fps frames: the first frame a knife reaches its board.
- **Results:** from `truth.json` (`b2-t10`, `b1-t13`).

| Board | Impact frame | Time | Result |
|---|---|---|---|
| Right (Target 2: green and red rings) | 217 | 3.617 s | stuck, 5 |
| Left (Target 1: red rings, dark bull) | 219 | 3.650 s | bounce-out (hits the bull and slides off) |

**Winner: right**, first to the board and stuck. The sound has one sharp onset at 162.132 s (Mark's knife); the Captain's impact can't be picked out of the ~70 ms rattle that follows (corrected 2026-10-15, as the Mac session found on 2026-10-14: "two thuds 37 ms apart" was an artefact of reading peaks in that rattle). So the margin, **2 frames (about 33 ms)**, rests on the video.
