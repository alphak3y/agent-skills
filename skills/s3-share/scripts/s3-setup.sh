#!/usr/bin/env bash
# s3-setup.sh — Create and configure an S3 bucket for agent file sharing
# Usage: s3-setup.sh <bucket-name> [region] [screenshot-expiry-days]
#
# Creates the bucket, blocks public access, and sets a lifecycle rule
# to auto-expire screenshots after N days (default 30).

set -euo pipefail

BUCKET="${1:?Usage: s3-setup.sh <bucket-name> [region] [expiry-days]}"
REGION="${2:-us-east-1}"
EXPIRY_DAYS="${3:-30}"

echo "Creating bucket: $BUCKET (region: $REGION)"

if [[ "$REGION" == "us-east-1" ]]; then
  aws s3api create-bucket --bucket "$BUCKET" --region "$REGION"
else
  aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION"
fi

echo "Blocking public access..."
aws s3api put-public-access-block --bucket "$BUCKET" --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "Setting lifecycle: screenshots/ expire after ${EXPIRY_DAYS} days..."
aws s3api put-bucket-lifecycle-configuration --bucket "$BUCKET" --lifecycle-configuration "{
  \"Rules\": [{
    \"ID\": \"expire-screenshots-${EXPIRY_DAYS}d\",
    \"Status\": \"Enabled\",
    \"Filter\": {\"Prefix\": \"screenshots/\"},
    \"Expiration\": {\"Days\": ${EXPIRY_DAYS}}
  }]
}"

echo ""
echo "✅ Bucket ready: $BUCKET"
echo ""
echo "Set these env vars for s3-share.sh:"
echo "  export S3_SHARE_BUCKET=$BUCKET"
echo "  export S3_SHARE_REGION=$REGION"
