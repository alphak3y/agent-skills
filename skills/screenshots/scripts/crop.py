#!/usr/bin/env python3
"""
Smart image cropping for product screenshots and marketing assets.

Usage:
    # Auto-crop: detect and remove browser chrome, nav bars, partial UI elements
    python3 crop.py --input screenshot.png --output cropped.png --auto

    # Manual crop with pixel values
    python3 crop.py --input screenshot.png --output cropped.png --top 80 --bottom 100

    # Crop by percentage
    python3 crop.py --input screenshot.png --output cropped.png --top-pct 5 --bottom-pct 10

    # Crop to specific aspect ratio (centered)
    python3 crop.py --input screenshot.png --output cropped.png --ratio 16:9

    # Crop to content (remove whitespace borders)
    python3 crop.py --input screenshot.png --output cropped.png --trim-whitespace

    # Resize after crop
    python3 crop.py --input screenshot.png --output cropped.png --auto --max-width 1920
"""

import argparse
import sys
from pathlib import Path

try:
    from PIL import Image, ImageChops
except ImportError:
    print("Error: Pillow required. Install with: pip3 install Pillow")
    sys.exit(1)


def auto_crop(img: Image.Image, threshold: int = 30) -> tuple[int, int, int, int]:
    """
    Detect browser chrome / nav bars at top and partial UI at bottom.
    Returns (left, top, right, bottom) crop box.
    
    Strategy:
    - Scan down from top: find first row that's mostly white/light (content start)
    - Scan up from bottom: find first row that's mostly white/light (content end)
    - Skip dark rows at edges (browser chrome, sticky bars)
    """
    w, h = img.size
    pixels = img.load()

    def row_avg_brightness(y: int) -> float:
        """Average brightness of a row (0-255)."""
        total = 0
        samples = min(w, 50)  # sample 50 evenly spaced pixels
        step = max(1, w // samples)
        count = 0
        for x in range(0, w, step):
            r, g, b = pixels[x, y][:3]
            total += (r + g + b) / 3
            count += 1
        return total / count if count else 0

    def row_is_uniform(y: int, tolerance: int = 15) -> bool:
        """Check if row is mostly one color (nav bar, footer bar)."""
        samples = []
        step = max(1, w // 30)
        for x in range(0, w, step):
            r, g, b = pixels[x, y][:3]
            samples.append((r + g + b) / 3)
        if not samples:
            return True
        avg = sum(samples) / len(samples)
        return all(abs(s - avg) < tolerance for s in samples)

    # Find top content boundary
    top = 0
    for y in range(min(h // 4, 200)):  # scan top 25% or 200px
        brightness = row_avg_brightness(y)
        if brightness < 200 and row_is_uniform(y):
            top = y + 1  # this is a dark bar, skip it
        elif brightness >= 230:
            # Found light content area
            break

    # Find bottom content boundary
    bottom = h
    for y in range(h - 1, max(h * 3 // 4, h - 200), -1):  # scan bottom 25%
        brightness = row_avg_brightness(y)
        if brightness < 200 and row_is_uniform(y):
            bottom = y  # this is a dark bar, stop before it
        elif brightness >= 230:
            break

    return (0, top, w, bottom)


def trim_whitespace(img: Image.Image, padding: int = 0) -> tuple[int, int, int, int]:
    """Remove whitespace borders around content."""
    # Create a background reference (assume corner pixel is background)
    bg = Image.new(img.mode, img.size, img.getpixel((0, 0)))
    diff = ImageChops.difference(img, bg)
    diff = ImageChops.add(diff, diff, 2.0, -100)
    bbox = diff.getbbox()
    if bbox:
        l, t, r, b = bbox
        return (
            max(0, l - padding),
            max(0, t - padding),
            min(img.width, r + padding),
            min(img.height, b + padding),
        )
    return (0, 0, img.width, img.height)


def crop_to_ratio(img: Image.Image, ratio_str: str) -> tuple[int, int, int, int]:
    """Crop to specific aspect ratio, centered."""
    w, h = img.size
    rw, rh = map(int, ratio_str.split(":"))
    target_ratio = rw / rh

    current_ratio = w / h
    if current_ratio > target_ratio:
        # Too wide, crop sides
        new_w = int(h * target_ratio)
        offset = (w - new_w) // 2
        return (offset, 0, offset + new_w, h)
    else:
        # Too tall, crop top/bottom
        new_h = int(w / target_ratio)
        offset = (h - new_h) // 2
        return (0, offset, w, offset + new_h)


def main():
    parser = argparse.ArgumentParser(description="Smart image cropping")
    parser.add_argument("--input", "-i", required=True, help="Input image path")
    parser.add_argument("--output", "-o", help="Output path (default: overwrites input)")
    
    # Crop modes
    parser.add_argument("--auto", action="store_true", help="Auto-detect and remove browser chrome/bars")
    parser.add_argument("--trim-whitespace", action="store_true", help="Remove whitespace borders")
    parser.add_argument("--ratio", help="Crop to aspect ratio (e.g., 16:9, 4:3, 1:1)")
    
    # Manual crop (pixels)
    parser.add_argument("--top", type=int, default=0, help="Pixels to crop from top")
    parser.add_argument("--bottom", type=int, default=0, help="Pixels to crop from bottom")
    parser.add_argument("--left", type=int, default=0, help="Pixels to crop from left")
    parser.add_argument("--right", type=int, default=0, help="Pixels to crop from right")
    
    # Manual crop (percentage)
    parser.add_argument("--top-pct", type=float, default=0, help="Percent to crop from top")
    parser.add_argument("--bottom-pct", type=float, default=0, help="Percent to crop from bottom")
    parser.add_argument("--left-pct", type=float, default=0, help="Percent to crop from left")
    parser.add_argument("--right-pct", type=float, default=0, help="Percent to crop from right")
    
    # Post-crop options
    parser.add_argument("--max-width", type=int, help="Resize to max width after crop (preserves ratio)")
    parser.add_argument("--max-height", type=int, help="Resize to max height after crop (preserves ratio)")
    parser.add_argument("--quality", type=int, default=95, help="Output JPEG quality (1-100)")
    parser.add_argument("--padding", type=int, default=0, help="Padding for trim-whitespace mode")
    
    args = parser.parse_args()
    
    img = Image.open(args.input)
    if img.mode == "RGBA":
        # Convert to RGB for analysis (keep alpha for saving)
        img_rgb = img.convert("RGB")
    else:
        img_rgb = img
    
    w, h = img.size
    print(f"Input: {w}×{h} ({args.input})")
    
    # Determine crop box
    if args.auto:
        box = auto_crop(img_rgb)
        print(f"Auto-detected crop: top={box[1]}, bottom={h - box[3]}")
    elif args.trim_whitespace:
        box = trim_whitespace(img_rgb, padding=args.padding)
        print(f"Trim whitespace: {box}")
    elif args.ratio:
        box = crop_to_ratio(img, args.ratio)
        print(f"Ratio crop ({args.ratio}): {box}")
    elif any([args.top, args.bottom, args.left, args.right]):
        box = (args.left, args.top, w - args.right, h - args.bottom)
    elif any([args.top_pct, args.bottom_pct, args.left_pct, args.right_pct]):
        box = (
            int(w * args.left_pct / 100),
            int(h * args.top_pct / 100),
            int(w * (1 - args.right_pct / 100)),
            int(h * (1 - args.bottom_pct / 100)),
        )
    else:
        print("No crop mode specified. Use --auto, --trim-whitespace, --ratio, or manual offsets.")
        sys.exit(1)
    
    # Apply crop
    cropped = img.crop(box)
    cw, ch = cropped.size
    print(f"Cropped: {cw}×{ch}")
    
    # Resize if requested
    if args.max_width and cw > args.max_width:
        ratio = args.max_width / cw
        cropped = cropped.resize((args.max_width, int(ch * ratio)), Image.LANCZOS)
        print(f"Resized: {cropped.size}")
    elif args.max_height and ch > args.max_height:
        ratio = args.max_height / ch
        cropped = cropped.resize((int(cw * ratio), args.max_height), Image.LANCZOS)
        print(f"Resized: {cropped.size}")
    
    # Save
    output = args.output or args.input
    ext = Path(output).suffix.lower()
    if ext in (".jpg", ".jpeg"):
        if cropped.mode == "RGBA":
            cropped = cropped.convert("RGB")
        cropped.save(output, "JPEG", quality=args.quality)
    else:
        cropped.save(output, quality=args.quality)
    
    print(f"Saved: {output}")


if __name__ == "__main__":
    main()
