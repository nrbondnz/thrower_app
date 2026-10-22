---
tags: [design]
---

# Throwing Screens

Part of [[App Design Index]]. Play (`play_screen.dart`, `two_target_play_screen.dart`), the score pad, and Quick draw.

## Show What the AI Saw

Many scoring apps only show numbers. Ours shows the camera picture with:
- the locked rings, in green;
- a yellow circle with the score at each knife's entry;
- a bounce-out's 0 beside the target.

This builds trust in the scoring. It's already built; keep it.

## Now (this story)

- These screens stay dark in both themes ([[Colour and Themes]]).
- The round and total in larger, bolder type, so they read from the throwing line.

## Later

- A score panel laid out as stat tiles: this round's knives, the round total, the session total.
- A small target beside the scores, with this round's hits on it.
- The words: "Game over" and the like ([[Brand and Voice]] → How the App Talks).
