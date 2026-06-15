# Doudou

A cross-platform music player that connects to your own media server. Stream your library, or pull from YouTube Music - all without ads, trackers, or cloud lock-in.

<p align="center">
  <img src="images/home.png" width="30%" />
  <img src="images/albums.png" width="30%" />
  <img src="images/nowplaying.png" width="30%" />
</p>

## What it connects to

- **Subsonic** / **OpenSubsonic** - Best tested and recommended
- **YouTube Music** - Full support with radio mode (disabled in Play Store build for compliance with Google's policies)
- **Jellyfin** - Supported, minor bugs possible
- **Plex** - Works, but less tested. File an issue if you hit problems

## What it does

- Gapless playback with a proper queue and history
- Background audio on mobile and desktop
- Download songs, albums, and playlists for offline listening
- Lyrics support (synced and static)
- Radio mode that keeps the music going
- Automatic transcoding when your server supports it
- System media controls
- Dynamic themes pulled from album artwork

## Platforms

Android, iOS, macOS, Windows and, Linux

## Download

Get builds for every platform at **[openlyst.ink/apps/doudou](https://openlyst.ink/apps/doudou)**.

## Quick start

1. Open the app and hit "Add Server"
2. Pick your backend type
3. Enter the server URL (for example, `http://192.168.1.100:8096` for Jellyfin)
4. Log in
5. Your library syncs automatically

## FAQ

**Can I use this outside my house?**

Yes, as long as your server is reachable from the internet. A reverse proxy or VPN is a good idea.

**How do downloads work?**

Long-press anything (song, album, playlist) and choose download. It lives in the app, not your public downloads folder.

**Is the desktop UI different?**

Same app, same backend. The layout adapts to screen size. 

## Building from source

You need the Flutter SDK (3.1.5 or newer).

```bash
git clone https://gitlab.com/Openlyst/doudou.git
cd doudou
flutter pub get
```

### Linux desktop extra dependency

`tray_manager` needs appindicator headers on Debian/Ubuntu:

```bash
sudo apt-get install -y libayatana-appindicator3-dev
```

### Build commands

```bash
# Android
flutter build apk --release
flutter build appbundle --release

# iOS
flutter build ipa --release

# Desktop
flutter build windows --release
flutter build macos --release
flutter build linux --release

# Web
flutter build web --release
```

## Issues and contributing

Bugs and feature requests go in the [issue tracker](https://gitlab.com/Openlyst/doudou/issues). Pull requests are welcome.

## License

[GPL-3.0](LICENSE)
