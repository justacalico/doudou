# Harmony-Music reference (anandnet/Harmony-Music)

We reference [Harmony Music](https://github.com/anandnet/Harmony-Music) for YouTube/YouTube Music streaming **without login**. Harmony Music is a cross-platform Flutter app that streams from YouTube and YouTube Music with no login required and no ads.

## Referenced concepts and files

- **No login required**: Harmony Music does not require cookies or account; we allow optional cookies for personalized catalog and enforce login only when the user explicitly adds credentials.
- **Stream resolution**: Harmony uses `youtube_explode_dart` for resolving audio stream URLs (see their `lib/services/stream_service.dart`). We use the same approach in `lib/services/players/youtube_music_service.dart` as one of our fallbacks (InnerTube → Piped → Invidious → youtube_explode_dart).
- **Constants**: Harmony’s `lib/services/constant.dart` defines `baseUrl` for `music.youtube.com/youtubei/v1/` and a WEB_REMIX API key; our InnerTube client uses the same base and key for WEB_REMIX (see `lib/services/players/innertube_client.dart`).

## In-code references

- `lib/services/players/youtube_music_service.dart` — stream fallback order and no-login support; stream logic referenced from Harmony-Music `lib/services/stream_service.dart`.
- `lib/services/players/innertube_client.dart` — InnerTube API key and base URL alignment with Harmony-Music `lib/services/constant.dart`.
