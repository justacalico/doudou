# Privacy Policy for Doudou

**Effective date:** 2026-06-05

## Overview

Doudou is an open-source, cross-platform music player developed by Openlyst. This Privacy Policy explains what information the app handles and how it is used.

## Information We Do Not Collect

Doudou does not create user accounts, and Openlyst does not collect, store, or process any personal data on its own servers. The app is designed to connect to media servers that you own or control.

## Information Stored and Processed Locally

All app data, including:

- Server connection settings (URLs, credentials)
- Cached album artwork and metadata
- Downloaded songs and playlists for offline listening
- Playback history and queue state
- App preferences (theme, language, animation speed)

is stored **locally** on your device. Openlyst does not have access to this data.

## Server Connections

Doudou connects to media servers that you configure, such as:

- Subsonic / OpenSubsonic
- Jellyfin
- Plex
- YouTube Music

Any data exchanged with these servers is subject to their respective privacy policies and is transmitted directly between your device and the server. Openlyst does not intermediate, log, or monitor these connections.

## YouTube Music Integration

When using the YouTube Music source, the app communicates directly with YouTube's services. This is subject to [Google's Privacy Policy](https://policies.google.com/privacy).

## Permissions

The app requests the following permissions on your device:

- **Internet** – Required to stream music and connect to your media servers.
- **Storage / External Storage** – Required to cache artwork and download media for offline playback.
- **Foreground Service / Media Playback** – Required to keep audio playing in the background.
- **Wake Lock** – Required to prevent the device from sleeping during active playback.
- **Battery Optimizations** – Optional, to ensure uninterrupted background playback.
- **App Links / URL handling** – To open YouTube links in the app when shared.

## Third-Party Dependencies

Doudou uses open-source libraries (listed in `pubspec.yaml`). Some of these libraries may collect anonymized usage or crash data according to their own policies. No advertising or analytics SDKs are included by the developers of Doudou.

## Changes to This Policy

We may update this Privacy Policy from time to time. Changes will be posted in the app's source repository.

## Contact

For questions about this Privacy Policy, please open an issue in our [GitLab repository](https://gitlab.com/Openlyst/doudou/-/issues) or contact us through [openlyst.ink](https://openlyst.ink).
