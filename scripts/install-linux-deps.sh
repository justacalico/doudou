#!/usr/bin/env bash
# Install system deps required for flutter build linux (tray_manager needs appindicator).
# Run before flutter build linux in CI or locally.
set -e
sudo apt-get update -qq
sudo apt-get install -y -qq \
  clang cmake ninja-build pkg-config \
  libgtk-3-dev liblzma-dev libstdc++-12-dev libsecret-1-dev libmpv-dev \
  libayatana-appindicator3-dev \
  dpkg-dev rpm wget file squashfs-tools patchelf plocate libfuse2 \
  libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev
