---
tags: [design]
---

# Typography and Numbers

Part of [[App Design Index]]. **Status:** built 2026-10-23: the phone's own font; tabular digits in `StatTile` and on Play.

## Fonts

- The template suggests **SF Pro** or **Inter**.
- **Now:** the phone's own font: SF Pro on the iPhone, Roboto on Android. No font file is added to the app.
- **Later, maybe:** Inter on both, bundled as an asset (a new asset needs the Review Agent: app size).

## Headings

Bold. The hero's THROWER is heavy and widely spaced.

## Numbers Are the Focus

Stats show the number large, with a small label under it:

```text
287
Points

4.1
Per knife
```

- Numbers use tabular (fixed-width) digits, so they don't jump about as they change.
- A stat tile is a big number and a short label: [[Components]] → Stat tile.
