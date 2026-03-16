#!/bin/bash
# Upload an image to S3 and return a public URL
# Usage: share-image.sh <image_path> [bucket] [prefix]
#
# Examples:
#   share-image.sh ./screenshot.png                          → upload to default bucket
#   share-image.sh ./screenshot.png my-bucket                → upload to specific bucket
#   share-image.sh ./screenshot.png my-bucket screenshots    → upload with prefix
#
# Environment:
#   SHARE_BUCKET  — default S3 bucket (fallback if no bucket arg)
#   AWS credentials via IAM role, env vars, or ~/.aws/credentials
#
# Returns the public URL on stdout.

set -euo pipefail

IMAGE="${1:-}"
BUCKET="${2:-${SHARE_BUCKET:-}}"
PREFIX="${3:-screenshots}"

if [ -z "$IMAGE" ]; then
  echo "Usage: share-image.sh <image_path> [bucket] [prefix]"
  echo ""
  echo "Set SHARE_BUCKET env var or pass bucket as second arg."
  exit 1
fi

if [ -z "$BUCKET" ]; then
  echo "Error: No S3 bucket specified. Set SHARE_BUCKET or pass as argument." >&2
  exit 1
fi

if [ ! -f "$IMAGE" ]; then
  echo "Error: File not found: $IMAGE" >&2
  exit 1
fi

# Determine content type
EXT="${IMAGE##*.}"
case "$EXT" in
  png)  CONTENT_TYPE="image/png" ;;
  jpg|jpeg) CONTENT_TYPE="image/jpeg" ;;
  gif)  CONTENT_TYPE="image/gif" ;;
  webp) CONTENT_TYPE="image/webp" ;;
  pdf)  CONTENT_TYPE="application/pdf" ;;
  *)    CONTENT_TYPE="application/octet-stream" ;;
esac

# Generate a unique key
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BASENAME=$(basename "$IMAGE")
KEY="${PREFIX}/${TIMESTAMP}-${BASENAME}"

# Upload with public-read ACL
aws s3 cp "$IMAGE" "s3://${BUCKET}/${KEY}" \
  --content-type "$CONTENT_TYPE" \
  --acl public-read \
  --quiet 2>/dev/null || \
aws s3 cp "$IMAGE" "s3://${BUCKET}/${KEY}" \
  --content-type "$CONTENT_TYPE" \
  --quiet

# Construct URL
REGION=$(aws configure get region 2>/dev/null || echo "us-east-2")
URL="https://${BUCKET}.s3.${REGION}.amazonaws.com/${KEY}"

echo "$URL"
