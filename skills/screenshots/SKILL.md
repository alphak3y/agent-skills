---
name: screenshots
description: Capture webpage screenshots using headless Chrome. Use when needing to screenshot a URL, capture a full-page screenshot, take visual snapshots of websites for design reference, visual testing, or sharing. Works on headless servers (no display needed). Supports viewport and full-page capture modes with configurable dimensions. Triggers on "screenshot", "capture page", "snap this site", "visual reference", "take a screenshot of".
---

# Screenshots

Capture webpage screenshots via headless Chrome CLI. No display server or Docker required.

## Prerequisites

- Google Chrome or Chromium installed (`google-chrome --version`)
- Python 3 with `websockets` package (only for full-page mode)

## Quick Usage

```bash
# Viewport screenshot (fast, default 1440x900)
scripts/screenshot.sh <url> [output_path] [width] [height]

# Full page screenshot (captures entire scrollable page)
scripts/screenshot.sh <url> [output_path] [width] [height] true [delay_secs]
```

## Parameters

| Param | Default | Description |
|-------|---------|-------------|
| `url` | required | URL to capture |
| `output_path` | `/tmp/screenshot-<ts>.png` | Output PNG path |
| `width` | `1440` | Viewport width in px |
| `height` | `900` | Viewport height in px |
| `full_page` | `false` | `true` for full scrollable page |
| `delay_secs` | `3` | Page load wait before capture |

## Examples

```bash
# Basic viewport screenshot
scripts/screenshot.sh https://example.com /tmp/example.png

# Wide desktop capture
scripts/screenshot.sh https://stripe.com /tmp/stripe.png 1920 1080

# Full page capture (entire scrollable content)
scripts/screenshot.sh https://docs.stripe.com /tmp/docs-full.png 1440 900 true

# Mobile viewport
scripts/screenshot.sh https://example.com /tmp/mobile.png 390 844

# Slow-loading page with extra delay
scripts/screenshot.sh https://heavy-site.com /tmp/heavy.png 1440 900 false 8
```

## How It Works

- **Viewport mode** (default): Uses `--screenshot` flag for a single-pass capture. Fast and reliable.
- **Full page mode**: Starts Chrome with CDP (Chrome DevTools Protocol), queries page dimensions via `Page.getLayoutMetrics`, resizes the viewport to full content height, then captures with `Page.captureScreenshot`. Requires Python `websockets`.

## After Capture

Use the `image` tool to view/analyze the screenshot:
```
image(image="/tmp/screenshot.png", prompt="Describe what you see")
```

## Troubleshooting

- **"No Chrome found"**: Install Chrome: `sudo apt-get install -y google-chrome-stable`
- **Full page fails**: Install websockets: `pip3 install websockets`
- **Page not fully rendered**: Increase `delay_secs` (e.g., 5-8 for JS-heavy SPAs)
- **Dark mode captured**: Chrome uses system theme; pages may render in dark mode on some setups
