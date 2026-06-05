# Privacy Policy for Doudou

**Effective date:** 2026-06-05

## Overview

Doudou is an open-source music player by Openlyst. This page explains what data the app touches and where it goes.

## What We Don't Collect

Openlyst doesn't run any servers for Doudou and we don't collect, store, or see your personal data. There are no user accounts, no sign-ups, and no cloud service on our end.

## What Stays on Your Device

Everything lives locally:

- Server connection settings (URLs, credentials)
- Cached album artwork and metadata
- Songs and playlists you've downloaded for offline use
- Playback history and queue state
- App preferences (theme, language, animation speed)

We can't access any of this. It's all on your device.

## Server Connections

Doudou talks to media servers you set up yourself:

- Subsonic / OpenSubsonic
- Jellyfin
- Plex
- YouTube Music

Traffic goes straight from your device to the server. Openlyst doesn't sit in the middle, log anything, or watch these connections.

## YouTube Music

If you use the YouTube Music source, the app hits YouTube's APIs directly. That falls under [Google's Privacy Policy](https://policies.google.com/privacy).

## Permissions

The app asks for these permissions:

- **Internet** – Needed to stream and talk to your media servers.
- **Storage / External Storage** – Needed to cache artwork and download media for offline playback.
- **Foreground Service / Media Playback** – Needed to keep audio running when the app isn't on screen.
- **Wake Lock** – Prevents the device from sleeping during playback.
- **Battery Optimizations** – Optional. Helps keep background playback smooth.
- **App Links / URL handling** – Lets the app open YouTube links when shared to it.

## Third-Party Libraries

Doudou is built on open-source Flutter and Dart packages listed in `pubspec.yaml` (things like Dio, Hive, GetX, and Just Audio). None of these include advertising or analytics SDKs. We don't ship any crash reporting or telemetry tools.

## Updates

This policy might change as the app evolves. Any updates will show up in the repo.

## Contact

Got questions? Open an issue on [GitLab](https://gitlab.com/Openlyst/doudou/-/issues) or reach out at [openlyst.ink](https://openlyst.ink).
