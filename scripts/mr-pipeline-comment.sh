#!/bin/bash
set -euo pipefail

# Post or update a comment on a GitLab merge request so the MR shows the live
# state of the GitHub build. Each GitLab pipeline gets its own comment.

ACTION="${1:-start}"
MR_IID="${CI_MERGE_REQUEST_IID:-}"
PROJECT_ID="${CI_PROJECT_ID:-}"
PIPELINE_ID="${CI_PIPELINE_ID:-}"
JOB_NAME="${CI_JOB_NAME:-}"
RUN_ID="${RUN_ID:-}"

[ -n "$MR_IID" ] || exit 0
[ -n "$PROJECT_ID" ] || exit 0
command -v glab >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

PROJECT_PATH="${CI_PROJECT_PATH:-Openlyst/doudou}"
MARKER="<!-- mr-pipeline-${PIPELINE_ID} -->"
PIPELINE_URL="https://gitlab.com/${PROJECT_PATH}/-/pipelines/${PIPELINE_ID}"
RUN_URL="https://github.com/justacalico/doudou/actions/runs/${RUN_ID}"

post_or_update() {
  local body="$1"
  local note_id
  note_id=$(glab api "projects/${PROJECT_ID}/merge_requests/${MR_IID}/notes?per_page=100" 2>/dev/null | jq -r --arg marker "$MARKER" '.[] | select(.body | contains($marker)) | .id' | head -n1)
  if [ -n "$note_id" ] && [ "$note_id" != "null" ]; then
    glab api --method PUT "projects/${PROJECT_ID}/merge_requests/${MR_IID}/notes/${note_id}" --field "body=${body}" >/dev/null
  else
    glab api --method POST "projects/${PROJECT_ID}/merge_requests/${MR_IID}/notes" --field "body=${body}" >/dev/null
  fi
}

case "$ACTION" in
  start)
    body="${MARKER}
**Pipeline ${PIPELINE_ID}** · ${JOB_NAME} · [in progress](${PIPELINE_URL})

GitHub run: ${RUN_URL:+[View on GitHub](${RUN_URL})}"
    post_or_update "$body"
    ;;

  update)
    body="${MARKER}
**Pipeline ${PIPELINE_ID}** · ${JOB_NAME} · [in progress](${PIPELINE_URL})

GitHub run: [View on GitHub](${RUN_URL})"
    post_or_update "$body"
    ;;

  finish)
    conclusion="${2:-failed}"
    icon="❌"
    [ "$conclusion" = "success" ] && icon="✅"

    jobs=""
    if [ -n "$RUN_ID" ] && command -v gh >/dev/null 2>&1; then
      jobs=$(gh run view "$RUN_ID" -R justacalico/doudou --json jobs 2>/dev/null | jq -r '.jobs[] | select(.conclusion != null or .status != null) | "- **\(.name)**: \(.conclusion // .status)"' || true)
    fi
    [ -n "$jobs" ] || jobs="GitHub job details unavailable."

    body="${MARKER}
**Pipeline ${PIPELINE_ID}** · ${JOB_NAME} · ${icon} ${conclusion}

GitHub run: [View on GitHub](${RUN_URL})
GitLab pipeline: [View on GitLab](${PIPELINE_URL})

GitHub jobs:
${jobs}"
    post_or_update "$body"
    ;;
esac
