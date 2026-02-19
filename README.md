# 🎵 Doudou

<p align="center">
  <img src="https://openlyst.ink/apps/doudou/icon.png" alt="Doudou" width="120">
</p>


# !!! THIS PROJECT IS BEING REWRITTEN !!!
# https://gitlab.com/httpAnimations/doudou


<p align="center">
  <strong>Your music. Your server. Your rules.</strong>
</p>

<p align="center">
  <a href="https://gitlab.com/Openlyst/doudou/-/pipelines"><img src="https://img.shields.io/gitlab/pipeline-status/Openlyst%2Fdoudou?branch=main&style=for-the-badge" alt="CI status"></a>
  <a href="https://gitlab.com/Openlyst/doudou/-/releases"><img src="https://img.shields.io/gitlab/v/release/Openlyst%2Fdoudou?style=for-the-badge" alt="Latest release"></a>
  <a href="https://gitlab.com/Openlyst/doudou/-/discussions"><img src="https://img.shields.io/badge/Community-Discussions-blue?style=for-the-badge" alt="Community"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-GPL--3.0-green.svg?style=for-the-badge" alt="GPL-3.0 License"></a>
</p>

**Doudou** is a privacy-focused music player for your media server. Stream your entire music collection with a modern, responsive interface that works across all your devices — no tracking, no ads, no cloud services required.

Connect to your existing Jellyfin, Plex, or Subsonic server and start listening in seconds. Or just play local files directly from your device — no server needed.

[Website](https://openlyst.ink/apps/doudou) · [Download](https://openlyst.ink/apps/doudou) · [Bug Reports](https://gitlab.com/Openlyst/doudou/issues) · [Feature Requests](https://gitlab.com/Openlyst/doudou/issues) · [Discussions](https://gitlab.com/Openlyst/doudou/-/discussions) · [Email Support](mailto:support@openlyst.com)

## Supported Backends

| Backend | Status | Notes |
|---|---|---|
| **Subsonic** | ✅ Full support | Recommended — free, full feature parity |
| **Jellyfin** | ✅ Full support | Requires Jellyfin 10.8+ |
| **Plex** | ✅ Working | Requires Plex Pass; report issues and they'll be fixed |
| **SoundCloud** | 🧪 Experimental | Authentication required |
| **YouTube Music** | 🧪 Experimental | Partial support |
| **Local Files** | ✅ Full support | No server required |

## Features

### 🔒 Privacy First
No data collection, analytics, or telemetry. No ads or third-party trackers. Doudou connects directly to your server and nowhere else — all your data stays on your devices.

### 🎧 Playback
- Gapless audio with smooth crossfades
- Drag-and-drop queue management
- Radio mode for continuous playback
- High-quality format support: MP3, FLAC, AAC, OGG, M4A, WAV, WMA, OPUS, AIFF, ALAC, APE, WEBM
- Automatic transcoding support

### 📁 Local Music
- Play music directly from your filesystem — no server needed
- Album artwork from embedded metadata, local images, or online sources (MusicBrainz / Cover Art Archive)
- Create and manage local playlists

### 📱 Platforms
- Android, iOS, macOS, Linux, Windows
- Android Auto integration
- Background playback
- Offline listening with downloads

## How It Works

```
Jellyfin / Plex / Subsonic / SoundCloud / YouTube Music / Local Files
                           │
                           ▼
              ┌────────────────────────┐
              │         Doudou         │
              │    (your music player) │
              └────────────┬───────────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
          Android        iOS /       Desktop
                         macOS    (Win/Mac/Linux)
```

## Requirements

- **Media server** (optional): Jellyfin 10.8+, Plex with Plex Pass, any Subsonic-compatible server, or Swing Music
- **Device**: Android 5.0+, iOS 12.0+, macOS 10.15+, Linux, or Windows 10+

## Download

**[Download for all platforms →](https://openlyst.ink/apps/doudou)**

Available for Android, iOS, macOS, Windows, and Linux.

## Setup

1. Open Doudou and tap **Add Server**
2. Select your server type (Jellyfin, Plex, Subsonic, or SoundCloud)
3. Sign in with your credentials
4. Your library will sync and you can start streaming

For local files, skip server setup entirely — just open the app and browse your device.

## FAQ

**Do I need a media server?**
No. You can play local files directly from your device without any server. SoundCloud is also available without self-hosting.

**Can I use Doudou away from home?**
Yes, as long as your media server is accessible over the internet.

**How do I download music for offline listening?**
Long-press any song, album, or playlist and select "Download for offline listening." Note: downloading is only available for self-hosted and local content. We do not support downloading from online providers.

**Which backend works best?**
Subsonic offers the best experience with full feature support and is completely free. For cloud-based listening without a server, SoundCloud is the recommended option.

**Is this affiliated with Jellyfin, Plex, or Subsonic?**
No. Doudou is an independent client that uses their public APIs.

## Building from Source

### Prerequisites

- Flutter SDK 3.8.0 or higher
- Dart SDK 3.8.0 or higher
- Platform-specific tooling: Xcode for iOS/macOS, Android SDK for Android

### Clone

```bash
git clone https://gitlab.com/Openlyst/doudou.git
cd doudou
```

### Install Dependencies

```bash
flutter pub get
```

### Generate Localization Files

```bash
flutter gen-l10n
```

### Build

```bash
# Android
flutter build apk --debug           # Debug APK
flutter build apk --release         # Release APK
flutter build appbundle --release   # App Bundle for Play Store

# iOS
flutter build ios --release
flutter build ipa --release

# Desktop
flutter build macos --release
flutter build windows --release
flutter build linux --release

# Clean build artifacts
flutter clean
```

## Support

- [Report a Bug](https://gitlab.com/Openlyst/doudou/issues)
- [Request a Feature](https://gitlab.com/Openlyst/doudou/issues)
- [Community Discussions](https://gitlab.com/Openlyst/doudou/-/discussions)

## Credits

Doudou is built on top of these great projects:

- [Flutter](https://flutter.dev/)
- [Jellyfin](https://jellyfin.org/)
- [Plex](https://plex.tv/)
- [Subsonic](http://www.subsonic.org/)
- [SoundCloud](https://soundcloud.com/)
- [YouTube Music](https://music.youtube.com/)

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on submitting issues and pull requests.

## License

GPL-3.0 — see [LICENSE](LICENSE) for details.