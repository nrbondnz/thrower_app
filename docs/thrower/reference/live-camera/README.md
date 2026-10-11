# Live Camera: Real Boards

Cropped on 2026-10-11 from a phone video Nigel supplied: two real boards on A-frame stands outdoors at dusk, with knives being thrown and collected. The clip is 3 min 10 s long, portrait 464 × 832, at 60 fps. Each crop shows one board at its **native resolution** (no upscaling). That's the size a far-off phone camera actually sees: each board is about 106 px across.

| File | Board | Crop in the source (w:h:x:y) |
|---|---|---|
| `1.mp4` | Left: red rings on wood, dark bull | `140:140:50:232` |
| `2.mp4` | Right: green and red rings on pale wood | `140:140:312:238` |

Both files are H.264 (CRF 18) with the original audio, made with `ffmpeg -vf crop=…`. The source `.mov` isn't kept in the repo.

Useful for: real ring colours (board 2 is a non-red board; see the [[backlog]] carry-over), real knives sticking and being collected, people walking in front, and dusk light. The camera position isn't the app's intended mount (it faces the boards from the throwing area). So use these for colours and events, not for the side-on geometry.

## Answer Key: `truth.json`

What happened on each board, round by round:
- **Throws and scores:** Nigel (2026-10-11). He judged them from the same footage, and some aren't clear.
- **Times and places:** Claude, from the footage.
- **Events:** each event has an `id`, a `kind` (`stuck`, `bounceOut` or `visit`), a `time` (s), a `score` and a `round`. A **visit** means people are at the board (collecting), which ends the round.

| Board | Rounds |
|---|---|
| 1 | 4 5 5 · bounce 5 5 · 4 5 bounce · 3 3 4 · bounce · bounce |
| 2 | 5 4 5 · 4 3 bounce · 2 bounce 4 · 5 · 3 |

The Live test replay tests check the app's live analysis against this file. The review page (zoomed clips of each event) is at https://claude.ai/artifact/1fAKaR23dR8D5DnWkC9WN6.
