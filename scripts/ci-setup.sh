#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-}"

PROJECT_DIR="${CI_PROJECT_DIR:-$PWD}"
PUB_CACHE="${PUB_CACHE:-/tmp/pub-cache-${CI_JOB_ID:-$$}}"
export PUB_CACHE
export PATH="$PUB_CACHE/bin:$PATH"

ensure_flutter() {
  if command -v flutter >/dev/null 2>&1; then
    echo "Flutter: $(which flutter)"
    return
  fi

  for d in /opt/flutter /home/calico/flutter "$HOME/flutter"; do
    if [ -d "$d/bin" ]; then
      export PATH="$d/bin:$PATH"
      echo "Flutter found at $d"
      return
    fi
  done

  local flutter_dir="$HOME/flutter"
  git clone --depth 1 -b "${FLUTTER_CHANNEL:-stable}" https://github.com/flutter/flutter.git "$flutter_dir"
  export PATH="$flutter_dir/bin:$PATH"
  echo "Flutter installed at $flutter_dir"
}

install_linux_deps() {
  if ! command -v apt-get >/dev/null 2>&1; then
    return
  fi

  if [ -f "$PROJECT_DIR/scripts/install-linux-deps.sh" ]; then
    bash "$PROJECT_DIR/scripts/install-linux-deps.sh" || true
  fi
}

install_appimagetool() {
  local arch="$1"
  if command -v appimagetool >/dev/null 2>&1; then
    return
  fi

  local url
  if [ "$arch" = "aarch64" ]; then
    url="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-aarch64.AppImage"
  else
    url="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
  fi

  rm -rf /tmp/appimagetool /tmp/appimagetool.AppImage /tmp/squashfs-root
  curl -fsSL "$url" -o /tmp/appimagetool.AppImage
  chmod +x /tmp/appimagetool.AppImage
  cd /tmp
  ./appimagetool.AppImage --appimage-extract
  mv /tmp/squashfs-root /tmp/appimagetool
  ln -sf /tmp/appimagetool/AppRun /tmp/appimagetool-bin
  export PATH="/tmp:$PATH"
  appimagetool --version || echo "appimagetool installed"
}

setup_java() {
  if [ -d /usr/lib/jvm/java-17-openjdk-* ]; then
    JAVA_HOME=$(ls -d /usr/lib/jvm/java-17-openjdk-* | head -1)
    export JAVA_HOME
  elif command -v apt-get >/dev/null 2>&1; then
    apt-get update -qq || true
    apt-get install -y -qq openjdk-17-jdk || true
    if [ -d /usr/lib/jvm/java-17-openjdk-* ]; then
      JAVA_HOME=$(ls -d /usr/lib/jvm/java-17-openjdk-* | head -1)
      export JAVA_HOME
    fi
  fi

  if [ -n "${JAVA_HOME:-}" ]; then
    export PATH="$JAVA_HOME/bin:$PATH"
    echo "JAVA_HOME=$JAVA_HOME"
  fi
}

setup_android_sdk() {
  local sdk_dir=""

  if [ -n "${ANDROID_HOME:-}" ] && [ -d "$ANDROID_HOME" ]; then
    sdk_dir="$ANDROID_HOME"
  else
    for d in /opt/android-sdk /home/calico/android-sdk /opt/android-studio/sdk "$HOME/android-sdk"; do
      if [ -d "$d" ]; then
        sdk_dir="$d"
        break
      fi
    done
  fi

  if [ -n "$sdk_dir" ]; then
    export ANDROID_HOME="$sdk_dir"
    export ANDROID_SDK_ROOT="$sdk_dir"
    export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$PATH"
    echo "Android SDK found at $sdk_dir"
    if command -v sdkmanager >/dev/null 2>&1; then
      yes | sdkmanager --licenses >/dev/null 2>&1 || true
      sdkmanager "platforms;android-31" "platforms;android-33" "platforms;android-34" "platforms;android-35" "platforms;android-36" "build-tools;35.0.0" "build-tools;36.0.0" "cmake;3.22.1" "ndk;28.2.13676358" >/dev/null 2>&1 || true
    fi
    return
  fi

  if ! command -v curl >/dev/null 2>&1; then
    echo "Android SDK not found and curl is unavailable" >&2
    return
  fi

  local sdk_dir="$HOME/android-sdk"
  local url="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
  mkdir -p "$sdk_dir/cmdline-tools"
  curl -fsSL "$url" -o /tmp/cmdline-tools.zip
  unzip -q -o /tmp/cmdline-tools.zip -d "$sdk_dir/cmdline-tools"
  mv "$sdk_dir/cmdline-tools/cmdline-tools" "$sdk_dir/cmdline-tools/latest"
  export ANDROID_HOME="$sdk_dir"
  export ANDROID_SDK_ROOT="$sdk_dir"
  export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
  yes | sdkmanager --licenses >/dev/null 2>&1 || true
  sdkmanager "platforms;android-36" "build-tools;36.0.0" "ndk;28.2.13676358" >/dev/null 2>&1 || true
  echo "Android SDK installed at $sdk_dir"
}

setup_android_signing() {
  if [ -z "${DOUDOU_KEYSTORE_BASE64:-}" ]; then
    echo "No keystore configured, using debug signing"
    return
  fi

  echo "Setting up release signing..."
  rm -rf "$PROJECT_DIR/android/keystore" "$PROJECT_DIR/android/app/keystore"
  mkdir -p "$PROJECT_DIR/android/keystore" "$PROJECT_DIR/android/app/keystore"
  printf '%s' "$DOUDOU_KEYSTORE_BASE64" | tr -d '\r\n ' | base64 -d > "$PROJECT_DIR/android/keystore/upload-keystore.jks"
  cp "$PROJECT_DIR/android/keystore/upload-keystore.jks" "$PROJECT_DIR/android/app/keystore/upload-keystore.jks"

  local keystore_abs="$PROJECT_DIR/android/keystore/upload-keystore.jks"
  {
    echo "storePassword=$DOUDOU_KEYSTORE_PASSWORD"
    echo "keyPassword=$DOUDOU_KEY_PASSWORD"
    echo "keyAlias=$DOUDOU_KEY_ALIAS"
    echo "storeFile=$keystore_abs"
  } > "$PROJECT_DIR/android/key.properties"
  cp "$PROJECT_DIR/android/key.properties" "$PROJECT_DIR/android/app/key.properties"

  keytool -list -keystore "$keystore_abs" -storepass "$DOUDOU_KEYSTORE_PASSWORD" -alias "$DOUDOU_KEY_ALIAS" -keypass "$DOUDOU_KEY_PASSWORD" >/dev/null
  echo "Release signing is configured"
}

patch_repeat_mode() {
  local audio_handler="$PROJECT_DIR/lib/services/audio/unified_audio_handler.dart"
  if [ ! -f "$audio_handler" ]; then
    return
  fi
  if ! grep -q '\bRepeatMode\b' "$audio_handler"; then
    return
  fi
  perl -i -pe 's/\bRepeatMode\b/AudioRepeatMode/g' "$audio_handler"
  find "$PROJECT_DIR/lib" -name "*.dart" -exec grep -l "unified_audio_handler" {} \; | while read -r f; do
    [ "$f" = "$audio_handler" ] || ! grep -q '\bRepeatMode\b' "$f" || perl -i -pe 's/\bRepeatMode\b/AudioRepeatMode/g' "$f"
  done
}

main() {
  mkdir -p "$PUB_CACHE"
  ensure_flutter
  flutter config --no-analytics

  case "$TARGET" in
    test)
      flutter doctor -v
      flutter pub get
      ;;
    linux-x64)
      install_linux_deps
      install_appimagetool x86_64
      flutter config --enable-linux-desktop
      flutter doctor -v
      flutter pub get
      ;;
    linux-arm64)
      install_linux_deps
      install_appimagetool aarch64
      flutter config --enable-linux-desktop
      flutter doctor -v
      flutter pub get
      ;;
    android-*)
      setup_java
      setup_android_sdk
      setup_android_signing
      patch_repeat_mode
      flutter doctor -v
      flutter pub get
      ;;
    windows)
      flutter doctor -v
      flutter pub get
      ;;
    macos)
      patch_repeat_mode
      flutter config --enable-macos-desktop
      flutter doctor -v
      flutter pub get
      ;;
    ios)
      setup_java
      patch_repeat_mode
      if command -v rustup >/dev/null 2>&1; then
        rustup target add aarch64-apple-ios x86_64-apple-ios aarch64-apple-ios-sim >/dev/null 2>&1 || true
      fi
      flutter doctor -v
      flutter pub get
      ;;
    *)
      flutter doctor -v
      flutter pub get
      ;;
  esac
}

main
