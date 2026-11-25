#!/usr/bin/env bash
# Tests for scripts/trigger-github-build.sh. Stubs gh and checks which run
# the script ends up watching, an older dispatch that is still in flight on
# the same branch must be skipped.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/trigger-github-build.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

mkdir -p "$TMP/bin"
PAYLOAD_DIR="$TMP/payloads"
COUNT_FILE="$TMP/api_count"
WATCHED_FILE="$TMP/watched_run"
mkdir -p "$PAYLOAD_DIR"

cat > "$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "workflow" ] && [ "$2" = "run" ]; then
  exit 0
fi
if [ "$1" = "api" ]; then
  count=0
  [ -f "$GH_FAKE_COUNT" ] && count=$(cat "$GH_FAKE_COUNT")
  count=$((count + 1))
  echo "$count" > "$GH_FAKE_COUNT"
  payload="$GH_FAKE_PAYLOAD_DIR/$count.json"
  [ -f "$payload" ] || payload="$GH_FAKE_PAYLOAD_DIR/last.json"
  cat "$payload"
  exit 0
fi
if [ "$1" = "run" ] && [ "$2" = "watch" ]; then
  echo "$3" > "$GH_FAKE_WATCHED"
  exit 0
fi
exit 1
EOF
chmod +x "$TMP/bin/gh"

export PATH="$TMP/bin:$PATH"
export GH_FAKE_COUNT="$COUNT_FILE"
export GH_FAKE_PAYLOAD_DIR="$PAYLOAD_DIR"
export GH_FAKE_WATCHED="$WATCHED_FILE"

NOW=$(date +%s)
OLD_TS=$(date -u -d "@$((NOW - 600))" +%Y-%m-%dT%H:%M:%SZ)
NEW_TS=$(date -u -d "@$((NOW + 600))" +%Y-%m-%dT%H:%M:%SZ)

# First poll sees only a stale run started before this dispatch. Second poll
# sees the stale run plus the fresh dispatch. The script must keep polling
# and end up watching the fresh run.
cat > "$PAYLOAD_DIR/1.json" <<EOF
{"workflow_runs":[{"id":111,"created_at":"$OLD_TS"}]}
EOF
cat > "$PAYLOAD_DIR/last.json" <<EOF
{"workflow_runs":[{"id":222,"created_at":"$NEW_TS"},{"id":111,"created_at":"$OLD_TS"}]}
EOF

bash "$SCRIPT" testbranch true false >/dev/null 2>&1
[ -f "$WATCHED_FILE" ] || fail "script never watched a run"
[ "$(cat "$WATCHED_FILE")" = "222" ] || fail "watched stale run $(cat "$WATCHED_FILE") instead of 222"

# When every listed run predates the dispatch the script must give up with
# a failure instead of watching a stale run.
rm -f "$WATCHED_FILE" "$COUNT_FILE" "$PAYLOAD_DIR"/[0-9]*.json
cat > "$PAYLOAD_DIR/last.json" <<EOF
{"workflow_runs":[{"id":111,"created_at":"$OLD_TS"}]}
EOF

if bash "$SCRIPT" testbranch true false >/dev/null 2>&1; then
  fail "script should fail when only stale runs exist"
fi
[ ! -f "$WATCHED_FILE" ] || fail "script watched a stale run"

echo "All trigger-github-build tests passed"
