---
name: agent-browser
description: "Browser automation, screenshots, visual testing, and performance auditing for AI agents. Use when: taking screenshots of pages, testing UI visually, running Lighthouse audits, automating browser interactions (clicking, typing, form filling), comparing page changes, or extracting rendered page content. Supports Playwright (full automation) and PinchTab (fast interactive browsing)."
---

# Agent Browser

Two browser engines for different jobs:

- **Playwright** — full automation, screenshots, testing, Lighthouse. No running browser needed.
- **PinchTab** — fast interactive browsing with accessibility tree. Needs `pinchtab` running.

## Quick Reference

### Screenshots

```bash
# Screenshot a URL (Playwright — works without running browser)
bash scripts/screenshot.sh https://example.com ./shot.png

# Full page screenshot
bash scripts/screenshot.sh https://example.com ./shot.png --full

# Custom viewport
bash scripts/screenshot.sh https://example.com ./shot.png --width=375 --height=812

# Screenshot current PinchTab tab (faster, needs PinchTab running)
bash scripts/screenshot.sh current ./shot.png
```

All paths in this skill are relative to the skill directory. Resolve against `dirname(SKILL.md)`.

### Browser Automation

For multi-step interactions, use `browse.js` with a JSON instruction set:

```bash
NODE_PATH=$(npm root -g) node scripts/browse.js '{
  "url": "https://example.com",
  "actions": [
    { "action": "screenshot", "output": "/tmp/before.png" },
    { "action": "click", "selector": "a.nav-link" },
    { "action": "waitFor", "selector": ".page-content" },
    { "action": "screenshot", "output": "/tmp/after.png" },
    { "action": "text", "selector": ".page-content" }
  ]
}'
```

Or from a file: `node scripts/browse.js @instructions.json`

**Available actions:** `screenshot`, `click`, `type`, `press`, `wait`, `waitFor`, `navigate`, `text`, `evaluate`, `pdf`

### Visual Comparison

```bash
# Compare two screenshots (requires ImageMagick)
bash scripts/visual-diff.sh before.png after.png diff.png
```

### Performance Audit

```bash
# Run Lighthouse (installs automatically on first use)
bash scripts/lighthouse.sh https://example.com /tmp
```

Returns JSON scores for performance, accessibility, best practices, SEO.

### Interactive Browsing (PinchTab)

When you need to explore a page interactively (follow links, fill forms, read content):

```bash
# Start PinchTab if not running
pinchtab &
sleep 3

# Navigate and get page structure
pinchtab nav https://example.com
sleep 3
pinchtab snap -i -c          # Interactive elements, compact format

# Interact
pinchtab click e5             # Click element by ref
pinchtab type e12 "search"    # Type into element
pinchtab press Enter

# Read content
pinchtab text                 # Readable text (~800 tokens)

# Screenshot current state
pinchtab ss -o page.jpg
```

**PinchTab screenshot via HTTP API** (for programmatic use):
```bash
# GET returns base64 JSON (not binary)
curl -s http://localhost:9867/screenshot | python3 -c "
import json, sys, base64
data = json.load(sys.stdin)
with open('page.png', 'wb') as f:
    f.write(base64.b64decode(data['base64']))
print('Saved page.png')
"
```

## When to Use What

| Task | Tool | Why |
|------|------|-----|
| Screenshot a URL | `screenshot.sh` (Playwright) | No setup needed, reliable |
| Screenshot current page | `pinchtab ss` | Faster, uses existing tab |
| Multi-step automation | `browse.js` (Playwright) | Full control, scriptable |
| Interactive exploration | PinchTab CLI | Accessibility tree, low tokens |
| Visual regression | `visual-diff.sh` | Pixel-level comparison |
| Performance audit | `lighthouse.sh` | Core Web Vitals scores |
| Form testing | `browse.js` (Playwright) | Fill + submit + verify |
| Content extraction | PinchTab `text` or `snap` | Token-efficient |

## Tips

- **Always use `--full` for landing pages** — captures below-the-fold content
- **Mobile screenshots:** `--width=375 --height=812` (iPhone viewport)
- **Share screenshots** by saving to the project directory and referencing the path
- **PinchTab waits:** Always `sleep 3` after `pinchtab nav` before snapshot
- **NODE_PATH:** Playwright requires `NODE_PATH=$(npm root -g)` when installed globally
