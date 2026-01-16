# Retro Sega Mega Drive Palette Usage

## Usage Rules
- Backgrounds use **black**, **deep_purple**, or **navy** for depth and contrast.
- Primary text uses **yellow** or **lime** for high readability.
- Secondary text uses **mint** or **teal** to keep reports readable without overpowering accents.
- Alerts map to **green** (success), **orange** (warning), **red** (error).
- Accents use **violet**, **magenta**, and **peggy_pink_accent** sparingly for highlights.
- Charts cycle through the full spectrum listed in `palette.json`.

## Terminal Color Codes
- info: `\u001b[38;2;120;248;0m`
- warn: `\u001b[38;2;248;168;0m`
- error: `\u001b[38;2;248;0;0m`
- accent: `\u001b[38;2;255;102;204m`
- reset: `\u001b[0m`

## ComfyUI Overlay Rules
- Keep overlays inside 85% of frame width/height to avoid UI collisions.
- Use pixel fonts with 2px outline, yellow/lime text on deep purple background.
- Apply 40% opacity black shadow for legibility.
- Peggy Pink Accent must be <= 15% of overlay area to remain tasteful.

## Peggy Pink Accent
- Color: `#FF66CC`
- Use for badges, shimmer highlights, and call-to-action labels.
