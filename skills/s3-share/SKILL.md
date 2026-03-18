---
name: s3-share
description: Share files between agents via S3 presigned URLs. Use when uploading screenshots, images, documents, or any files to S3 for cross-agent handoffs, sharing with users, or temporary file hosting. Handles bucket setup, upload, and signed URL generation. Requires AWS credentials (IAM role, env vars, or aws configure).
---

# S3 Share

Upload files to S3 and get presigned URLs for sharing. Designed for multi-agent workflows where agents need to pass files (screenshots, reports, assets) to each other or to users.

## Prerequisites

- `aws` CLI installed and configured with S3 permissions
- Environment variables set:
  - `S3_SHARE_BUCKET` — bucket name (required)
  - `S3_SHARE_REGION` — AWS region (default: `us-east-1`)

## First-Time Setup

Run the setup script to create and configure a bucket:

```bash
{baseDir}/scripts/s3-setup.sh my-bucket-name us-east-2 30
```

This creates the bucket with public access blocked and a lifecycle rule to auto-expire `screenshots/` after 30 days.

Then set the env vars (add to shell profile for persistence):

```bash
export S3_SHARE_BUCKET=my-bucket-name
export S3_SHARE_REGION=us-east-2
```

## Sharing Files

```bash
# Upload screenshot, get 24-hour signed URL
{baseDir}/scripts/s3-share.sh screenshot.png

# Custom prefix and 7-day expiry
{baseDir}/scripts/s3-share.sh mockup.png designs 604800

# Short-lived link (1 hour)
{baseDir}/scripts/s3-share.sh report.pdf reports 3600
```

Output is a single presigned URL line, ready to paste into messages or handoff docs.

## Defaults

| Parameter | Default | Notes |
|-----------|---------|-------|
| prefix | `screenshots` | S3 key prefix / folder |
| expiry | `86400` (24h) | Presigned URL validity in seconds |
| max expiry | `604800` (7d) | AWS limit for presigned URLs |

## Multi-Agent Usage

When handing off files between agents:

1. Upload the file: `URL=$({baseDir}/scripts/s3-share.sh file.png)`
2. Include the URL in the handoff document or message
3. Receiving agent can use `curl -o file.png "$URL"` to download

For batch uploads, loop over files:

```bash
for f in output/*.png; do
  {baseDir}/scripts/s3-share.sh "$f" batch-results
done
```
