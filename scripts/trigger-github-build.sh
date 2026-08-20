#!/bin/bash
set -euo pipefail

# Trigger a GitHub Actions "Build and Release" workflow and block while
# streaming its output, so the GitLab job duration matches the GitHub run and
# the logs appear in GitLab as if it were a native runner.

REPO="justacalico/doudou"
WORKFLOW="build.yml"

REF="${1:-main}"
BUILD_ALL="${2:-true}"
CREATE_RELEASE="${3:-false}"
PUSH_REF="${4:-}"

if [ -n "$PUSH_REF" ]; then
  echo "Pushing $PUSH_REF to GitHub branch $REF..."
  git remote add github "git@github.com:$REPO.git" 2>/dev/null || true
  git remote update github
  git push -f github "$PUSH_REF:refs/heads/$REF"
fi

echo "Triggering GitHub workflow: $WORKFLOW @ $REF (build_all=$BUILD_ALL, create_release=$CREATE_RELEASE)"
RUN_URL=$(gh workflow run "$WORKFLOW" -R "$REPO" --ref "$REF" \
  -f build_all="$BUILD_ALL" \
  -f create_release="$CREATE_RELEASE" 2>&1 | head -n 1)

RUN_ID=""
if [[ "$RUN_URL" =~ ^https://github.com/[^/]+/[^/]+/actions/runs/([0-9]+) ]]; then
  RUN_ID="${BASH_REMATCH[1]}"
  echo "GitHub run URL: $RUN_URL"
else
  # Fallback: search the list by commit
  for i in {1..30}; do
    sleep 5
    RUN_ID=$(gh run list -R "$REPO" -w "$WORKFLOW" -b "$REF" -e workflow_dispatch -c "$CI_COMMIT_SHA" -L 1 --json databaseId -q '.[0].databaseId' 2>/dev/null || true)
    [ -n "$RUN_ID" ] && break
  done
fi

if [ -z "$RUN_ID" ]; then
  echo "Could not find GitHub run for $REF @ $CI_COMMIT_SHA" >&2
  exit 1
fi

echo "Watching GitHub run $RUN_ID..."
gh run watch "$RUN_ID" -R "$REPO" --exit-status
