#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-}"
PROJECT_DIR="${CI_PROJECT_DIR:-$PWD}"

PUB_CACHE="${PUB_CACHE:-/tmp/pub-cache-${CI_JOB_ID:-$$}}"
export PUB_CACHE
export PATH="$PUB_CACHE/bin:$PATH"
mkdir -p "$PUB_CACHE"

if [ -f "$PROJECT_DIR/build.env" ]; then
  source "$PROJECT_DIR/build.env"
fi

VERSION="${VERSION:-$(grep '^version:' "$PROJECT_DIR/pubspec.yaml" | sed 's/version: //g' | cut -d'+' -f1)}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%s | cut -c4-10)}"
BUILD_DATE="${BUILD_DATE:-$(date +%Y-%m-%d)}"

APK_DIR="$PROJECT_DIR/build/app/outputs/flutter-apk"
AAB_DIR="$PROJECT_DIR/build/app/outputs/bundle"
ARTIFACTS_DIR="$PROJECT_DIR/artifacts"

build_apk() {
  local flavor="$1" name="$2"
  shift 2
  flutter build apk --release --flavor "$flavor" "$@" --build-name="$VERSION" --build-number="$BUILD_NUMBER"
  cp "$APK_DIR/app-${flavor}-release.apk" "$ARTIFACTS_DIR/doudou-${name}-${VERSION}-${BUILD_DATE}.apk"
}

build_aab() {
  local flavor="$1" name="$2"
  shift 2
  flutter build appbundle --release --flavor "$flavor" "$@" --build-name="$VERSION" --build-number="$BUILD_NUMBER"
  cp "$AAB_DIR/${flavor}Release/app-${flavor}-release.aab" "$ARTIFACTS_DIR/doudou-${name}-${VERSION}-${BUILD_DATE}.aab"
}

mkdir -p "$ARTIFACTS_DIR"

case "$TARGET" in
  android-phone)
    build_apk phone phone -t lib/main.dart
    if [ -n "${CI_COMMIT_TAG:-}" ] || [ "${BUILD_ALL:-}" = "true" ] || [ "${BUILD_AAB:-}" = "true" ]; then
      build_aab phone phone -t lib/main.dart
    fi
    ;;
  android-phone-playstore)
    build_aab phone phone-playstore --dart-define=PLAYSTORE=true -Pplaystore=true -t lib/main.dart
    ;;
  android-wear)
    build_apk wear wear -t lib/main_wear.dart
    build_aab wear wear -t lib/main_wear.dart
    ;;
  android-tv-playstore)
    build_apk tv tv-playstore --dart-define=PLAYSTORE=true --dart-define=TV=true
    build_aab tv tv-playstore --dart-define=PLAYSTORE=true --dart-define=TV=true
    ;;
  android-tv)
    build_apk tv tv --dart-define=PLAYSTORE=false --dart-define=TV=true
    build_aab tv tv --dart-define=PLAYSTORE=false --dart-define=TV=true
    ;;
  linux-x64)
    flutter build linux --release --build-name="$VERSION"
    (cd "$PROJECT_DIR/build/linux/x64/release" && zip -r "$ARTIFACTS_DIR/doudou-linux-x64-${VERSION}-${BUILD_DATE}.zip" bundle/)
    dart pub global activate fastforge
    fastforge package --platform linux --targets deb --skip-clean || echo "DEB build had warnings"
    fastforge package --platform linux --targets rpm --skip-clean || echo "RPM build had warnings"
    fastforge package --platform linux --targets appimage --skip-clean || echo "AppImage build had warnings"
    find "$PROJECT_DIR/dist" -name "*.deb" -exec cp {} "$ARTIFACTS_DIR/doudou-linux-amd64-${VERSION}-${BUILD_DATE}.deb" \; 2>/dev/null || true
    find "$PROJECT_DIR/dist" -name "*.rpm" -exec cp {} "$ARTIFACTS_DIR/doudou-linux-amd64-${VERSION}-${BUILD_DATE}.rpm" \; 2>/dev/null || true
    find "$PROJECT_DIR/dist" -name "*.AppImage" -exec cp {} "$ARTIFACTS_DIR/doudou-linux-x86_64-${VERSION}-${BUILD_DATE}.AppImage" \; 2>/dev/null || true
    ;;
  linux-arm64)
    flutter build linux --release --build-name="$VERSION"
    (cd "$PROJECT_DIR/build/linux/arm64/release" && zip -r "$ARTIFACTS_DIR/doudou-linux-arm64-${VERSION}-${BUILD_DATE}.zip" bundle/)
    dart pub global activate fastforge
    fastforge package --platform linux --targets deb --skip-clean || echo "DEB build had warnings"
    fastforge package --platform linux --targets rpm --skip-clean || echo "RPM build had warnings"
    fastforge package --platform linux --targets appimage --skip-clean || echo "AppImage build had warnings"
    find "$PROJECT_DIR/dist" -name "*.deb" -exec cp {} "$ARTIFACTS_DIR/doudou-linux-arm64-${VERSION}-${BUILD_DATE}.deb" \; 2>/dev/null || true
    find "$PROJECT_DIR/dist" -name "*.rpm" -exec cp {} "$ARTIFACTS_DIR/doudou-linux-arm64-${VERSION}-${BUILD_DATE}.rpm" \; 2>/dev/null || true
    find "$PROJECT_DIR/dist" -name "*.AppImage" -exec cp {} "$ARTIFACTS_DIR/doudou-linux-aarch64-${VERSION}-${BUILD_DATE}.AppImage" \; 2>/dev/null || true
    ;;
  windows)
    flutter build windows --release
    if command -v 7z >/dev/null 2>&1; then
      7z a "$ARTIFACTS_DIR/doudou-windows-x64-${VERSION}-${BUILD_DATE}.zip" "$PROJECT_DIR/build/windows/x64/runner/Release"
    else
      (cd "$PROJECT_DIR/build/windows/x64/runner/Release" && zip -r "$ARTIFACTS_DIR/doudou-windows-x64-${VERSION}-${BUILD_DATE}.zip" .)
    fi
    ;;
  macos)
    flutter config --enable-macos-desktop
    flutter build macos --release --build-name="$VERSION"
    (cd "$PROJECT_DIR/macos" && /usr/libexec/PlistBuddy -c "Set :buildSettings:CODE_SIGN_IDENTITY ''" Runner.xcodeproj/project.pbxproj 2>/dev/null || true)
    xcodebuild -project "$PROJECT_DIR/macos/Runner.xcodeproj" -scheme Runner -configuration Release CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -derivedDataPath "$PROJECT_DIR/build/macos_unsigned" || true
    (cd "$PROJECT_DIR/build/macos/Build/Products/Release" && zip -r "$ARTIFACTS_DIR/doudou-macos-${VERSION}-${BUILD_DATE}.zip" *.app)
    ;;
  ios)
    bash "$PROJECT_DIR/scripts/build-ios.sh"
    dart run flutter_rust_bridge_codegen build-ios --release || true
    flutter build ios --release --no-codesign
    mkdir -p "$PROJECT_DIR/Payload"
    cp -r "$PROJECT_DIR/build/ios/iphoneos/Runner.app" "$PROJECT_DIR/Payload/"
    (cd "$PROJECT_DIR" && zip -r "$ARTIFACTS_DIR/doudou-ios-${VERSION}-${BUILD_DATE}.ipa" Payload/)
    rm -rf "$PROJECT_DIR/Payload"
    ;;
  *)
    echo "Unknown target: $TARGET" >&2
    exit 1
    ;;
esac

if [[ "$TARGET" == android* ]]; then
  apksigner=""
  if [ -n "${ANDROID_HOME:-}" ] && [ -d "$ANDROID_HOME/build-tools" ]; then
    apksigner=$(find "$ANDROID_HOME/build-tools" -name apksigner -type f | sort -V | tail -1 || true)
  fi
  for pkg in "$ARTIFACTS_DIR"/*.apk "$ARTIFACTS_DIR"/*.aab; do
    [ -f "$pkg" ] || continue
    echo "Verifying $pkg..."
    if [[ "$pkg" == *.apk ]]; then
      if [ -n "$apksigner" ] && [ -x "$apksigner" ]; then
        "$apksigner" verify "$pkg" >/dev/null 2>&1 || { echo "APK signature verification failed: $pkg" >&2; exit 1; }
      else
        jarsigner -verify "$pkg" >/dev/null 2>&1 || { echo "APK signature verification failed: $pkg" >&2; exit 1; }
      fi
    else
      jarsigner -verify "$pkg" >/dev/null 2>&1 || { echo "AAB signature verification failed: $pkg" >&2; exit 1; }
    fi
    echo "Verified: $pkg"
  done
fi

ls -la "$ARTIFACTS_DIR/"
