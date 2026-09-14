#!/usr/bin/env bash
# Tests for scripts/stamp-ci-version.sh. Runs the script against a temp
# pubspec and asserts on the rewritten version line and printed output.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/stamp-ci-version.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

write_pubspec() {
  printf 'name: doudou\nversion: %s\n' "$1" > "$TMP/pubspec.yaml"
}

# Case 1: plain version gets the build number appended.
write_pubspec "22.0.0"
out="$(bash "$SCRIPT" "$TMP/pubspec.yaml" 42)"
grep -q '^version: 22.0.0+42$' "$TMP/pubspec.yaml" || fail "version not stamped"
echo "$out" | grep -q '^version=22.0.0$' || fail "version output wrong"
echo "$out" | grep -q '^build_number=42$' || fail "build_number output wrong"
echo "$out" | grep -q '^full_version=22.0.0+42$' || fail "full_version output wrong"

# Case 2: an existing build number is replaced, not appended twice.
write_pubspec "22.0.0+7"
bash "$SCRIPT" "$TMP/pubspec.yaml" 43 >/dev/null
grep -q '^version: 22.0.0+43$' "$TMP/pubspec.yaml" || fail "existing build number not replaced"

# Case 3: build number can come from the BUILD_NUMBER env var.
write_pubspec "1.2.3"
BUILD_NUMBER=9 bash "$SCRIPT" "$TMP/pubspec.yaml" >/dev/null
grep -q '^version: 1.2.3+9$' "$TMP/pubspec.yaml" || fail "BUILD_NUMBER env not used"

# Case 4: missing build number fails and leaves the file untouched.
write_pubspec "22.0.0"
if bash "$SCRIPT" "$TMP/pubspec.yaml" >/dev/null 2>&1; then
  fail "script should fail without a build number"
fi
grep -q '^version: 22.0.0$' "$TMP/pubspec.yaml" || fail "pubspec modified on failure"

# Case 5: non-numeric build number fails.
if bash "$SCRIPT" "$TMP/pubspec.yaml" abc >/dev/null 2>&1; then
  fail "script should fail with non-numeric build number"
fi

# Case 6: missing version field fails.
printf 'name: doudou\n' > "$TMP/pubspec.yaml"
if bash "$SCRIPT" "$TMP/pubspec.yaml" 5 >/dev/null 2>&1; then
  fail "script should fail when version field is missing"
fi

echo "All stamp-ci-version tests passed"
