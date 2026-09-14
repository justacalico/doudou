#!/usr/bin/env bash
# Stamp the pubspec version with the CI run number so every CI build is
# uniquely identifiable (version: X.Y.Z becomes X.Y.Z+N). Prints name=value
# lines so callers can pipe the output into $GITHUB_OUTPUT or a build.env.
set -euo pipefail

PUBSPEC="${1:-pubspec.yaml}"
BUILD_NUMBER="${2:-${BUILD_NUMBER:-}}"

if ! [[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "usage: $0 [pubspec.yaml] <build-number>" >&2
  exit 1
fi

VERSION=$(sed -n 's/^version:[[:space:]]*\([^+[:space:]]*\).*/\1/p' "$PUBSPEC" | head -1)
if [ -z "$VERSION" ]; then
  echo "no version field found in $PUBSPEC" >&2
  exit 1
fi

sed -i.bak "s/^version:.*/version: ${VERSION}+${BUILD_NUMBER}/" "$PUBSPEC" && rm -f "$PUBSPEC.bak"

echo "version=$VERSION"
echo "build_number=$BUILD_NUMBER"
echo "full_version=${VERSION}+${BUILD_NUMBER}"
