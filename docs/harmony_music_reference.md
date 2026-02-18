# Harmony-Music reference (anandnet/Harmony-Music)

We reference [Harmony Music](https://github.com/anandnet/Harmony-Music) for YouTube/YouTube Music streaming **without login**. Harmony Music is a cross-platform Flutter app that streams from YouTube and YouTube Music with no login required and no ads.

## Referenced concepts and files

- **No login required**: Harmony Music does not require cookies or account; we allow optional cookies for personalized catalog and enforce login only when the user explicitly adds credentials.
- **Stream resolution (primary stack)**: Harmony uses **only** `youtube_explode_dart` for streaming (see their `lib/services/stream_service.dart` – `StreamProvider.fetch(videoId)`). We **port that as our primary** YouTube Music stream source: we try Piped first, then Invidious, then youtube_explode, then InnerTube (proxied URLs first so desktop MPV works). This order matches Harmony’s working stack and avoids relying on direct googlevideo.com URLs first.
- **Stream selection**: Harmony’s `stream_service.dart` defines `highestQualityAudio` as itag 251 (opus) or 140 (mp4a), and `lowQualityAudio` as itag 249/139. We use the same itag preference in `_pickAudioUrlsFromManifest()` and `_preferredItags` / `_fallbackItags` in `youtube_music_service.dart`.
- **Constants**: Harmony’s `lib/services/constant.dart` defines `baseUrl` for `music.youtube.com/youtubei/v1/` and a WEB_REMIX API key; our InnerTube client uses the same base and key for WEB_REMIX (see `lib/services/players/innertube_client.dart`).

## In-code references

- `lib/services/players/youtube_music_service.dart` — **streaming stack ported from Harmony-Music**: resolution order is 1) Piped, 2) Invidious, 3) youtube_explode_dart, 4) InnerTube; stream selection uses Harmony’s itag preference (251/140 then 250/139) in `_pickAudioUrlsFromManifest()`; no-login support; references `lib/services/stream_service.dart` (StreamProvider.fetch, highestQualityAudio).
- `lib/services/players/innertube_client.dart` — InnerTube API key and base URL alignment with Harmony-Music `lib/services/constant.dart`.
