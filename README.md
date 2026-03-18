# 🌐 Agent Browser

Browser automation, screenshots, visual testing, and performance auditing for AI coding agents. Built for [OpenClaw](https://github.com/openclaw/openclaw), works anywhere.

## What It Does

| Capability | Tool | Setup |
|------------|------|-------|
| **Screenshot any URL** | Playwright | Zero config |
| **Full page / mobile screenshots** | Playwright | Zero config |
| **Multi-step browser automation** | Playwright (`browse.js`) | Zero config |
| **Interactive page exploration** | PinchTab | `pinchtab &` |
| **Visual regression testing** | ImageMagick | `apt install imagemagick` |
| **Performance audits** | Lighthouse | Auto-installs |
| **Content extraction** | PinchTab / Playwright | Either works |
| **Share images with humans** | S3 upload (`share-image.sh`) | Any chat platform |

## Quick Start

### Prerequisites

```bash
# Install Playwright + browser
npm install -g playwright
npx playwright install chromium
npx playwright install-deps chromium

# Optional: PinchTab for interactive browsing
npm install -g pinchtab
```

### Take a Screenshot

```bash
bash skills/agent-browser/scripts/screenshot.sh https://example.com ./shot.png

# Full page
bash skills/agent-browser/scripts/screenshot.sh https://example.com ./shot.png --full

# Mobile viewport
bash skills/agent-browser/scripts/screenshot.sh https://example.com ./mobile.png --width=375 --height=812
```

### Automate Browser Actions

```bash
NODE_PATH=$(npm root -g) node skills/agent-browser/scripts/browse.js '{
  "url": "https://example.com",
  "actions": [
    { "action": "screenshot", "output": "./before.png" },
    { "action": "click", "selector": "a" },
    { "action": "screenshot", "output": "./after.png" },
    { "action": "text" }
  ]
}'
```

**Available actions:** `screenshot`, `click`, `type`, `press`, `wait`, `waitFor`, `navigate`, `text`, `evaluate`, `pdf`

### Compare Screenshots

```bash
bash skills/agent-browser/scripts/visual-diff.sh before.png after.png diff.png
```

### Share Screenshots

Upload to S3 and get a public URL you can send in any chat:

```bash
export SHARE_BUCKET=my-bucket
bash skills/agent-browser/scripts/share-image.sh ./screenshot.png
# → https://my-bucket.s3.us-east-2.amazonaws.com/screenshots/20260316-screenshot.png
```

Requires AWS credentials (IAM role, env vars, or `~/.aws/credentials`).

### Run Lighthouse Audit

```bash
bash skills/agent-browser/scripts/lighthouse.sh https://example.com /tmp
# Returns: { performance: 95, accessibility: 100, bestPractices: 92, seo: 90 }
```

## Installation (OpenClaw)

```bash
cp -r skills/agent-browser ~/.openclaw/workspace/skills/
```

Agents discover skills automatically.

## Skill Structure

```
skills/
├── agent-browser/
│   ├── SKILL.md                # When and how to use each tool
│   └── scripts/
│       ├── screenshot.sh       # Quick screenshots (Playwright or PinchTab)
│       ├── browse.js           # Multi-step browser automation (Playwright)
│       ├── share-image.sh      # Upload images to S3 for sharing via URL
│       ├── visual-diff.sh      # Compare two screenshots (ImageMagick)
│       └── lighthouse.sh       # Performance/accessibility audits
└── s3-share/
    ├── SKILL.md                # S3 presigned URL file sharing
    └── scripts/
        ├── s3-share.sh         # Upload file → get presigned URL
        └── s3-setup.sh         # One-command bucket setup
```

## Two Engines, One Skill

**Playwright** — headless Chromium, spins up on demand, full page control. Best for screenshots, testing, and automation sequences. No running browser process needed.

**PinchTab** — connects to a running Chrome instance, returns an accessibility tree with stable element refs. Best for interactive exploration where you need to read the page, click around, and understand structure. Token-efficient.

| Use Case | Best Tool |
|----------|-----------|
| Screenshot a URL | Playwright (`screenshot.sh`) |
| Screenshot current page | PinchTab (`pinchtab ss`) |
| Fill a form and submit | Playwright (`browse.js`) |
| Explore a page interactively | PinchTab (`pinchtab snap`) |
| Visual regression testing | Playwright + `visual-diff.sh` |
| Performance audit | `lighthouse.sh` |

## License

MIT
