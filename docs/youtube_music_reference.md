# YouTube Music implementation reference

## OpenTune backend (reference only; we do not use the UI)

We studied **only** the YouTube Music / InnerTube **backend** code from [Arturo254/OpenTune](https://github.com/Arturo254/OpenTune). The repo was cloned to `docs/reference/OpenTune` (gitignored). We do **not** use any OpenTune UI (Compose, themes, navigation).

### InnerTube API (OpenTune)

- **Base URL**: `https://music.youtube.com/youtubei/v1/`
- **Key endpoints** (POST unless noted):
  - `search` — search with query, optional filter (songs, albums, etc.), continuation for pagination
  - `player` — get playback/stream info for a videoId (and optional playlistId, signatureTimestamp)
  - `browse` — browse by browseId (e.g. album, artist, library), params, continuation
  - `next` — up-next / queue (videoId, playlistId, index, etc.)
  - `music/get_search_suggestions` — search suggestions
  - `music/get_queue` — queue for videoIds or playlistId
  - `account/account_menu` — account info (requires login)
  - `like/like`, `like/removelike` — like video or playlist
  - `browse/edit_playlist` — add/remove items, create/delete playlist
- **Headers**: `X-YouTube-Client-Name` (client id, e.g. 67 for WEB_REMIX), `X-YouTube-Client-Version`, `X-Origin`, `Referer` (music.youtube.com). For authenticated requests: `cookie` header and `Authorization: SAPISIDHASH <timestamp>_<sha1(sapisid)>`.
- **Auth**: Cookie string; when `setLogin` is true, cookies and SAPISID hash are sent. No official OAuth for third-party YTM clients.
- **Client**: WEB_REMIX (clientId 67) used for music browse/search; player can use different clients (e.g. TVHTML5_SIMPLY_EMBEDDED_PLAYER for embedded) for stream URLs.

### Dart implementation (doudou)

We implement the same **concepts** in Dart using:

- **dart_ytmusic_api** — catalog: search (songs, albums, artists, playlists), getSong, getAlbum, getArtist, getPlaylist, getPlaylistVideos, getHomeSections. Auth via `initialize(cookies, gl, hl)`. **Does not work on web**; YouTube Music is disabled when `kIsWeb` is true.
- **youtube_explode_dart** — stream URL: given a video ID, returns stream manifest; we use `audioOnly.withHighestBitrate().url` for playback.

Track id in doudou = YouTube **videoId**. No port of OpenTune Kotlin code; we use the above Dart packages and align behavior (e.g. search → search, track id → videoId → stream) with what OpenTune’s backend does.
