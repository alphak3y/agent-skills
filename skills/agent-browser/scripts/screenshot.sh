#!/bin/bash
# Take a screenshot of a URL or the current page
# Usage: screenshot.sh <url> [output_path] [--full] [--width=N] [--height=N]
#
# Examples:
#   screenshot.sh https://example.com                    → screenshot to /tmp/screenshot-<ts>.png
#   screenshot.sh https://example.com ./shot.png         → screenshot to ./shot.png
#   screenshot.sh https://example.com ./shot.png --full  → full page screenshot
#   screenshot.sh current ./shot.png                     → screenshot current PinchTab tab

set -euo pipefail

URL="${1:-}"
OUTPUT="${2:-/tmp/screenshot-$(date +%s).png}"
FULL_PAGE=false
WIDTH=1280
HEIGHT=720

# Parse flags
for arg in "$@"; do
  case "$arg" in
    --full) FULL_PAGE=true ;;
    --width=*) WIDTH="${arg#--width=}" ;;
    --height=*) HEIGHT="${arg#--height=}" ;;
  esac
done

if [ -z "$URL" ]; then
  echo "Usage: screenshot.sh <url|current> [output_path] [--full] [--width=N] [--height=N]"
  exit 1
fi

# If "current" and PinchTab is running, use PinchTab CLI (faster)
if [ "$URL" = "current" ]; then
  if command -v pinchtab &>/dev/null && curl -s http://localhost:9867/health &>/dev/null; then
    pinchtab ss -o "$OUTPUT"
    echo "$OUTPUT"
    exit 0
  else
    echo "Error: PinchTab not running. Use a URL instead of 'current'." >&2
    exit 1
  fi
fi

# Use Playwright for URL screenshots (handles any page, no running browser needed)
NODE_PATH=$(npm root -g) node -e "
const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: ${WIDTH}, height: ${HEIGHT} } });
  await page.goto('${URL}', { waitUntil: 'networkidle', timeout: 30000 });
  await page.screenshot({ path: '${OUTPUT}', fullPage: ${FULL_PAGE} });
  await browser.close();
})().catch(e => { console.error(e.message); process.exit(1); });
"

echo "$OUTPUT"
