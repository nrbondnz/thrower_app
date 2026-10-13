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

Useful for: real ring colours (board 2 is a non-red board; see the [[backlog]] carry-over), real knives sticking and being collected, people walking in front, and dusk light. The camera position isn't the app's intended mount (it faces the boards from the throwing area). So use these for colours and events, not for the side-on geometry.

## Answer Key: `truth.json`

What happened on each board, round by round:
- **Throws and scores:** Nigel (2026-10-11). He judged them from the **copy**, and some aren't clear.
- **Times and places:** Claude, from the copy. The times hold for the original too.
- **Events:** each event has an `id`, a `kind` (`stuck`, `bounceOut` or `visit`), a `time` (s), a `score` and a `round`. A **visit** means people are at the board (collecting), which ends the round.

| Board | Rounds |
|---|---|
| 1 | 4 5 5 · bounce 5 5 · 4 5 bounce · 3 3 4 · bounce · bounce |
| 2 | 5 4 5 · 4 3 bounce · 2 bounce 4 · 5 · 3 |

The original confirms the throws and bounce-outs. For example, board 1's last bounce-out (177.0 s), invisible on the copy, is a knife hitting the top of the board and falling past the bottom. The **scores** haven't been re-checked against it yet (see [[backlog]] → Carry-overs from Live Test).

The Live test replay tests check the app's live analysis against this file. The review page (zoomed clips of each event, from the copy) is at https://claude.ai/artifact/1fAKaR23dR8D5DnWkC9WN6.
