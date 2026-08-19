#!/usr/bin/env bash
set -euo pipefail

if [ ! -f coverage/lcov.info ]; then
  echo "No coverage file generated"
  exit 1
fi

TOTAL_LINES=0
COVERED_LINES=0

while IFS= read -r line; do
  case "$line" in
    DA:*)
      hits=$(echo "$line" | cut -d: -f2 | cut -d, -f2)
      TOTAL_LINES=$((TOTAL_LINES + 1))
      if [ "$hits" -gt 0 ]; then
        COVERED_LINES=$((COVERED_LINES + 1))
      fi
      ;;
  esac
done < coverage/lcov.info

if [ "$TOTAL_LINES" -eq 0 ]; then
  echo "No coverage data found"
  exit 1
fi

PERCENTAGE=$((COVERED_LINES * 100 / TOTAL_LINES))
echo "Total lines: $TOTAL_LINES"
echo "Covered lines: $COVERED_LINES"
echo "Coverage: ${PERCENTAGE}%"

if [ "$PERCENTAGE" -lt 5 ]; then
  echo "Coverage ${PERCENTAGE}% is below threshold 5%"
  exit 1
fi

echo "Coverage ${PERCENTAGE}% meets threshold 5%"
