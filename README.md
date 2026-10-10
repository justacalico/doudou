# Doudou

A music player that connects to your own media server. Stream your library, or pull from YouTube Music

<p align="center">
  <img src="images/home.png" width="30%" />
  <img src="images/albums.png" width="30%" />
  <img src="images/nowplaying.png" width="30%" />
</p>

<p align="center">
  <img src="images/desktop.png" width="100%" />
</p>

## What it connects to

- **Subsonic** / **OpenSubsonic** - Best tested and recommended
- **YouTube Music** - Full support (disabled in Play Store build for compliance with Google's policies)
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
- Android Auto support
- Android TV support with D-pad navigation and 10-foot UI
- Discord Rich Presence on desktop (show what you're listening to)
- Dynamic themes pulled from album artwork

## Platforms

Android, Android TV, iOS, macOS, Windows and, Linux

## Download

Get builds for every platform at **[openlyst.ink/apps/doudou](https://openlyst.ink/apps/doudou)**, or visit the **[landing page](https://openlyst.gitlab.io/doudou)**.

Nightly builds are also available on **[GitLab Releases](https://gitlab.com/Openlyst/doudou/-/releases)**.

## Quick start
1. Open the app and hit "Add Server"
2. Pick your backend type (Youtube Music is turned off for Playstore versions)
3. Log in

## FAQ

**Can I use this outside my house?**

Yes, as long as your server is reachable from the internet. A reverse proxy or VPN is a good idea.

**How do downloads work?**

Long-press anything (song, album, playlist) and choose download. It lives in the app, not your public downloads folder.

**Is the desktop UI different?**

Same app, same backend. The layout adapts to screen size. 

## Sync server

Doudou ships a headless sync server that hosts your library database so every device you log in with shares the same favorites, playlists, recently played, and search history. Only library data is synced: stream URLs, caches, downloads, and device settings stay local.

### Running it

From a source checkout:

```bash
dart run bin/doudou_server.dart
```

Or from an installed desktop build:

```bash
doudou -server
```

The app UI still opens normally while a server is running.

### Options

| Flag | Description |
| --- | --- |
| `--port <n>` | Port to listen on (default 8461) |
| `--bind <address>` | Address to bind (default `0.0.0.0`) |
| `--data-dir <path>` | Server data directory (default `~/.doudou-server`) |
| `--password <pw>` | Set or replace the login password |
| `-importdb <path>` | Import a `.hmb` backup into the server database at startup |
| `-h`, `--help` | Show usage |

On first run the server asks you to choose a password. On a headless launch with no terminal it generates a random one, prints it, and also writes it to `<data-dir>/initial-password.txt`. Server config lives in `<data-dir>/server.json` and the database in `<data-dir>/db`.

### Connecting from the app

In the app go to **Settings > Servers > Device sync**, enter the server address (for example `192.168.1.10:8461`) and the password, then hit connect.

### Backups

`-importdb backup.hmb` seeds the server from a backup exported by the app, and `GET /api/export.hmb` produces a `.hmb` file the app can restore.

### A note on security

The server speaks plain HTTP. On your LAN that is fine, but if you expose it to the internet put it behind a reverse proxy with TLS or reach it over a VPN.

## Compile

You need the Flutter SDK (3.35.0 or newer).

```bash
git clone https://gitlab.com/Openlyst/doudou.git
cd doudou
flutter pub get
```

### Linux desktop extra dependency
Appindicator headers are needed on Debian/Ubuntu:

```bash
sudo apt-get install -y libayatana-appindicator3-dev
```

### Build commands

The Android app uses product flavors — `phone` for the main app and `tv` for Android TV.

```bash
# Android (phone)
flutter build apk --release --flavor phone -t lib/main.dart
flutter build appbundle --release --flavor phone -t lib/main.dart

# Android (phone — Play Store)
flutter build apk --release --flavor phone --dart-define=PLAYSTORE=true -Pplaystore=true -t lib/main.dart
flutter build appbundle --release --flavor phone --dart-define=PLAYSTORE=true -Pplaystore=true -t lib/main.dart

# Android (TV — YouTube Music disabled)
flutter build apk --release --flavor tv --dart-define=PLAYSTORE=true --dart-define=TV=true
flutter build appbundle --release --flavor tv --dart-define=PLAYSTORE=true --dart-define=TV=true

# Android (TV — YouTube Music enabled)
flutter build apk --release --flavor tv --dart-define=PLAYSTORE=false --dart-define=TV=true
flutter build appbundle --release --flavor tv --dart-define=PLAYSTORE=false --dart-define=TV=true

# iOS
flutter build ipa --release

# Desktop
flutter build windows --release
flutter build macos --release
flutter build linux --release
```

## Issues and contributing

Bugs and feature requests go in the [issue tracker](https://gitlab.com/Openlyst/doudou/issues). Pull requests are welcome.

## License

[GPL-3.0](LICENSE)

## Acknowledgements

Doudou (version 16.0.0 and later) is based on [Harmony-Music](https://github.com/anandnet/Harmony-Music) by anandnet.
