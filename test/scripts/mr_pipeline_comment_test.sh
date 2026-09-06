#!/usr/bin/env bash
# Tests for scripts/mr-pipeline-comment.sh. Stubs out curl and gh so the
# comment body can be captured and asserted on without hitting real APIs.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/mr-pipeline-comment.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/bin"
CAPTURE_FILE="$TMP/captured_body"
GH_MODE="${GH_MODE:-ok}"

cat > "$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
# Stub gh: returns canned job/artifact data, or fails when GH_MODE=fail.
if [ "${GH_MODE:-ok}" = "fail" ]; then
  exit 1
fi
for arg in "$@"; do
  case "$arg" in
    *artifacts*)
      cat <<'JSON'
{"artifacts":[
  {"id":111,"name":"doudou-phone","expired":false},
  {"id":222,"name":"doudou-linux-x64","expired":false},
  {"id":333,"name":"doudou-old","expired":true}
]}
JSON
      exit 0
      ;;
    view)
      cat <<'JSON'
{"jobs":[{"name":"Build android-phone","conclusion":"success","status":"completed"}]}
JSON
      exit 0
      ;;
  esac
done
exit 0
EOF
chmod +x "$TMP/bin/gh"

cat > "$TMP/bin/curl" <<'EOF'
#!/usr/bin/env bash
# Stub curl: note list GET returns [], POST/PUT captures the body param.
body=""
while [ $# -gt 0 ]; do
  case "$1" in
    --data-urlencode)
      shift
      case "$1" in
        body=*) body="${1#body=}" ;;
      esac
      ;;
    *notes?per_page=100*)
      echo '[]'
      ;;
  esac
  shift
done
if [ -n "$body" ]; then
  printf '%s' "$body" > "$CAPTURE_FILE"
fi
echo '{}'
exit 0
EOF
chmod +x "$TMP/bin/curl"

run_script() {
  env -i \
    PATH="$TMP/bin:/usr/bin:/bin" \
    CAPTURE_FILE="$CAPTURE_FILE" \
    GH_MODE="${GH_MODE:-ok}" \
    CI_MERGE_REQUEST_IID=42 \
    CI_PROJECT_ID=1234 \
    CI_PIPELINE_ID=555 \
    CI_JOB_NAME=github-mr-build \
    CI_SERVER_URL=https://gitlab.com \
    CI_PROJECT_PATH=Openlyst/doudou \
    GITLAB_MR_COMMENT_TOKEN=dummy \
    RUN_ID=12345 \
    bash "$SCRIPT" "$@"
}

fail() { echo "FAIL: $1" >&2; exit 1; }

# Case 1: finish success posts job list plus artifact download links.
GH_MODE=ok run_script finish success
body="$(cat "$CAPTURE_FILE")"
echo "$body" | grep -q 'Build android-phone' || fail "job list missing"
echo "$body" | grep -q 'Downloads (GitHub sign-in required)' || fail "downloads section missing"
echo "$body" | grep -q '\[doudou-phone\](https://github.com/justacalico/doudou/actions/runs/12345/artifacts/111)' || fail "phone artifact link missing"
echo "$body" | grep -q '\[doudou-linux-x64\](https://github.com/justacalico/doudou/actions/runs/12345/artifacts/222)' || fail "linux artifact link missing"
echo "$body" | grep -q 'doudou-old' && fail "expired artifact was listed"

# Case 2: gh unavailable/failing still posts the comment without downloads.
rm -f "$CAPTURE_FILE"
GH_MODE=fail run_script finish success
body="$(cat "$CAPTURE_FILE")"
echo "$body" | grep -q 'GitHub job details unavailable' || fail "fallback text missing"
echo "$body" | grep -q 'Downloads' && fail "downloads section should be absent when gh fails"

# Case 3: start action still posts a normal comment.
rm -f "$CAPTURE_FILE"
GH_MODE=ok run_script start
body="$(cat "$CAPTURE_FILE")"
echo "$body" | grep -q 'in progress' || fail "start comment missing"

echo "All mr-pipeline-comment tests passed"
