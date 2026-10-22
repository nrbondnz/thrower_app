---
tags: [design]
---

# Colour and Themes

Part of [[App Design Index]]. Code: `lib/ui/theme/app_theme.dart` (`AppPalette`, `AppTheme`).

## The Palette

The template's colours, for the dark theme:
- **Background:** charcoal `#121212`.
- **Surface** (cards): `#1E1E1E`.
- **Primary:** amber `#D97706`.
- **Accent:** red `#DC2626`.
- **Text:** `#F3F4F6`.

What they mean:
- Charcoal: a premium sports and competition feel.
- Amber: wood, axes, competition.
- Red: the bull, and highlights.
- Near-white text: high contrast.

## Light and Dark

Nigel, 2026-10-23: **follow the phone, with a setting to override it.**

- **Setup → Appearance:** Phone (the default), Light or Dark. Kept on the phone.
- The light theme uses the same colours, darkened so they read on a light background:
  - background `#F7F5F2` (warm off-white);
  - surface `#FFFFFF`;
  - primary amber `#B45309`;
  - accent red `#B91C1C`;
  - text `#1F2937`.
- Text on an amber button is charcoal in the dark theme and white in the light theme, for contrast.

## The Camera Screens Stay Dark

Play, two-target Play, Quick draw, Calibrate and Live test show the camera picture with the scores under it, on black. They stay dark in both themes:
- they're read from the throwing line, often in a dim range, so white text on black reads best;
- the green rings and yellow score marks were chosen to show on the camera picture.

They use the dark theme whatever the setting (`AppTheme.cameraDark` wraps them).

## Board Colours

The target drawing (`TargetPainter`) keeps the painted board's own colours, red (`#C62828`) and bare wood (`#E3C9A0`), in both themes.
