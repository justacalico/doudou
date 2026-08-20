FROM ghcr.io/cirruslabs/flutter:stable

USER root
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -qq && \
    apt-get install -y -qq --no-install-recommends \
      clang cmake ninja-build pkg-config \
      libgtk-3-dev liblzma-dev libsecret-1-dev libmpv-dev mpv \
      libayatana-appindicator3-dev libmimalloc-dev libasound2-dev \
      libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
      gstreamer1.0-libav gstreamer1.0-plugins-base \
      dpkg-dev rpm wget file squashfs-tools patchelf libfuse2 zip unzip \
      libstdc++-13-dev && \
    rm -rf /var/lib/apt/lists/*

ENV RUSTUP_HOME=/root/.rustup \
    CARGO_HOME=/root/.cargo
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile minimal && \
    $CARGO_HOME/bin/rustup target add armv7-linux-androideabi aarch64-linux-android x86_64-linux-android
ENV PATH="$CARGO_HOME/bin:$PATH"

RUN mkdir -p /root/.local/bin && \
    curl -fsSL https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage -o /tmp/appimagetool.AppImage && \
    chmod +x /tmp/appimagetool.AppImage && \
    cd /tmp && ./appimagetool.AppImage --appimage-extract && \
    mv /tmp/squashfs-root /tmp/appimagetool && \
    ln -sf /tmp/appimagetool/AppRun /root/.local/bin/appimagetool && \
    /root/.local/bin/appimagetool --version
ENV PATH="/root/.local/bin:$PATH"

# Keep Flutter in PATH and avoid unknown-channel warnings in CI.
ENV FLUTTER_GIT_URL="https://github.com/flutter/flutter.git"

WORKDIR /project
