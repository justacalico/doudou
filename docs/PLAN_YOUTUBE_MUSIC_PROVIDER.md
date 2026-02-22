# Plan: Add YouTube Music as a Provider (v15 Rewrite)

## Context

- **Current state**: Version 15 was rewritten; the old v15 (commit `60d22aa5`) had YouTube Music support but was buggy and **broke Linux users’ system audio** for everything except YouTube Music.
- **Goal**: Re-add YouTube Music as a provider using code from the old version and [Harmony-Music](https://github.com/anandnet/Harmony-Music), with **strict isolation** so that **YouTube Music code cannot affect the main audio pipeline**, especially on Linux.
- **Reference artifacts**:
  - Old v15 archive: `https://gitlab.com/Openlyst/doudou/-/archive/60d22aa5ba0f6c12e644d7ae7298c48215bcdb99/doudou-60d22aa5ba0f6c12e644d7ae7298c48215bcdb99.zip`
  - Harmony-Music: `https://github.com/anandnet/Harmony-Music` (streaming via `youtube_explode_dart`, no login required).

---

## 1. Isolation Rules (Mandatory)

1. **YouTube Music code MUST live in a dedicated module**  
   - All YT Music–specific code (catalog, stream resolution, and **on Linux** playback) must be under a single subtree (e.g. `lib/services/players/youtube_music/` or `lib/providers/youtube_music/`) so it can be maintained, tested, or disabled without touching core audio or other providers.

2. **On Linux: separate playback path for YouTube Music**  
   - The main app’s single `AppAudioPlayer` (currently `AudioplayersAppPlayer` on Linux) must **never** be used to play YouTube Music streams on Linux.  
   - When the active provider is YouTube Music on Linux, use a **dedicated player instance** used only for YT Music (create when entering YT Music, dispose when leaving). All YT playback on Linux goes through this instance; the main player is only used for Jellyfin, Plex, Subsonic, and Local.  
   - Do **not** change system-wide or process-wide audio configuration (e.g. default PulseAudio sink, ALSA device) from YT Music code.

3. **No shared audio state with main pipeline for YT on Linux**  
   - Avoid reusing the same backend/instance for both YT and non-YT on Linux. If the main app uses `audioplayers` (GStreamer), the YT-dedicated path can use a second `audioplayers` instance **only for YT**, or a separate approach that does not touch the main pipeline.

4. **Optional base interface extensions**  
   - Prefer adding optional methods (e.g. `setServerId`, `persistLocalDataIfAny`) only where needed and implementing them in the YT Music service; keep the base interface unchanged for existing providers where possible.

---

## 2. Source of Truth for Implementation

- **Catalog / search / home**: Old v15 `lib/services/players/youtube_music_service.dart` (dart_ytmusic_api: catalog, no-login mode; local favorites/followed artists/albums/playlists in SharedPreferences).
- **Stream URL resolution**: Old v15 `lib/services/players/harmony_stream_provider.dart` (Harmony-Music style: `youtube_explode_dart` only, `streamsClient.getManifest(videoId)`, audio-only, best quality). Do **not** wire YT playback through the main `getStreamUrl`/preload path used by other providers on Linux; use the isolated path instead.
- **Playback behavior (non-Linux)**: Old v15 `lib/services/audio/providers/youtube_music_handler.dart` (no cache/preload for URLs, completion cooldown, ConcatenatingAudioSource-style behavior). On Linux, this logic is used only for the **dedicated** YT player, not the main handler’s player.
- **Harmony-Music**: Use as reference for stream fetching and quality selection (e.g. `lib/services/stream_service.dart` / StreamProvider), not for copying their full app structure.

---

## 3. Dependencies

- Add (or restore) in `pubspec.yaml`:
  - `dart_ytmusic_api: ^1.3.6` (catalog; disable or hide on web if not supported).
  - `youtube_explode_dart` (stream URLs). Prefer the same version or fork used by Harmony-Music (e.g. `2.x` with `streamsClient.getManifest`); if the old archive used a fork, document it (e.g. `anandnet/youtube_explode_dart`).
- Keep existing audio stack (`just_audio`, `just_audio_media_kit`, `media_kit`, `audioplayers`, etc.) as-is for non-YT; do not add a new global audio backend just for YT.

---

## 4. Code Layout (Suggested)

```
lib/
  models/
    jellyfin_models.dart          # Add YTMHomeSection if missing.
  services/
    base_service.dart             # Add ServerType.youtubeMusic; optional setServerId/persistLocalDataIfAny.
    media_service_manager.dart    # Register YT Music service; isYouTubeMusic; getYouTubeMusicHomeSections; all YT-specific branches.
    players/
      youtube_music/             # NEW: isolated module
        youtube_music_service.dart   # Catalog + stream URL resolution (HarmonyStreamProvider).
        harmony_stream_provider.dart # Port from old v15 (youtube_explode_dart only).
    audio/
      app_audio_player.dart       # No change to main player creation.
      unified_audio_handler.dart  # Route to YT-dedicated path when current provider is YT and platform is Linux; otherwise use existing flow.
      youtube_music/             # NEW: isolated playback for YT (optional subfolder)
        youtube_music_linux_player.dart  # Dedicated AppAudioPlayer (or audioplayers) used only for YT on Linux.
        youtube_music_handler.dart       # Port completion/URL rules from old youtube_music_handler; used by unified handler only for YT.
```

- **Critical**: On Linux, `UnifiedAudioHandler` must detect `currentServerType == youtubeMusic` and use the dedicated YT player and **never** call `_player.setSource()` (or equivalent) with a googlevideo.com URL for the main player.

---

## 5. Implementation Phases

### Phase 1: Models and base wiring (no playback)

- Add `ServerType.youtubeMusic` to `lib/services/base_service.dart`.
- Add `YTMHomeSection` to `lib/models/jellyfin_models.dart` if not present.
- Add optional `setServerId(String? id)` and `persistLocalDataIfAny()` to `BaseMediaService` (default no-op), and implement in the YT Music service.

### Phase 2: YouTube Music module (catalog + URLs only)

- Create `lib/services/players/youtube_music/` and port:
  - `youtube_music_service.dart`: catalog, search, home sections, favorites/followed/playlists (SharedPreferences), `getStreamUrl` / `getAlternativeStreamUrlsAsync` using Harmony-style stream provider.
  - `harmony_stream_provider.dart`: fetch manifest via `youtube_explode_dart`, return best audio URL(s); no dependency on main audio stack.
- Add `YouTubeMusicService` to `MediaServiceManager` (initializeService, getServerInfo, getLibraries, getAlbums, getArtists, getTracks, getPlaylists, getPlaylistTracks, search, getImageUrl, toggleFavorite, etc.). Expose `isYouTubeMusic` and `getYouTubeMusicHomeSections()`.
- **Do not** wire YT into the main `UnifiedAudioHandler` playback path yet on any platform.

### Phase 3: UI and server selection

- In server connection / add-server UI, add “YouTube Music” as a provider (hide on web if dart_ytmusic_api is unsupported).
- In settings, add optional Invidious/Piped instance fields for YT Music if the product decision is to support them later; otherwise leave as no-op or omit.
- Update home, library, search, now playing, and details so that when `currentServerType == ServerType.youtubeMusic` the correct labels and data sources are used (e.g. home sections from `getYouTubeMusicHomeSections()`).
- Ensure login flow for YT Music uses the same “no-login” approach as old v15 (fixed server URL, no cookie auth in app).

### Phase 4: Playback integration with isolation

- **Non-Linux (Windows, macOS, Android, iOS, web)**  
  - Integrate YT Music into the existing `UnifiedAudioHandler` flow: resolve stream URL via `YouTubeMusicService.getAlternativeStreamUrlsAsync`, then use the **existing** `_player` (JustAudio/AppAudioPlayer) to play the URL. Optionally port the old `YouTubeMusicHandler` completion/cooldown and “no cache/preload” rules into a small helper or handler used only when current track is YT, so the main handler logic stays clear.

- **Linux**  
  - Implement the **dedicated YT-only player**:
    - When user switches to YouTube Music on Linux, create a dedicated `AppAudioPlayer` (or equivalent) instance used **only** for YT Music playback.
    - All `playTrack` / `skipToNext` / `skipToPrevious` / `seek` / `pause` / `resume` for YT Music on Linux go through this instance; the main `_player` is not used for YT.
    - When user switches away from YouTube Music (or app suspends), stop and dispose the YT-dedicated player; do not use it for non-YT content.
  - In `UnifiedAudioHandler`, when `defaultTargetPlatform == TargetPlatform.linux` and `currentServerType == ServerType.youtubeMusic`, route all playback to the YT-dedicated player instead of `_player`.
  - Ensure no code in the YT path sets global audio device or default sink (e.g. avoid mpv/ALSA/Pulse options that change system defaults).

### Phase 5: Testing and hardening

- **Linux**: Test that after playing YT Music and then switching to Jellyfin (or Local), system audio and in-app playback for non-YT still work. Test that switching back to YT Music uses the dedicated player again.
- **All platforms**: Test YT Music search, home, playlists, play/pause/seek, and queue; test that URL expiry and completion/cooldown behave correctly.
- Document in code comments that the YT Music module and Linux-dedicated player exist to avoid regressions that broke system audio in the old v15.

---

## 6. Files to Create or Modify (Checklist)

| Action  | Path |
|--------|------|
| Modify | `pubspec.yaml` (dart_ytmusic_api, youtube_explode_dart) |
| Modify | `lib/models/jellyfin_models.dart` (YTMHomeSection) |
| Modify | `lib/services/base_service.dart` (ServerType.youtubeMusic; optional setServerId/persistLocalDataIfAny) |
| Create | `lib/services/players/youtube_music/harmony_stream_provider.dart` |
| Create | `lib/services/players/youtube_music/youtube_music_service.dart` |
| Modify | `lib/services/media_service_manager.dart` (register YT, isYouTubeMusic, getYouTubeMusicHomeSections, YT branches) |
| Create | `lib/services/audio/youtube_music/youtube_music_handler.dart` (completion/URL rules; no main-player use on Linux) |
| Create | `lib/services/audio/youtube_music/youtube_music_linux_player.dart` (dedicated player for Linux YT only) |
| Modify | `lib/services/audio/unified_audio_handler.dart` (route YT on Linux to dedicated player; use handler for completion/URLs) |
| Modify | `lib/providers/app_state.dart` (youtubeMusic in server type handling, home sections, login) |
| Modify | `lib/ui/settings/server_connection_section.dart` (add YouTube Music option; hide on web if needed) |
| Modify | `lib/ui/pages/settings_page.dart` (YT Music settings if any) |
| Modify | `lib/ui/pages/home_page.dart` (YT home sections when currentServerType == youtubeMusic) |
| Modify | `lib/ui/pages/library_page.dart` (show/hide tabs for YT) |
| Modify | `lib/ui/pages/search_page.dart` (YT search) |
| Modify | `lib/ui/pages/details/*` (artist/album/media details for YT) |
| Modify | `lib/ui/playing/now_playing.dart` (and desktop/mobile variants if any) (download disabled for YT; labels) |
| Modify | `lib/ui/layout/app_shell.dart` (nav visibility for YT) |
| Modify | Other UI that branches on `ServerType` (track list, add server form, etc.) |

---

## 7. Summary

- **Isolation**: YT Music lives in a dedicated module; on Linux it uses a **dedicated player instance** only for YT, and the main app player is never used for YouTube Music.
- **Streaming**: Use Harmony-Music–style resolution with `youtube_explode_dart` only; catalog via `dart_ytmusic_api`; no login in app.
- **Safety**: No shared audio pipeline with other providers on Linux for YT; no global audio configuration changes from YT code.
- **Reference**: Old v15 archive and Harmony-Music repo are the source of truth for behavior and stream fetching; the current codebase is the source of truth for where to plug in the isolated YT path.
