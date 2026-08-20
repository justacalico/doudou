#!/usr/bin/env bash
set -euo pipefail

TYPE="${1:-}"
PROJECT_DIR="${CI_PROJECT_DIR:-$PWD}"

if [ -f "$PROJECT_DIR/build.env" ]; then
  source "$PROJECT_DIR/build.env"
fi

VERSION="${VERSION:-$(grep '^version:' "$PROJECT_DIR/pubspec.yaml" | sed 's/version: //g' | cut -d'+' -f1)}"
BUILD_DATE="${BUILD_DATE:-$(date +%Y-%m-%d)}"
SHORT_SHA="${SHORT_SHA:-${CI_COMMIT_SHORT_SHA:-}}"

ensure_glab() {
  if command -v glab >/dev/null 2>&1; then
    return
  fi

  local version="${GLAB_VERSION:-1.106.0}"
  local arch="${CI_RUNNER_ARCH:-amd64}"
  case "$arch" in
    arm|armv7l) arch="armv6" ;;
    aarch64|arm64) arch="arm64" ;;
    386|i386) arch="386" ;;
    x86_64|amd64) arch="amd64" ;;
  esac

  local url="https://gitlab.com/gitlab-org/cli/-/releases/v${version}/downloads/glab_${version}_linux_${arch}.tar.gz"
  mkdir -p "$HOME/.local/bin"
  curl -fsSL "$url" -o /tmp/glab.tar.gz
  tar -xzf /tmp/glab.tar.gz -C /tmp --strip-components=1
  install /tmp/glab "$HOME/.local/bin/glab" 2>/dev/null || cp /tmp/glab "$HOME/.local/bin/glab"
  chmod +x "$HOME/.local/bin/glab"
  export PATH="$HOME/.local/bin:$PATH"
  glab --version
}

ensure_glab

mkdir -p "$PROJECT_DIR/release-assets"
find "$PROJECT_DIR/artifacts" -type f \( \
  -name "*.apk" -o -name "*.aab" -o -name "*.tar.gz" -o -name "*.zip" -o \
  -name "*.ipa" -o -name "*.exe" -o -name "*.deb" -o -name "*.rpm" -o -name "*.AppImage" \
\) -exec cp {} "$PROJECT_DIR/release-assets/" \;
ls -la "$PROJECT_DIR/release-assets/"

cd "$PROJECT_DIR/release-assets"
sha256sum * > "$PROJECT_DIR/SHA256SUMS.txt"
cd "$PROJECT_DIR"
cp SHA256SUMS.txt release-assets/
ls -la "$PROJECT_DIR/SHA256SUMS.txt"

if [ "$TYPE" = "nightly" ]; then
  TAG="nightly"
  NAME="Nightly Build"
  NOTES="Automated nightly build from commit ${CI_COMMIT_SHA}

- Branch: ${CI_COMMIT_REF_NAME}
- Version: ${VERSION}
- Build: #${CI_PIPELINE_ID}
- Date: ${BUILD_DATE}
- Commit: ${CI_COMMIT_SHA}

This release is automatically updated on every push. Artifacts are untested nightly builds."
else
  if [ -n "${CI_COMMIT_TAG:-}" ]; then
    TAG="$CI_COMMIT_TAG"
  else
    TAG="v$VERSION"
  fi
  NAME="Doudou $TAG"
  NOTES="## Doudou $TAG

- Build: #${CI_PIPELINE_ID}
- Date: ${BUILD_DATE}
- Commit: ${CI_COMMIT_SHA}

### Artifacts
- Android Phone: APK + AAB
- Android Play Store: AAB
- Android Wear OS: APK + AAB
- Android TV: APK + AAB
- Android TV Play Store: APK + AAB
- Linux x64: zip + deb + rpm + AppImage

### Verification
SHA256 checksums are in \`SHA256SUMS.txt\`. Verify with:

\`\`\`
sha256sum -c SHA256SUMS.txt --ignore-missing
\`\`\`"
fi

glab release create "$TAG" \
  --name "$NAME" \
  --notes "$NOTES" \
  --ref "$CI_COMMIT_SHA" \
  --use-package-registry \
  "$PROJECT_DIR/release-assets"/*
