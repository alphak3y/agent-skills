#!/bin/bash
# Run Lighthouse audit on a URL
# Usage: lighthouse.sh <url> [output_dir]
#
# Outputs JSON report + summary to stdout

set -euo pipefail

URL="${1:-}"
OUTPUT_DIR="${2:-/tmp}"

if [ -z "$URL" ]; then
  echo "Usage: lighthouse.sh <url> [output_dir]"
  exit 1
fi

TIMESTAMP=$(date +%s)
JSON_OUT="${OUTPUT_DIR}/lighthouse-${TIMESTAMP}.json"
HTML_OUT="${OUTPUT_DIR}/lighthouse-${TIMESTAMP}.html"

if ! command -v lighthouse &>/dev/null; then
  echo "Installing lighthouse..."
  npm install -g lighthouse 2>&1 | tail -1
fi

lighthouse "$URL" \
  --chrome-flags="--headless --no-sandbox" \
  --output=json,html \
  --output-path="${OUTPUT_DIR}/lighthouse-${TIMESTAMP}" \
  --quiet 2>&1

# Extract scores
node -e "
const r = require('${JSON_OUT}');
const scores = {
  performance: Math.round(r.categories.performance.score * 100),
  accessibility: Math.round(r.categories.accessibility.score * 100),
  bestPractices: Math.round(r.categories['best-practices'].score * 100),
  seo: Math.round(r.categories.seo.score * 100)
};
console.log(JSON.stringify(scores, null, 2));
console.log('Reports:', '${JSON_OUT}', '${HTML_OUT}');
"
