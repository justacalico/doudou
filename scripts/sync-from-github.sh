#!/usr/bin/env bash
set -euo pipefail

RELEASE_TAG="${RELEASE_TAG:-}"
GITHUB_RUN_ID="${GITHUB_RUN_ID:-}"
PROJECT_DIR="${CI_PROJECT_DIR:-$PWD}"

cd "$PROJECT_DIR"

# Determine which GitHub release to sync.
if [ -z "$RELEASE_TAG" ]; then
  RELEASE_TAG=$(gh release view -R justacalico/doudou --json tagName -q .tagName)
fi

echo "Syncing GitHub release: $RELEASE_TAG"

# Download assets from the GitHub release.
rm -rf release-assets SHA256SUMS.txt
mkdir -p release-assets
gh release download "$RELEASE_TAG" -R justacalico/doudou --dir release-assets

# Fetch GitHub Actions job logs if a run ID was provided.
if [ -n "$GITHUB_RUN_ID" ]; then
  gh run view "$GITHUB_RUN_ID" -R justacalico/doudou --log > github-logs.txt 2>/dev/null || true
  if [ -s github-logs.txt ]; then
    cp github-logs.txt release-assets/
  fi
fi

# Generate checksums.
cd release-assets
sha256sum * > "$PROJECT_DIR/SHA256SUMS.txt"
cd "$PROJECT_DIR"
cp SHA256SUMS.txt release-assets/

ls -la release-assets/

# Mirror to a GitLab release. The tag is kept the same as GitHub.
# glab in CI will use CI_JOB_TOKEN when GLAB_ENABLE_CI_AUTOLOGIN is set.
glab release create "$RELEASE_TAG" \
  --name "Doudou $RELEASE_TAG" \
  --notes "Mirrored from the GitHub release." \
  --ref "$CI_COMMIT_SHA" \
  "$PROJECT_DIR/release-assets"/*
