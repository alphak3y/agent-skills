---
name: screenshots
description: Capture webpage screenshots and crop/resize images using headless Chrome + Pillow. Use when needing to screenshot a URL, capture a full-page screenshot, crop screenshots for product showcases, trim browser chrome, resize images, or prepare marketing assets. Works on headless servers (no display needed). Triggers on "screenshot", "capture page", "snap this site", "visual reference", "take a screenshot of", "crop", "crop image", "trim screenshot", "resize image".
---

# Screenshots & Image Cropping

Capture webpage screenshots via headless Chrome CLI + smart cropping via Pillow. No display server or Docker required.

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

## Image Cropping

Smart cropping for product screenshots and marketing assets. Requires `pip3 install Pillow`.

```bash
# Auto-crop: detect and remove browser chrome, nav bars, sticky footers
python3 scripts/crop.py --input screenshot.png --output cropped.png --auto

# Crop by pixels (remove 80px top, 100px bottom)
python3 scripts/crop.py -i screenshot.png -o cropped.png --top 80 --bottom 100

# Crop by percentage (5% top, 10% bottom)
python3 scripts/crop.py -i screenshot.png -o cropped.png --top-pct 5 --bottom-pct 10

# Crop to aspect ratio (centered)
python3 scripts/crop.py -i screenshot.png -o cropped.png --ratio 16:9

# Trim whitespace borders
python3 scripts/crop.py -i screenshot.png -o cropped.png --trim-whitespace

# Resize after crop (max width 1920px, preserves ratio)
python3 scripts/crop.py -i screenshot.png -o cropped.png --auto --max-width 1920
```

### Crop Modes

| Mode | Flag | Description |
|------|------|-------------|
| Auto | `--auto` | Detects dark browser chrome / nav bars and removes them |
| Manual (px) | `--top/bottom/left/right` | Exact pixel values to trim from each edge |
| Manual (%) | `--top-pct/bottom-pct/left-pct/right-pct` | Percentage of image to trim |
| Aspect ratio | `--ratio 16:9` | Crops to target ratio, centered |
| Trim whitespace | `--trim-whitespace` | Removes uniform-color borders |

### Post-Crop Options

| Flag | Description |
|------|-------------|
| `--max-width 1920` | Resize to max width after crop (preserves aspect ratio) |
| `--max-height 1080` | Resize to max height after crop |
| `--quality 85` | JPEG output quality (1-100, default 95) |
| `--padding 10` | Padding for trim-whitespace mode |

### Common Workflows

```bash
# Screenshot + auto-crop in one go
scripts/screenshot.sh https://example.com /tmp/raw.png 1440 900
python3 scripts/crop.py -i /tmp/raw.png -o /tmp/clean.png --auto

# Product showcase: screenshot, crop chrome, resize for web
scripts/screenshot.sh https://getrenta.io /tmp/product.png 1440 900
python3 scripts/crop.py -i /tmp/product.png -o /tmp/showcase.png --auto --max-width 1920

# Crop uploaded image for specific section
python3 scripts/crop.py -i upload.png -o hero.png --top-pct 5 --bottom-pct 30

# Social media format
python3 scripts/crop.py -i screenshot.png -o og-image.png --ratio 1200:630
```

## Headshot / Portrait Cropping

When cropping photos of people for team pages, profiles, or about sections:

### Finding the Face
Don't guess — sample pixel brightness to locate skin tones:
```python
from PIL import Image
img = Image.open('photo.jpg')
w, h = img.size
for pct in range(0, 100, 5):
    y = int(h * pct / 100)
    r, g, b = img.getpixel((w//2, y))[:3]
    print(f"{pct}% (y={y}): rgb({r},{g},{b}) {'SKIN' if r > 150 and g > 80 else 'SKY' if b > 200 and r < 150 else ''}")
```

### Crop Rules for Head+Shoulders
- **Top of frame:** ~10-15% above the top of the head (hair/hat)
- **Bottom of frame:** mid-chest / shoulders visible
- **Horizontal:** center on the face, not the body
- **Aspect ratio:** square (`aspect-square`) works best for team grids
- **Face should fill 50-60% of the frame height**

### Common Mistakes
- Cropping too high → just sky/hair, face cut off
- Cropping too low → too much body, head looks small
- Using `object-position` CSS instead of actual crop → unpredictable across containers
- Assuming face is at top of photo → selfies/mountain shots often have face in lower 60%

### Quick Recipe
```python
# For a full-body or mountain selfie → head+shoulders crop
from PIL import Image
img = Image.open('fullbody.jpg')
w, h = img.size

# 1. Find face zone (sample center column for skin tones)
# 2. Set top = 10% above face start, bottom = 20% below face end
# 3. Make it square, centered horizontally
top = int(h * 0.25)    # adjust based on face location
bottom = int(h * 0.85)  # adjust to include shoulders
crop_h = bottom - top
crop_w = crop_h  # square
left = (w - crop_w) // 2
cropped = img.crop((left, top, left + crop_w, bottom))
cropped.save('headshot.jpg', quality=90)
```

### CSS for Team Photo Grids
```html
<!-- Use aspect-square containers with object-cover -->
<div class="aspect-square rounded-2xl overflow-hidden">
  <img src="/team/mike.jpg" class="w-full h-full object-cover" />
</div>
```
- Don't use `next/image` with `fill` for team photos — plain `<img>` with `object-cover` is more reliable
- Crop the actual image file rather than relying on `object-position` — what you see is what you get
- For team grids: crop all photos to the same dimensions before uploading for consistent alignment

## Troubleshooting

- **"No Chrome found"**: Install Chrome: `sudo apt-get install -y google-chrome-stable`
- **Full page fails**: Install websockets: `pip3 install websockets`
- **"Pillow required"**: Install Pillow: `pip3 install Pillow`
- **Page not fully rendered**: Increase `delay_secs` (e.g., 5-8 for JS-heavy SPAs)
- **Dark mode captured**: Chrome uses system theme; pages may render in dark mode on some setups
- **Auto-crop too aggressive/conservative**: Use manual `--top/--bottom` pixel values instead
