# Doudou

A privacy-focused music player for your media server. Stream your music collection with a modern interface that works across all your devices. No tracking, no ads, no cloud services.

## Supported Backends

- **Subsonic** - Full support (Recommanded)
- **YouTube Music** - Full support (Recommanded)
- **Plex** - Working without a bunch of testing. (This is supported just not bugtested all the time (open a issue if a bug accross))
- **Jellyfin** - Supported unpritoized expect minor bugs
- **Local Files** - Play music directly from your device without a server

## Features

### Privacy
- No data collection, analytics, or telemetry
- No ads or third-party trackers
- Direct connection to your server only

### Playback
- Gapless audio
- Radio mode for continuous playback
- Automatic transcoding support

### Local Music
- Play music directly from your filesystem
- Album artwork from embedded metadata, local images, or online sources
- Create and manage local playlists

### Platforms
- Android, iOS, macOS, Linux, Windows, Web* (web untested)
- Background playback
- Offline listening with downloads

## Requirements

- **Media server**: Jellyfin 10.8+, Plex (with Plex Pass), Subsonic-compatible server, or Swing Music
- **Device**: Android 5.0+, iOS 12.0+, macOS 10.15+, Linux, or Windows 10+

## Download

**[Download for all platforms](https://openlyst.ink/apps/doudou)**

Available for Android, iOS, macOS, Windows, Linux.

## Setup

1. Open Doudou and tap "Add Server"
2. Select your server type (Jellyfin, Plex, or Subsonic)
3. Enter your server address (e.g., `http://192.168.1.100:8096`)
4. Sign in with your credentials
5. Your library will sync and you can start streaming

## FAQ

**Can I use this away from home?**
Yes, as long as your server is accessible over the internet. Consider using a VPN for security.

**How do I download for offline listening?**
Long-press any song, album, or playlist and select "Download for offline listening."

**Is the desktop version different?**
Desktop and mobile use the same backend rescaling the app will change from desktop or mobile ui tho.s

## Building from Source

### Clone the Repository

```bash
git clone https://gitlab.com/Openlyst/doudou.git
cd doudou
```

### Install Dependencies

```bash
flutter pub get
```

### Linux build (CI / desktop)

For Linux desktop build, install the system dependency required by `tray_manager`:

```bash
# Debian/Ubuntu
sudo apt-get install -y libayatana-appindicator3-dev
```

In CI, add `libayatana-appindicator3-dev` to your `apt-get install` list before `flutter build linux`.

### Build Commands

```bash
# Android
flutter build apk --debug          # Debug APK
flutter build apk --release        # Release APK
flutter build appbundle --release  # App Bundle for Play Store

# iOS
flutter build ios --release
flutter build ipa --release

# Desktop
flutter build windows --release
flutter build macos --release
flutter build linux --release

# Web
flutter build web --release

# Clean build artifacts
flutter clean
```

## Support

- [Report a Bug](https://gitlab.com/Openlyst/doudou/issues)
- [Request a Feature](https://gitlab.com/Openlyst/doudou/issues)

## Credits

Built upon:

- [Jellyfin](https://jellyfin.org/), [Plex](https://plex.tv/), [Subsonic](http://www.subsonic.org/), [Youtube Music](https://music.youtube.com) - Media servers
- [Harmony-Music](https://github.com/anandnet/Harmony-Music) - YouTube Music support
- [Flutter](https://flutter.dev/) - framework
 
 
