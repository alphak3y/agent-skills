#!/usr/bin/env bash
# s3-share.sh — Upload a file to S3 and return a presigned URL
# Usage: s3-share.sh <local-file> [prefix] [expiry-seconds]
#
# Requires: aws CLI with credentials (IAM role, env vars, or aws configure)
# Config: Set S3_SHARE_BUCKET and S3_SHARE_REGION env vars, or edit defaults below.

set -euo pipefail

BUCKET="${S3_SHARE_BUCKET:?Set S3_SHARE_BUCKET env var or edit this script}"
REGION="${S3_SHARE_REGION:-us-east-1}"

FILE="${1:?Usage: s3-share.sh <file> [prefix] [expiry-seconds]}"
PREFIX="${2:-screenshots}"
EXPIRY="${3:-86400}"

if [[ ! -f "$FILE" ]]; then
  echo "Error: File not found: $FILE" >&2
  exit 1
fi

BASENAME=$(basename "$FILE")
TIMESTAMP=$(date -u +%Y%m%d-%H%M%S)
KEY="${PREFIX}/${TIMESTAMP}-${BASENAME}"

aws s3 cp "$FILE" "s3://${BUCKET}/${KEY}" --region "$REGION" --quiet
URL=$(aws s3 presign "s3://${BUCKET}/${KEY}" --region "$REGION" --expires-in "$EXPIRY")

echo "$URL"
