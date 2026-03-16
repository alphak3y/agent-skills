#!/bin/bash
# Compare two screenshots and highlight differences
# Requires ImageMagick (sudo apt install imagemagick)
#
# Usage: visual-diff.sh <before.png> <after.png> [diff_output.png]
#
# Returns exit code 0 if images match, 1 if different
# Outputs the percentage difference to stdout

set -euo pipefail

BEFORE="${1:-}"
AFTER="${2:-}"
DIFF_OUTPUT="${3:-/tmp/visual-diff-$(date +%s).png}"

if [ -z "$BEFORE" ] || [ -z "$AFTER" ]; then
  echo "Usage: visual-diff.sh <before.png> <after.png> [diff_output.png]"
  exit 1
fi

if ! command -v compare &>/dev/null; then
  echo "ImageMagick required. Install with: sudo apt install imagemagick" >&2
  exit 1
fi

# Compare and get the number of differing pixels
RESULT=$(compare -metric AE "$BEFORE" "$AFTER" "$DIFF_OUTPUT" 2>&1 || true)

echo "Differing pixels: $RESULT"
echo "Diff saved: $DIFF_OUTPUT"

if [ "$RESULT" = "0" ]; then
  echo "Images are identical"
  exit 0
else
  echo "Images differ"
  exit 1
fi
