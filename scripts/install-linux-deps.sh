#!/usr/bin/env bash
# Install system deps required for flutter build linux (tray_manager needs appindicator).
# Run before flutter build linux in CI or locally.
set -e

SUDO=""
if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
fi

$SUDO apt-get update -qq

GCC_DEV=""
if apt-cache show libstdc++-13-dev >/dev/null 2>&1; then
  GCC_DEV="libstdc++-13-dev"
elif apt-cache show libstdc++-12-dev >/dev/null 2>&1; then
  GCC_DEV="libstdc++-12-dev"
fi

$SUDO apt-get install -y -qq --no-install-recommends \
  clang cmake ninja-build pkg-config \
  libgtk-3-dev liblzma-dev libsecret-1-dev libmpv-dev mpv \
  libayatana-appindicator3-dev libmimalloc-dev libasound2-dev \
  libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
  gstreamer1.0-libav gstreamer1.0-plugins-base \
  dpkg-dev rpm wget file squashfs-tools patchelf libfuse2 zip unzip \
  $GCC_DEV
