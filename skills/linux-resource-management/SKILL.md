---
name: linux-resource-management
description: Manage Linux memory, swap, and processes to prevent OOM kills during heavy agent workloads. Use when running enrichment pipelines, multiple subagents, or any memory-intensive batch operation. Also use when diagnosing crashes, freeing memory, or monitoring resource usage. Triggers on "OOM", "out of memory", "crashed", "killed", "memory", "swap", "free up", "EC2 resources".
---

# Linux Resource Management

Prevent OOM kills and manage resources on memory-constrained Linux instances running OpenClaw.

## Current Setup
- **Instance:** t3-class (3.7GB RAM)
- **Swap:** 4GB (added manually — see setup below)
- **Biggest memory consumer:** OpenClaw gateway (~1.6-2GB RSS)
- **Effective total:** ~7.7GB (RAM + swap)

## Quick Diagnostics

### Check memory
```bash
free -h
```

### Top memory consumers
```bash
ps aux --sort=-%mem | head -10
```

### Check swap usage
```bash
free -h | grep Swap
```

## Immediate Fixes (When Memory is Tight)

### 1. Drop filesystem caches (SAFE — doesn't kill processes)
```bash
sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'
```
Frees OS file read cache. Typically recovers 500MB-1.5GB. Zero risk to running processes.

### 2. Kill unused services
```bash
# PinchTab (if running and not needed)
pkill -f pinchtab

# Check for zombie Python processes
ps aux | grep python | grep -v grep

# Docker (if no containers running)
docker ps  # check first
sudo systemctl stop docker  # saves ~18MB
```

### 3. Check for runaway processes
```bash
# Processes using >5% memory
ps aux --sort=-%mem | awk '$4 > 5.0'
```

## Swap Setup (One-Time)

If swap isn't configured:
```bash
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab  # persist across reboots
```

Verify: `free -h` should show swap.

### Make swap persistent across reboots
```bash
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

## Preventing OOM Kills

### Rule 1: Process sequentially, not in parallel
BAD: Load all 103 market JSONs into memory at once
GOOD: Process one market file at a time

```bash
# Sequential processing pattern
for f in prospects/*.json; do
    python3 enrich.py --input "$f" --concurrency 3
done
```

### Rule 2: Low concurrency for HTTP scraping
- **3 concurrent** for basic HTTP (enrich_website.py)
- **3 concurrent** for Playwright/headless browser
- **1 at a time** for heavy API calls (Apollo, SerpAPI)
- **Never** run 10+ concurrent on a 3.7GB instance

### Rule 3: Don't stack heavy processes
- One enrichment pipeline at a time
- Don't run enrichment + subagent simultaneously
- If you need both, wait for enrichment to finish first
- Subagent (Opus) alone uses ~500MB-1GB

### Rule 4: Monitor before launching
```bash
# Check available memory before starting a heavy task
free -h | grep Mem | awk '{print "Available: " $7}'
# If less than 500MB available, drop caches first
```

## Memory Budget

| Component | Typical RSS | Notes |
|-----------|-------------|-------|
| OpenClaw gateway | 1.5-2.0GB | Always running, can't reduce |
| JFL context hub | ~27MB | Background service |
| Python enrichment script | 20-50MB | Per-file processing |
| Playwright browser | 200-400MB | Only when JS scraping |
| Subagent (Opus) | 500MB-1GB | During subagent runs |
| **Total when idle** | **~2GB** | |
| **Total during enrichment** | **~2.5GB** | |
| **Total during subagent + enrichment** | **~3.5-4GB** | ⚠️ Needs swap |

## Instance Upgrade Path

| Instance | RAM | Cost/mo | When to upgrade |
|----------|-----|---------|----------------|
| t3.medium | 4GB | ~$30 | Current-ish |
| **t3.large** | **8GB** | **~$60** | When running multiple subagents regularly |
| t3.xlarge | 16GB | ~$120 | If running Playwright at scale |

## Enrichment Pipeline Memory Tips

### enrich_website.py (Tier 0)
- Sequential by market file: ~30MB per market
- Concurrency 3-5 is safe
- Concurrency 10 will OOM without swap

### enrich_gbp.py (Tier 0.25)
- Very lightweight: ~24MB per market
- Single process, 0.2s delay between API calls
- Safe to run alongside gateway

### enrich_website_js.py (Tier 0.5 — Playwright)
- Headless Chromium: 200-400MB per browser instance
- Concurrency 3 max on 3.7GB instance
- Kill PinchTab first if it's running
- Consider running only on Warm tier (~500 prospects) not full 13K

### enrich_reviews.py (Tier 4 — SerpAPI)
- Lightweight: ~20MB (just HTTP calls)
- Rate limited by SerpAPI, not by memory
- Safe to run anytime
