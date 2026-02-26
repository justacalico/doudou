# Doudou – Vibecode prompt

Build a music app named **Doudou** in **React 19**. Support exactly two backends: **Jellyfin** and **Navidrome** (Subsonic API). Do not implement translations (single language, e.g. English, is enough). Design the UI to be super good: modern, polished, and responsive. You decide the look and feel; no UI mockups are provided.

---

## Pages

Implement these pages/screens:

| # | Page | Purpose |
|---|------|--------|
| 1 | Home | Quick access (recent, favorites), then library sections. |
| 2 | Search | Global search; when empty show recommendations (recent, favorites, shuffle). |
| 3 | Library | Hub with tiles: Albums, Artists, Tracks, Playlists, and Downloads (if Jellyfin + downloads enabled). Each tile navigates to the corresponding page. |
| 4 | Albums | Grid of albums; tap/click opens album detail. |
| 5 | Artists | Grid of artists; tap/click opens artist detail. |
| 6 | Tracks | List of all/library tracks. |
| 7 | Playlists | Grid of playlists; tap/click opens playlist detail. |
| 8 | Downloads | Only when provider is Jellyfin and downloads are enabled. List of downloaded tracks; play all / shuffle. |
| 9 | Settings | Grouped sections: Server, General, Playback, Appearance, About. |
| — | Album detail | Overlay or dedicated route: metadata, track list, play, add to queue, add to playlist, favorite, download (Jellyfin), share. |
| — | Artist detail | Overlay or route: metadata, albums, popular tracks, play, add to queue, favorite, share. |
| — | Playlist detail | Overlay or route: metadata, track list, play, add to queue, add/remove tracks, delete playlist, share. |
| — | Now playing | Full-screen: artwork, progress, play/pause, skip, shuffle, repeat, lyrics, queue, open album/artist. |
| — | Onboarding | First launch when not logged in: welcome, theme (system/light/dark/OLED), accent color, then “Get started”. |
| — | Connect / Server | When not logged in: connect to server (leads to Settings server flow or onboarding). |

Use responsive behavior: detail screens as overlay or side panel on large screens, full page on small. Now playing is full-screen.

---

## Features

Implement every feature below.

1. **Authentication (both providers)**  
   - **Jellyfin:** Username/password; API key; Quick Connect (initiate → show code → poll until user approves on server → authenticate with secret). Store server URL, user id, token (or API key). Validate with `GET /Users/{userId}` or `/System/Info`.  
   - **Navidrome (Subsonic):** Username + password (MD5 with salt per request, or token if server supports). Validate with `GET .../rest/ping`.  
   - **Multi-server:** Saved list of servers (name, type, URL, credentials); switch / add / edit / remove; one “current” server. When no server or not logged in, show onboarding or “Connect to server”.

2. **Library data**  
   - **Jellyfin:** `GET /Users/{userId}/Views` (libraries), `GET /Users/{userId}/Items` (albums, artists, tracks, playlists by type/parent); images `GET /Items/{id}/Images/{type}`; search via Items API.  
   - **Navidrome:** `getMusicFolders`, `getAlbumList2`, `getArtists`, `getAlbum`, `getPlaylists`, `getPlaylist`, `search3`; art `getCoverArt`; stream `stream`.  
   - **Unified models:** Map both APIs into shared Album, Artist, Track, Playlist, Library.  
   - **Caching:** Optional local cache (e.g. IndexedDB) for faster load; background refresh.

3. **Playback**  
   - Single track: resolve stream URL from current provider, set queue to [track], play.  
   - Album/playlist/list: set queue to list, start at index.  
   - Queue: add, remove, reorder; show “up next” and full queue (e.g. in now playing or player bar).  
   - Shuffle and repeat (none, one, all).  
   - Stream URL: Jellyfin `GET /Audio/{id}/stream...` or Download; Navidrome `stream?id=`.  
   - Expose state: current track, position, duration, playing/paused, queue, shuffle, repeat (e.g. context/store).

4. **Queue and player bar**  
   - Persistent mini bar: current art, title, progress, play/pause, next/prev, optional shuffle/repeat, open queue, expand to now playing.  
   - Queue panel: list with reorder and remove.

5. **Favorites / starring**  
   - Jellyfin: `POST /Users/{userId}/FavoriteItems/{id}`, `DELETE` to unfavorite.  
   - Navidrome: star/unstar via Subsonic API.  
   - Toggle favorite on tracks, albums, artists; reflect in library and home.

6. **Playlists CRUD**  
   - List playlists from both APIs.  
   - Create: Jellyfin `POST /Users/{userId}/Items` (Playlist); Navidrome `createPlaylist`.  
   - Add/remove tracks: Jellyfin `POST /Items` (playlist id); Navidrome `updatePlaylist`.  
   - Delete playlists via both APIs.  
   - UI: “Add to playlist” from track/album (picker or “Create playlist and add”).

7. **Search**  
   - Jellyfin: Items API with search params.  
   - Navidrome: `search3` (query, albumCount, artistCount, songCount).  
   - Single search box; results grouped by albums, artists, tracks, playlists. Empty state: recent, favorites, “Shuffle all”.

8. **Downloads (Jellyfin only)**  
   - Setting to enable/disable downloads.  
   - Download track: get stream URL, save to local storage with metadata.  
   - Downloads page: list downloaded tracks; play from local file.  
   - Optional: offline mode when network fails but credentials and downloads exist (use local files for stream).

9. **Lyrics**  
   - Optional (setting). Fetch from lrclib.net (plain and synced). Show in now playing and/or overlay.  
   - Synced: highlight line by current playback time.

10. **Settings**  
    - **Server:** Connect/disconnect; add/edit/remove servers; Jellyfin: URL, auth method (password / API key / Quick Connect); Navidrome: URL, username, password.  
    - **General:** Toggles for lyrics on/off, downloads on/off (Jellyfin).  
    - **Playback:** Default volume, default speed, gapless playback, autoplay (e.g. recommendations at end of queue).  
    - **Appearance:** Theme (system/light/dark/OLED), accent color.  
    - **About:** App name “Doudou”, version, licenses link.

11. **Onboarding**  
    - First launch when no server connected: welcome step, theme and accent, then “Get started” (mark onboarding done, show server connection).

12. **Sharing**  
    - Share track/album/artist (e.g. Web Share API or copy link).

13. **Detail actions**  
    - From album/artist/playlist/track: play, add to queue, add to playlist, favorite, share; for album/track: download (Jellyfin only).

14. **Responsive layout**  
    - Desktop: sidebar nav (Home, Search, Library) and library sub-items (Albums, Artists, Tracks, Playlists, Downloads); detail as overlay or side panel.  
    - Mobile: bottom nav for main sections; library as hub or nested; detail and now playing as full screens.

---

## API summary

**Jellyfin**  
- Auth: `POST /Users/AuthenticateByName` (username, password); API key via `X-Emby-Token` with `GET /Users`; Quick Connect: `GET /QuickConnect/Enabled`, `POST /QuickConnect/Initiate`, poll `GET /QuickConnect/Connect`, then `POST /Users/AuthenticateWithQuickConnect`.  
- Main: `GET /Users/{userId}/Views`; `GET /Users/{userId}/Items` (IncludeItemTypes, ParentId, etc.); `GET /Items/{id}/Images/{type}`; stream `GET /Audio/{id}/stream` or Download; `POST/DELETE /Users/{userId}/FavoriteItems/{id}`; playlists create/add/delete as per Jellyfin API.

**Navidrome (Subsonic)**  
- Auth: every request uses `u`, `t` (MD5(password + salt)), `s` (salt), `v`, `c`, `f=json`. Ping: `GET .../rest/ping`.  
- Main: `getMusicFolders`, `getAlbumList2`, `getArtists`, `getAlbum`, `getPlaylists`, `getPlaylist`, `stream`, `getCoverArt`, `search3`; star/unstar; `createPlaylist`, `updatePlaylist`, `deletePlaylist`.

---

## Data models

Use unified models; map both APIs into them.

- **Album:** id, name, artistName?, imageUrl?, year?, dateCreated?, isFavorite  
- **Artist:** id, name, imageUrl?  
- **Track:** id, name, albumName?, artistName?, albumId?, duration (ms), trackNumber?, imageUrl?, isFavorite, playCount?  
- **Playlist:** id, name, imageUrl?, trackCount  
- **Library:** id, name, collectionType?, imageUrl?  
- **SavedServer:** id, name?, serverType (jellyfin | navidrome), serverUrl, authMethod?, identifier?, credential?, apiKey?, userId?  
- **DownloadedTrack** (Jellyfin downloads): trackId, filePath, imagePath?, downloadedAt, fileSize

---

## Exclusions

- Do **not** support Plex, local music, or YouTube Music.  
- Do **not** implement translations or i18n.  
- Do **not** follow a specific UI mockup; you design the look and feel.
