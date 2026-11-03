# Privacy Policy for Doudou

**Effective date:** 2026-11-03

## Overview

Doudou is an open-source music player by Openlyst. This page explains what data the app touches and where it goes.

## What We Don't Collect

Doudou has no user accounts, no sign-ups, no advertising, and no analytics. We don't collect, store, or see your personal data or listening habits. The only Openlyst server the app ever talks to is the update check described below.

## What Stays on Your Device

Your data lives locally by default:

- Server connection settings (URLs, credentials)
- Cached album artwork and metadata
- Songs and playlists you've downloaded for offline use
- Favourites, playlists, playback history and queue state
- Search history
- App preferences (theme, language, animation speed)

We can't access any of this. If you enable device sync, some of it is stored on a Doudou server you choose instead, covered in its own section below.

## Server Connections

Doudou talks to media servers you set up yourself:

- Subsonic / OpenSubsonic
- Jellyfin
- Plex
- YouTube Music

Traffic goes straight from your device to the server. Openlyst doesn't sit in the middle, log anything, or watch these connections.

Self-hosted servers often run on plain HTTP, so the app allows cleartext connections and warns you in the UI when a connection isn't HTTPS. Use HTTPS endpoints where you can.

## Update Checks

On startup, the app requests `https://openlyst.ink/api/v1/apps/doudou/latest` to learn the newest release version. It's a plain GET: nothing about you, your device, or your library is sent, and the version comparison happens on your device. Like any HTTPS request, our web host sees a connection from your IP address.

You can turn this off under Settings > App info ("Check for updates on startup"), and F-Droid builds skip it entirely.

## Doudou Server (Device Sync)

Optionally, you can run your own Doudou server (`doudou -server`) and connect the app to it. When you do, the server holds your library data: favourites, playlists, recently played, search history, blacklisted playlists and session state. The app treats the server as the source of truth and pushes your local writes to it.

That server is yours, or run by whoever hosts it for you. Openlyst doesn't run it and can't see its contents. Protect it with a password and prefer HTTPS, since your library data and login travel over that connection.

## YouTube and Google

If you use the YouTube Music source, the app hits YouTube's APIs directly. That falls under [Google's Privacy Policy](https://policies.google.com/privacy).

Separately, the app downloads its display font (Inter) from Google Fonts the first time it runs and caches it locally afterward.

## Discord Rich Presence

On desktop, you can optionally show the song you're listening to as your Discord status. It's off by default. When enabled, the app hands the current track to the Discord client on the same machine; what Discord then displays or stores is governed by [Discord's Privacy Policy](https://discord.com/privacy).

## Local MCP Server

On desktop, the app can host a local MCP (Model Context Protocol) endpoint so AI tools on the same computer can control playback. It's off by default and only listens on `127.0.0.1`, so nothing is exposed to the network.

## Permissions

The app asks for these permissions:

- **Internet** - stream music, reach your media servers, and check for updates.
- **Foreground Service / Media Playback** - keep audio running when the app isn't on screen.
- **Wake Lock** - prevent the device from sleeping during playback.
- **Battery Optimizations** - optional; helps keep background playback smooth.
- **App Links / Share handling** - open YouTube links shared to or pasted into the app.
- **Android Auto / CarPlay** - show your library on the car display.

The app does **not** request broad storage access. Media and caches live in the app's own storage, and exporting files or picking a download folder goes through the system file picker or Storage Access Framework.

## Third-Party Libraries

Doudou is built on open-source Flutter and Dart packages listed in `pubspec.yaml` (things like Dio, Hive, GetX, and Just Audio). None of these include advertising or analytics SDKs, and the app ships no crash reporting or telemetry tools.

## Updates

This policy might change as the app evolves. Any updates will show up in the repo.

## Contact

Got questions? Open an issue on [GitLab](https://gitlab.com/Openlyst/doudou/-/issues) or reach out at [openlyst.ink](https://openlyst.ink).
