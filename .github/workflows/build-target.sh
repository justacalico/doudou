#!/usr/bin/env bash
# Builds debug + release artifacts for a single target and drops them in artifacts/.
# Called by .github/workflows/build.yml with the target name as $1.
set -euo pipefail

target="${1:?target required}"
short_sha="${GITHUB_SHA-}"
[ -n "$short_sha" ] && short_sha="${short_sha::7}" || short_sha="local"
out="artifacts"
mkdir -p "$out"

# Tag name (empty for non-tag runs) used to name release artifacts.
tag="${GITHUB_REF#refs/tags/}"
[ "$tag" = "$GITHUB_REF" ] && tag=""
suffix="$short_sha"
[ -n "$tag" ] && suffix="$tag"

build_apk() {
  local flavor="$1"; shift
  local apk_name="$1"; shift
  local extra=("$@")
  local out_apk="build/app/outputs/flutter-apk/app-${flavor}"

  echo "::group::Build ${apk_name} debug"
  flutter build apk --debug --flavor "$flavor" "${extra[@]}"
  cp "${out_apk}-debug.apk" "$out/doudou-${apk_name}-debug-${suffix}.apk"
  echo "::endgroup::"

  echo "::group::Build ${apk_name} release"
  flutter build apk --release --flavor "$flavor" "${extra[@]}"
  cp "${out_apk}-release.apk" "$out/doudou-${apk_name}-release-${suffix}.apk"
  echo "::endgroup::"
}

case "$target" in
  android-phone)
    build_apk phone phone -t lib/main.dart
    ;;
  android-phone-playstore)
    build_apk phone phone-playstore --dart-define=PLAYSTORE=true -Pplaystore=true -t lib/main.dart
    ;;
  android-wear)
    build_apk wear wear -t lib/main_wear.dart
    ;;
  android-tv-playstore)
    build_apk tv tv-playstore --dart-define=PLAYSTORE=true --dart-define=TV=true
    ;;
  android-tv-nonplaystore)
    build_apk tv tv --dart-define=PLAYSTORE=false --dart-define=TV=true
    ;;
  linux)
    echo "::group::Build linux debug"
    flutter build linux --debug
    (cd build/linux/x64/debug && zip -r "$OLDPWD/$out/doudou-linux-debug-${suffix}.zip" bundle)
    echo "::endgroup::"
    echo "::group::Build linux release"
    flutter build linux --release
    (cd build/linux/x64/release && zip -r "$OLDPWD/$out/doudou-linux-release-${suffix}.zip" bundle)
    echo "::endgroup::"
    ;;
  windows)
    echo "::group::Build windows debug"
    flutter build windows --debug
    7z a "$out/doudou-windows-debug-${suffix}.zip" "build/windows/x64/runner/Debug"
    echo "::endgroup::"
    echo "::group::Build windows release"
    flutter build windows --release
    7z a "$out/doudou-windows-release-${suffix}.zip" "build/windows/x64/runner/Release"
    echo "::endgroup::"
    ;;
  macos)
    echo "::group::Build macos debug"
    flutter build macos --debug
    (cd build/macos/Build/Products/Debug && zip -ry "$OLDPWD/$out/doudou-macos-debug-${suffix}.zip" ./*.app)
    echo "::endgroup::"
    echo "::group::Build macos release"
    flutter build macos --release
    (cd build/macos/Build/Products/Release && zip -ry "$OLDPWD/$out/doudou-macos-release-${suffix}.zip" ./*.app)
    echo "::endgroup::"
    ;;
  ios)
    echo "::group::Build ios debug (no codesign)"
    flutter build ios --debug --no-codesign
    (cd build/ios/iphoneos && zip -ry "$OLDPWD/$out/doudou-ios-debug-${suffix}.zip" ./*.app)
    echo "::endgroup::"
    echo "::group::Build ios release (no codesign)"
    flutter build ios --release --no-codesign
    (cd build/ios/iphoneos && zip -ry "$OLDPWD/$out/doudou-ios-release-${suffix}.zip" ./*.app)
    echo "::endgroup::"
    ;;
  *)
    echo "Unknown target: $target" >&2
    exit 1
    ;;
esac

echo "Artifacts for $target:"
ls -la "$out"
