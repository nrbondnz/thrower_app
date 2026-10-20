# Story Checkpoint: Virtual Thrower (Rendered Games to Test the Camera)

## Story Goal
Whole games rendered on the PC from the ray-traced scene (`SyntheticScene`, the reference board's photo on its stand, knives, people, shadows), as Live test recordings (`.tfrm`) with an answer key, and replayed through the app's real camera path (`RecordedCamera` → `ThrowWatcher` → scores) in tests, so the camera can be checked on many throws without a board. Backlog #19.

## Answers (Nigel, 2026-10-20)
- Option **A**: fake pictures for testing the camera (not fake throw events).
- The recordings live with the **tests only** (not in the app: size).
- **One board (Scoring) first**; the new games' layouts (three boards; 3–7 m) last.

## Complexity Score
4 (Large): tools (rendering) → camera → vision → scoring; a new fixture format; several acceptance criteria.

## Status
IN PROGRESS: plan approved 2026-10-20; run whole, committing per task ([[dont-ask-again]]).

---

## Task 1: Render a whole game
- **Status:** COMPLETE (2026-10-20)
- **What changed:**
  - `tool/throw_scenes.dart` (new): the scenes from `render_throw_sequences.dart` (stick, bounce, retrieval, the knife's flight, motion blur, noise), made public and shared. Bounce-outs now leave their knife on the grass for the rest of the round, and collecting picks them up. `render_throw_sequences.dart` uses it; its output is unchanged (re-rendered `throw-bounce-out`: identical files).
  - `tool/render_game.dart` (new): a game script (`test/fixtures/virtual_games/<name>.json`: rounds of knives, each a painted ring 1–5 (its middle, or 3% from its inner or outer edge), a bounce-out or a miss) → `<name>/game.tfrm` (15 fps, 640 × 360), `truth.json` (each throw's kind, time and score; each collection; round totals) and `preview.gif`. Settled frames are rendered once per board state and reused with fresh noise; the moving ones run on all but one core.
  - First script, `solo_3_rounds.json`: 3 rounds, 8 knives in every ring (three 3% from an edge) and a bounce-out; key round totals 12, 6, 9.
  - **Size:** `game.tfrm` is 42 MB (the noise makes the JPEGs big), so renders are **not committed** (`.gitignore`); they're deterministic and take ~12 min (56.6 s of game, 849 frames, 347 renders on 7 cores).
- **Verified by:** the render ran; `preview.gif` to watch (`test/fixtures/virtual_games/solo_3_rounds/preview.gif`).
- **Plan (was):** `tool/render_game.dart`: a game script (rounds of knives: where each lands, or a bounce-out; collecting between rounds) → a `.tfrm`, an answer key and a preview. The existing throw, bounce and retrieval scenes move into a shared library. Settled frames are rendered once per board state and reused with fresh noise; the rest is spread over the PC's cores. First script: one board, 1 player, 3 rounds.

## Task 2: Replay test
- **Status:** IN PROGRESS (paused 2026-10-20 for Mark's boards, Nigel's priority)
- `test/game/virtual_game_replay_test.dart` (written, not committed): the render through `RecordedCamera` → `ThrowWatcher` → `GameNotifier`, calibrated on frame 0.
- **First result (solo_3_rounds):** the board was found and every collection seen, and the bounce-out found, but only **2 of 8 stuck knives** were seen (one scored right, 2; one scored 0 for a 1); so Play ended after 2 rounds. Knives thrown from 4 m and seen from 2 m at 45° are mostly missed: the next thing to investigate (the watcher's thresholds on this view, or the render).

## Task 3: The virtual thrower (random games from a seed)
- **Status:** NOT STARTED

## Task 4: The new games' layouts (three boards; 3–7 m)
- **Status:** NOT STARTED

---

## Notes
- Render cost measured 2026-10-20: ~7 s a frame at 640 × 360 with 4-sample motion blur (`throw-stick-ring4`, 30 frames in 211 s), single-threaded.

## Plan Changes Log
- (none yet)
