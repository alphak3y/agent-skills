#!/usr/bin/env bash
# screenshot.sh — Capture a webpage screenshot using headless Chrome
# Usage: screenshot.sh <url> [output_path] [width] [height] [full_page] [delay_secs]
#
# Arguments:
#   url         - URL to capture (required)
#   output_path - Output file path (default: /tmp/screenshot-<timestamp>.png)
#   width       - Viewport width in pixels (default: 1440)
#   height      - Viewport height in pixels (default: 900)
#   full_page   - "true" for full page capture via CDP (default: false)
#   delay_secs  - Seconds to wait for page load before capture (default: 3)
#
# Examples:
#   screenshot.sh https://example.com
#   screenshot.sh https://stripe.com /tmp/stripe.png 1920 1080
#   screenshot.sh https://stripe.com /tmp/stripe-full.png 1440 900 true
#   screenshot.sh https://stripe.com /tmp/stripe.png 1440 900 false 5

set -euo pipefail

URL="${1:?Usage: screenshot.sh <url> [output_path] [width] [height] [full_page] [delay_secs]}"
TIMESTAMP=$(date +%s%N)
OUTPUT="${2:-/tmp/screenshot-${TIMESTAMP}.png}"
WIDTH="${3:-1440}"
HEIGHT="${4:-900}"
FULL_PAGE="${5:-false}"
DELAY="${6:-3}"

# Find Chrome
CHROME=""
for candidate in google-chrome google-chrome-stable chromium-browser chromium; do
  if command -v "$candidate" &>/dev/null; then
    CHROME="$candidate"
    break
  fi
done

if [[ -z "$CHROME" ]]; then
  echo "ERROR: No Chrome/Chromium found. Install with: sudo apt-get install -y google-chrome-stable" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT")"

CHROME_COMMON_FLAGS=(
  --headless=new
  --no-sandbox
  --disable-gpu
  --disable-dev-shm-usage
  --disable-software-rasterizer
  --disable-extensions
  --disable-background-networking
  --hide-scrollbars
  --mute-audio
)

if [[ "$FULL_PAGE" == "true" ]]; then
  # Full page via CDP + Python websockets
  REMOTE_PORT=$((19200 + RANDOM % 800))
  TMPDIR="/tmp/chrome-ss-${TIMESTAMP}"

  "$CHROME" "${CHROME_COMMON_FLAGS[@]}" \
    --window-size="${WIDTH},${HEIGHT}" \
    --remote-debugging-port="${REMOTE_PORT}" \
    --user-data-dir="${TMPDIR}" \
    "$URL" &>/dev/null &
  CHROME_PID=$!

  cleanup() { kill "$CHROME_PID" 2>/dev/null || true; wait "$CHROME_PID" 2>/dev/null || true; rm -rf "$TMPDIR" 2>/dev/null || true; }
  trap cleanup EXIT

  # Wait for CDP
  for _ in $(seq 1 40); do
    curl -s "http://127.0.0.1:${REMOTE_PORT}/json/version" &>/dev/null && break
    sleep 0.25
  done

  python3 - "$REMOTE_PORT" "$OUTPUT" "$DELAY" "$WIDTH" <<'PYEOF'
import sys, json, base64, asyncio

async def main():
    port = sys.argv[1]
    output = sys.argv[2]
    delay = float(sys.argv[3])
    width = int(sys.argv[4])

    import urllib.request
    targets = json.loads(urllib.request.urlopen(f"http://127.0.0.1:{port}/json").read())
    ws_url = None
    for t in targets:
        if t.get("type") == "page":
            ws_url = t["webSocketDebuggerUrl"]
            break
    if not ws_url:
        print("ERROR: No page target found", file=sys.stderr)
        sys.exit(1)

    import websockets
    async with websockets.connect(ws_url, max_size=100*1024*1024) as ws:
        msg_id = 0
        async def cmd(method, params=None):
            nonlocal msg_id
            msg_id += 1
            c = {"id": msg_id, "method": method}
            if params: c["params"] = params
            await ws.send(json.dumps(c))
            while True:
                r = json.loads(await ws.recv())
                if r.get("id") == msg_id:
                    if "error" in r:
                        print(f"CDP error: {r['error']}", file=sys.stderr)
                    return r

        await asyncio.sleep(delay)

        layout = await cmd("Page.getLayoutMetrics")
        cs = layout["result"]["contentSize"]
        h = int(cs["height"])
        w = max(int(cs["width"]), width)

        await cmd("Emulation.setDeviceMetricsOverride", {
            "width": w, "height": h,
            "deviceScaleFactor": 1, "mobile": False
        })
        await asyncio.sleep(0.5)

        result = await cmd("Page.captureScreenshot", {
            "format": "png",
            "captureBeyondViewport": True
        })
        data = base64.b64decode(result["result"]["data"])
        with open(output, "wb") as f:
            f.write(data)
        print(f"OK: Full page screenshot saved to {output} ({len(data)} bytes)")

asyncio.run(main())
PYEOF
else
  # Simple viewport screenshot
  "$CHROME" "${CHROME_COMMON_FLAGS[@]}" \
    --window-size="${WIDTH},${HEIGHT}" \
    --virtual-time-budget=$((DELAY * 1000)) \
    --screenshot="$OUTPUT" \
    "$URL" 2>/dev/null

  if [[ -f "$OUTPUT" ]]; then
    SIZE=$(stat -c%s "$OUTPUT" 2>/dev/null || stat -f%z "$OUTPUT" 2>/dev/null)
    echo "OK: Screenshot saved to $OUTPUT (${SIZE} bytes)"
  else
    echo "ERROR: Screenshot failed" >&2
    exit 1
  fi
fi
