# Changelog

All notable changes to Doudou are recorded here. This file consolidates the
previously per-version files that lived under `changelog/`.

## 22.0.0

- Added debug-only playback error logging via `logPlaybackDebugError` for
  YouTube Music stream failures and playback errors.

## 21.0.0 - 2026-08-05

- Bumped version to 21.0.0
- Updated dependencies
- Added Android Auto support
- Added Wear OS companion app with playback controls, shuffle all, favorites, and settings (#207)
- Fixed duplicate lyrics bottom sheets appearing when the lyrics button is tapped rapidly (#208)
- Lyrics bottom sheet now opens immediately, with content loading asynchronously
- Fixed an issue where adding music to playlists on Subsonic servers would fail (#211)
- Fixed album details occasionally failing to load with a HiveError when the downloads box has not been opened yet (#213)
- Added right-click and long-press support to open song options across all song lists, the queue, the artist table, and home screen sections (#212)
- Fixed a crash occurring when the `getWatchPlaylist` response is missing `playlistPanelRenderer` (#214)
- Fixed favorite status not displaying or toggling correctly in song options for Subsonic and other non-YouTube servers (#215)
- Added Android TV support with D-pad navigation, focus highlighting, and 10-foot UI adaptations (#208)
- Added a `tv` product flavor with a leanback launcher, a separate `applicationIdSuffix .tv`, and a `versionCode` offset for Play Store multi-APK delivery
- Disabled YouTube Music on TV builds via the `PLAYSTORE` compile flag, consistent with Play Store phone builds
- Added `TvService` for runtime TV detection using `device_info_plus`
- Added `DoudouLayoutClass.tv` with a wider content area, larger padding, and side navigation for D-pad
- Added a `TvFocusHighlight` widget for visible focus rings on interactive elements
- Disabled sliding panel drag and slidable swipe actions on TV, as there is no touchscreen
- Enabled the queue drawer on TV layouts
- Added Discord Rich Presence support for desktop platforms (Linux, macOS, Windows). Users can enter their Discord Application ID in Settings > Misc to display the current song as their Discord activity status
- Fixed a second window opening as a black screen on desktop. Launching a second instance now focuses the existing window instead (Linux, Windows, macOS)
- Changed the compact desktop volume button to open a vertical volume slider popup on left click. Right-click still mutes or unmutes audio
- Fixed the volume slider having no usable range at low volumes. The slider now applies a perceptual (quadratic) curve across the full 0–100% range instead of flooring non-zero values at 20% internal volume
- Fixed loudness normalization overriding the user's volume preference on Android. The slider value is now multiplied with the loudness adjustment rather than replacing it entirely
- Removed the backdrop blur filter from the lyrics and queue bottom sheets. Both sheets retain their background color, border, and shadow without the blur effect
- Redesigned the desktop now playing experience with a resizable side panel on the right side of the application window, replacing the previous bottom sliding panel
- Added a drag handle between the main content and the now playing panel, allowing users to resize the panel width between 280 and 600 pixels
- The panel width and visibility state are persisted across application restarts using Hive
- Added a show/hide toggle button in the sidebar for the now playing panel, visible in both expanded and collapsed sidebar modes
- Added a fullscreen toggle button in the now playing panel on wide screens (greater than 800 pixels), which expands the now playing view to fill the entire application window with a fade transition
- On narrow screens (800 pixels or fewer), the now playing panel displays a minimize button instead of the fullscreen toggle, consistent with the mobile experience
- The fullscreen and minimize button selection is now based on screen width rather than platform, ensuring correct behavior across window sizes
- Animated the now playing panel sliding in and out when toggled via the sidebar button, using a clipped alignment transition with an ease-in-out cubic curve
- Fixed library section titles overflowing when the main content area is narrowed by the side panel, by wrapping title text widgets with flexible layout and ellipsis truncation
- Fixed a GetX improper use error in the sidebar that occurred when no observable variables were read inside an Obx widget on desktop layouts
- Fixed the resize handle position resetting on each rebuild by converting it to a stateful widget to persist drag position across rebuilds
- Fixed the now playing panel causing layout overflow by replacing the full-screen Player widget with StandardPlayer, wrapped in a MediaQuery override to respect the panel's constrained dimensions
- Updated the compact now playing layout to use LayoutBuilder constraints instead of MediaQuery for sizing, preventing overflow inside the constrained side panel
- Adjusted the queue drawer bottom margin on desktop to account for the removal of the mini player bottom bar
- Made PanelController methods safe to call when not attached, returning early instead of asserting, to support the desktop side panel layout where no SlidingUpPanel is used
- Reordered the Windows and Linux window control buttons to close, maximize, minimize (x, +, -) to match the sidebar layout (!112)
- On Hyprland (Wayland), only the close button is now shown since client-side minimize and maximize are not supported (!113)
- On KDE (Plasma), the in-app window controls are now hidden since the window manager draws its own title bar (!114)
- Fixed YouTube Music playback, including 403 errors, by switching to a patched `youtube_explode_dart` fork and moving `just_audio_media_kit` in-tree (!117)
- Reworked the settings page with a real desktop sidebar, updated server add/edit dialogs, and improved accessibility text (!119)
- Fixed theme changes not applying, including when following system brightness, by syncing `onThemeChange` with `appThemeProvider` (!120)
- Fixed a crash in settings sub-pages caused by looking up localizations on a deactivated widget (!121)
- Fixed album art appearing squashed on the vertical now playing screen (!122)
- Removed unsupported translation JSON files (!123)
- Added a `Now playing layout` setting on desktop to choose between a side panel or a play bar, and fixed the play bar layout on large screens and when changing the setting (!124)
- Removed Riverpod and consolidated app settings and theme management under GetX (!126)
- Fixed a return type warning in `audio_handler` `catchError` handling (!127)
- Fixed the fullscreen player duration display truncating hours for songs over one hour, so 1:03:05 no longer appears as 03:05 (!128)
- Fixed the now playing player showing a fullscreen button instead of a minimize button when opened from the bottom bar on wide screens, so the panel can be closed correctly
- Fixed `PlaybackDiagnosticsService` not being registered before `AudioHandler` initialization (!132)
- Redesigned the App Info settings card with a compact horizontal header and fixed GitLab description text truncation (!137)

## 20.0.1

- Bump version to 20.0.1
- Apks with 16k alignment (!42)

## 20.0.0

### Added
- Confirmation dialog before deleting a server. (!23)
- Protocol dropdown (HTTPS/HTTP) when adding or editing a server, defaulting to HTTPS. (!27)
- Server URL input now automatically strips existing protocol prefixes. (!27)
- "Your favorites" track row section on the home screen for all providers. (!19)
- App icon displayed next to the app name in the App Info settings section. (!25)
- Heart button in the mobile mini player to quickly favorite/unfavorite the current song. (!29)
- `PLAYSTORE` compile flag that directs the update dialog download button to the Google Play Store instead of the website when building Android releases. (!36)
- `NoOpBackend` stub to gracefully handle the app when no media server is configured. (!37)
- Hidden easter egg to unlock the YouTube Music provider on Play Store builds (long-press the app icon in Settings → App Info). (!37)

### Changed
- Removed sliding transition animations when switching between main tabs and content pages for a snappier experience. (!8)
- Redesigned bottom navigation bar with a cleaner, more compact custom design and integrated mini player. (!16)
- Mobile mini player is now a full-width flat bar instead of a floating pill, with reduced height and smaller album art. (!16)
- Now playing screen no longer auto-opens on mobile when pressing play, matching desktop behavior. (!11)
- Theme mode selector changed from dialog to dropdown with custom styling. (!12)
- All dropdowns redesigned with custom icons, colors, and rounded corners. (!12)
- Removed redundant "Active" badge from Servers settings and desktop two-pane selected section indicator. (!12)
- Favourites quick action card hidden when user has zero favorites. (!18)
- Replaced "Shuffle all" quick action with "Start radio" for YouTube Music servers. (!19)
- YouTube Music users now see a hybrid home feed combining personalized local sections and YouTube Music content. (!19)
- Default synced lyrics highlight style changed to karaoke. (!24)
- "Random" removed from radio labels to avoid implying random song selection. (!19)
- CI pipeline made manual to reduce costs. (!22)
- Removed redundant YouTube Music add server dialog since it does not require login credentials. (!21)
- Removed the compact short desktop mini player state that appeared before the mobile shell took over. (!30)
- YouTube Music is hidden from the "Add Server" provider picker when building with `PLAYSTORE=true`. (!37)
- Fresh installs no longer create a default YouTube Music server when building with `PLAYSTORE=true`. (!37)

### Fixed
- Status bar overlap on mobile. (!9)
- Settings screen layout not extending full height in two-pane view. (!12)
- Theme switching properly updates all UI providers. (!17)
- ListTile rendering and ink splash issues. (!17)
- UI unresponsiveness caused by improper reactive widget nesting. (!17)
- Bottom navbar not navigating away when on settings sub-pages on mobile. (!13)
- Settings header alignment on mobile. (!15)
- Back button visibility in light mode. (!17)
- Now playing bottom bar icon visibility in light mode. (!17)
- Home screen quick action card borders not visible in light mode. (!17)
- Search bar background and border colors in light mode. (!17)
- Switch/toggle "on" state visibility in light mode. (!17)
- Home screen favorite count not updating reactively. (!18)
- Incorrect "Your library is empty" message showing when library sections exist. (!18)
- Radio seeding from a random favorited song instead of a fallback chain. (!19)
- Nested scroll view issues in YouTube Music home feed. (!19)
- Desktop player song title overflow. (!20)
- Full-screen player title text wrapping. (!20)
- Localization strings showing literal `\n` instead of rendering as newlines. (!26)
- Radio mode button now hidden on the now playing bar when not connected to a YouTube Music host. (!32)
- Window controls (close, minimize, maximize) not working on macOS. (!33)
- YouTube Music search results page showing blank due to parsing logic not handling itemSectionRenderer sections. (!34)
- YouTube Music community playlists search parameters updated to use double-letter codes matching ytmusicapi reference implementation. (!34)
- "Add Server" button now visible even when no servers are configured. (!37)

## 19.0.0

- Settings panels are now scrollable. (7e507cf4)
- Adds a new radio mode for YouTube Music (b343dfe4)
- Ensure other servers can't affect other servers (359406c5)
- YouTube Music will show some songs if you have nothing added (37703e9c)
- Fix the desktop bottom bar favorite button not updating when clicked until state refreshed (9a388abd)
- The navbar actions are now centered (275a1a87)
- Switching servers will cancel the current queue (20aa5900)
- Don't show sections with 0 data in the song info panel. (912a1592)
- Format timestamp for song info. (5312d49c)
- Hide quick action cards if they have 0 data. (2e6b01df)
- Fix mini player not updating UI states. (4b769644)
- Show the time stamps in the desktop player. (be2069e6)
- Detailed artist view will scroll with the user content (ab511dec)
- Fix library songs/artists/downloads tabs appearing empty when using non-English locale. (2e311258)
- Fix queue crashes when switching servers with an empty or single-item queue. (2e311258)
- Dont show the username on the top with the back button. (687b5438)

## 18.0.0

- Show song details in the system tray. (0092c7cf)
- Removes top text from home page. (005d4442)
- Updated description. (fc5e3f26)
- Updated version. (7947844b)
- Updated system tray package. (7f524096)
- Remove the scroll bar form the sidebar on desktop. (ebdf4d87)
- Fix the lyric service not working from non yt music servers. (2032c267)
- Polished the lyrics display UI. (4f868907)
- Click on album art to open the full screen player. (bf775058)
- Polish the add to playlist screen. (0573b915)
- Opening the queue will open to the current song playing. (a1ec3595)
- New window controller for desktop (linux, macos, windows). (a7cc8aa2)
- Polished sidebar design for desktop. (be7645bc)
- Polished playing bar design for desktop. (0935c5cd)
- Fix the downloads button like being a differnt scale and size and stuff from the rest of the icons. (e00ff4ef)
- Updated description to "Stream music correctly." (fc5e3f26)
- Updated the new version dialog design. (eab43435)
- Remove wasted space in the home screen. (14b08b32)
- Remove the hover message on the sidebar. (a655332b)

## 17.0.0

- Fix macOS youtube music playback (267de25e)
- Set a smaller default window size for macOS (21ad9177)
- fix add to playlist window not matching the theme of the app (4b2107e2)

## 16.2.0

- Navbar design tweaks (e0dadf10)
- Skeleton refactor for pages up to 50% faster in some pages (d0d1cf67)
- New animations for changing pages (95d41920)
- Fixed the universal back button on subpages in the settings screen (986372df)
- Search bar now supports themeing (1cfa4de9)
- Fixed downloads screen (fc96e63d)
- Fixed songs and artists pages from loading (e04537be)
- Premade playlists now repsond to themes (647cf602)
- Span custom art (d6e103f4)

## 16.1.0

- en_AU patches (9a16a3c3)
- Fix album art animations (fb809ee9)
- Fix Animations not being smooth (fb809ee9)
- Removed getX (3ddd1008)
- Fixed andriod back buttons on some sub pages. (1c8f0b64)

## 16.0.0

- Brand new app
- Everything has been rewritten to just work. We are done with bugs and unimplamented features

## 15.1.0

- fixed nav bar (9a42dc97)

## 15.0.0

### Highlights

- **YouTube Music**: New provider (select in Server type). Search and stream without login. Home shows Harmony-style layout with Quick picks, Popular playlists, Trending; search shows Artists, Playlists, Songs. (1d3a5b45, 93d29057, 376dcba3)
- **General options** (Settings > General): Toggles for Lyrics, Downloads, Volume on player bar, Queue button, Shuffle & repeat (desktop). YouTube Music can be re-enabled on Windows/Linux (off by default on desktop). (da0ce7be)
- **Onboarding**: Language → Theme (System/Light/Dark/OLED) → Accent colour → Get Started. Localized (English, 中文, Русский). When not logged in: welcome message and no-server screen after Get Started. (829b49c0, 731ffa49, 407ec699, 8b25853c)
- **Multi-server**: Add, edit, remove, switch saved servers without reload. Settings > Server lists saved servers; legacy single-server prefs migrate on first load. (6b4e56e4)
- **Detail headers**: Gradient derived from cover image (dominant color, darkened). Fades in over 280ms; no flicker. Shuffle/Play are circular icon-only; Shuffle in horizontal scroll on narrow panels. (2ec5a0c9, 7a1ee1bf, 4d2b0f13)
- **Artist/album/playlist**: Clickable artist names (no underline) open artist page when in library. Albums/Songs tab is animated segmented control (purple pill, 220ms). Tab bar full width, equal segments. (53bd41f9, 9fabeccc, 058aebf3)
- **Now playing**: Single responsive screen (mobile & desktop, breakpoint 900px). Compact: carousel, progress, controls, queue/favorite/lyrics/more. Expanded: album + controls left, Up Next / Lyrics right. Download in more-options: start, cancel, or delete download. Volume control. Close button clears queue and stops playback. (8ad18d8c, 1fe0d40d)
- **Now playing polish (release pass)**:
  - Desktop uses blurred artwork background and improved spacing for smaller heights.
  - Play/pause visual treatment unified (no gradient orb styling).
  - Volume controls support keyboard shortcuts and toggle-style panels.
  - Queue and lyrics panels now hide/show contextually based on availability.
- **YouTube Music follow-based home**:
  - Home supports followed content and guidance when library is empty.
  - Follow actions for artist/album/playlist with per-server persistence. (6b095e67, a700ca2a)
  - Mix-style playlists are excluded from follow surfaces. (386ac306)
- **Search**: Full-width bar. Shows albums, artists, songs for all providers; YouTube Music also shows community playlists. Server URL validation rejects YouTube Music with clear message. (ab357379, 95f963d7)
- **Dates**: Year/month/day (e.g. 2025/02/21) for album Added, Settings build date, log names. (a7a8a12a)

### Design & UI

- **Organic refined** look: AppTokens (Plus Jakarta Sans + Nunito, teal accent, warm dark palette, soft radii). Same tokens on desktop and mobile; light, dark, OLED. (618de3ca)
- **OLED**: Pure black (#000000) everywhere when OLED theme selected. Dark mode uses charcoal (#1C1C1E). (dc21ac99, 30dcaf52)
- **Gemini-style**: Dark palette (#0a0a0c page, #0e0e11 sidebar, etc.). Sidebar: purple logo box, rounded nav tiles, Library label, Settings at bottom. Settings sidebar: section headers, rounded cards, status (e.g. Connected). (dc2b89f1, 8efd0d17)
- **Dialogs**: Apple-style frosted glass (blur, rounded corners, scale/fade). showAppDialog / showAppConfirmDialog / showAppChoiceDialog (Apple* deprecated). Select Language, Theme, accent/custom color redesigned. (618de3ca, c0a6dae2)
- **Mobile**: extendBody so content under nav/player bars; bars use frosted glass. Bottom padding so content not covered by nav bar. (ca8ae532, f9a6a288)
- **Empty states**: Full-width centered icon and text. Home: no header; content starts with quick access and sections. (2318ba40, def33472)
- **Settings**: iOS-style grouped list (Server, Playback, Appearance, About), sub-pages. Connection shows Jellyfin username (User.Name) or "Logged in". Connection box adapts by provider (Local, YouTube Music, Jellyfin/Plex/Subsonic). (21787727, 103a9b0a)
- **Queue/lyrics overlays**:
  - Current track is pinned at the top of queue presentations.
  - Lyrics open at the current playback position.
  - Lyrics tabs/buttons are hidden when lyrics are unavailable.

### Fixes

- **Queue**: Clear queue also clears current track and emits null so player bar hides. (8ad18d8c)
- **Layout**: Mobile nav no longer overflows on resize (Expanded + FittedBox). KeyedSubtree on breakpoint switch avoids _elements.contains assertion. (35471c5c)
- **Dialogs**: showAppleDialog (and Add/Edit server) use actionsBuilder so Navigator.pop uses dialog context—fixes "Looking up a deactivated widget's ancestor" when caller screen already closed.
- **Search**: Bar no longer Expanded inside PageTemplate (layout crash); use fixed width (320px). (8698ce4a, 95f963d7)
- **Server settings**: Subsonic/Navidrome config data shown via displayServerUrl and displayUsername on login/restore. (109d0485)
- **Now playing**: Album/artist lines under title have no underline. Lyrics: no yellow underline (TextDecoration.none). (53bd41f9, 0eb0ffd3)
- **Now playing**: Volume overlay no longer blocks slider drag; tapping outside closes the overlay. (49f0c68d)
- **Now playing**: Added mobile parity for The Mind Electric easter egg behavior. (11ceb9a9)
- **Settings**: Reliable scrolling (AlwaysScrollableScrollPhysics, ConstrainedBox). Add/switch server no longer kicks you off Settings (shell keeps selection). (7e507cf4, 39c966ff)

### Removed

- Android Auto, voice commands (Google Assistant, deep links, MEDIA_PLAY_FROM_SEARCH, shortcuts). (afc85d4c)
- Dynamic Isle / mini player island. Standalone Local Music screen (config in Settings only). (f48c7195, d56153b1)
- Refresh buttons (Library, Albums, Artists, Playlists, Tracks, detail, Rescan). Login screen (main shell always; Connect/Disconnect in Settings). (afede3e4, 37dd6e2a)
- Unused: cached_image.dart, apple_design/glassmorphism.dart. General settings section (OLED/Show album art moved to Theme dialog). Mobile-only UI. (de55fa65, d90127c4, dd32be9f)

### Linux

- YouTube Music disabled in Server type and saved list by default; if current server was YT Music on startup, app switches or disconnects. (23f2a5db)
- YouTube Music playback: media_kit (mpv), setlocale(LC_NUMERIC, "C") before mpv to avoid "Non-C locale" crash. Fallback: ~/.config/mpv/mpv.conf with ao=pulse,pipewire,alsa. Packaged .desktop uses LC_ALL=C. (9cb36b2e, 6a6b23d1)
- Other Linux playback: audioplayers (GStreamer). Install gstreamer, gst-plugins-base, gst-plugins-good, gst-libav. (78a8685e, 49326132)

### Refactors & performance

- **Single codebase**: One set of Dart UI for mobile and desktop; sidebar ≥768px, bottom nav on mobile. No ui/desktop vs ui/mobile split. Navigation in lib/services; theme in lib/ui/theme. (dd32be9f)
- **Dialog API**: showAppDialog, showAppConfirmDialog, showAppChoiceDialog, AppDialogOption. Theme/layout in app_tokens.dart, desktop_theme.dart. (618de3ca)
- **Startup**: System info logging after first frame. Isolates for dominant color, cache/API JSON (Jellyfin, local). List keys, lazy tab loading, Selector for playlists/artists/albums. Now playing: AnimatedBuilder for skip/snap-back (no setState per tick); blur limited to header. (39ea6e90)
- **YouTube Music**: Prefer 96–160 kbps stream; position-based completion fallback on mobile for auto-play/next. (a7e25d5c)
- **Lint**: mounted checks after async (media_details, settings_page); braces in now_playing lyrics. (6b3edae6)
- **Cleanup**: Add-to-playlist consolidated (Create New Playlist in DesktopLayout; used from now-playing and home). ArtistDetailScreen vs ArtistDetailsPage clarified. Page template title: TextDecoration.none. (03357b9f)

## 14.0.0

- New UI for both desktop and mobile. (88e7fd91)
- Don't show desktop sidebar when on small screens. (f1d8d3e3)
- Remove logging. (dd58a214)
- Expand the about Doudou section. (e7263bfa)
- Port the old navbar. (a2cfc97c)
- Settings scales. (c3f0860d)
- New app layouts. (88e7fd91)
- Port the now playing screen. (3f9a3063)
- Spec bump to 14.0.0. (7f75e427)
- Mobile track now goes left from right. (2686a9b5)
- Lyrics icon is now a microphone; only shown when lyrics are available. (a77431a3, 09eba224)
- Fixed animation when reversing a song. (ca12618a)
- Updated dependencies: dio, clipboard, vibration, file_picker. (48c69fe8)

## 13.0.0

- Spec bump to **13.0.0**. (5a22f750)
- Complete UI rewrite with a new adaptive shell and fully replaced login/library/settings screens. (0b3a7fcb)
- Added platform-native app modes: Material for Android and Cupertino for iOS. (07fde17d)
- Added shared UI section definitions for mobile and desktop, with separate layout files for each.
- Added responsive state-safe navigation so current section/search state persists when switching layouts.
- Unified theme + localization controls in the rewritten settings screen (light/dark/system and language selection).
- Removed the entire legacy `lib/UI` implementation so only the rewritten UI stack is active. (bd58872b)
- Added top-bar shuffle controls (Shuffle All + Shuffle Favorites) and removed refresh actions from nav/header areas.
- Added Settings option to switch UI style between System, Material, and Cupertino. (07fde17d)
- Refined Cupertino rendering for a more native iOS/macOS look by using Cupertino scaffolding and controls throughout the rewritten shell.
- Fixed multiple overflow/jank issues in cards, section headers, tiles, and now-playing controls.
- Reduced mobile navigation crowding by using compact label behavior on smaller widths.
- Simplified the mobile UI controls by reducing top-bar and per-track action clutter. (767f737d)
- Reduced mobile bottom navigation to core destinations only.
- Improved Home overview card scaling so it adapts cleanly across narrow and wide layouts.
- Added reusable detailed views for albums, playlists, and artists. (767f737d)
- Added navigation paths from tracks/cards/lists into album and artist detail views. (1c19294c, 1c8f0b64)
- Fix yellow underlined text on the arist_detailed view page. (fbe686bc)
- Fixed mobile artists page showing yellow underlined text by applying consistent text-decoration overrides. (a4486cac)
- Fixed yellow underlied text on the playlist page. (f7539e20)
- Fixed bug on android where the langage setting would override the app's lanage. (10419315)
- No play icon on the artist page on the desktop page. (4d943b13)
- Placeholder artist icon. (3365c13b)
- Don't show albums on deatiled_artist page when no albums are applyable. (a18b2049)
- Implemented updated desktop Library empty-state cards for Genres and Years to match the new design. (407ab26b)
- Use a template for tracks on mobile. (286e0586)
- Made mobile bottom-nav labels always visible so section names are shown on all widths.
- Updated Cupertino mobile bottom navigation to a floating rounded style.
- Added mobile Home quick actions for Shuffle All and Shuffle Favorites.
- Added a playlist-aware track action to remove individual songs directly from a playlist. (cb49efe2)
- Made track context options open immediately on right-click/secondary-click. (13ae70d7)
- Fixed detail header content being covered by the top navigation bar on pages like playlist details. (51ad433e)
- Updated detailed page top-bar styling to better match the liquid glass theme. (ed63b5f7)
- Made detailed page album-art glow colors dynamically derive from each cover image instead of a fixed purple glow. (ea9e6c93)
- Applied the same album-art-derived glow color behavior to the now-playing carousel artwork. (abba86fb)
- Fully integrated shuffle and loop/repeat mode state handling across now-playing UI, audio handler, and queue management. (63ab94a7)
- Fixed multiple reliability gaps: local playlist operations now work in media service manager, desktop playlist play/shuffle actions are functional, queue shuffle indices stay correct after removals, and duplicate audio listeners in app state are prevented. (0d1d59a8)

## 12.1.0

- Spec bump to **12.1.0**. (3d3ae2f1)
- Redesigned shuffle buttons on home page to better match the glass-morphism theme. (ee7607d0)
- Fixed lyrics not loading on desktop - now properly fetches and displays synced lyrics. (e4d4ec33)

## 12.0.1

- Updated donate URL | https://openlyst.ink/support (729930a1)
- Version bump to 12.0.1
- Haptic feedback for favorite button (2391af36)

## 12.0.0

### Added
- Added Downloads page to desktop UI with full download management support. (4b75789e)
- Added Download button to track context menu in desktop UI for offline listening. (23227bee)
- Added track options menu to desktop now playing bar with queue, playlist, album, artist, and download actions. (0800ba03)
- Added "Check for Updates" feature to mobile and desktop settings that checks the OpenLyst API for new versions. (0b46418d)
- Added album art carousel to mobile now playing screen with rotary-style animation; swipe or tap side albums to change tracks. (d00828f5)

### Fixed
- Fixed "No CupertinoLocalizations found" error on mobile pages by using GlobalCupertinoLocalizations delegate. (f2f5ae70)
- Fixed Windows unable to play any music by initializing JustAudioMediaKit for all desktop platforms (Windows, macOS, Linux). (4f4f0f12)
- Fixed Windows local music playback by using correct `file:///` URI format for Windows paths. (223abe4e)
- Fixed SMTC artwork loading errors on Windows when playing local music files.
- Fixed local music album covers not displaying on desktop by adding support for file:// URIs in image widgets. (ae4e16db)
- Fixed local music metadata (title, artist, album, duration) not being read from ID3 tags by adding `audiotags` package. (ec1e06c6)
- Fixed local music albums with various artists creating duplicate album entries by using album artist or folder path for grouping. (91bb00a9)
- Fixed local music embedded album art not being extracted from audio files. (b1c2bd21)
- Fixed desktop home page "See All" buttons and Quick Access cards not navigating to their respective pages. (2c3c79fe)
- Fixed desktop play bar and now playing overlay not showing album art for local music files. (833f49ff)
- Fixed mobile UI not displaying album art for local music files (home, playlists, queue, track lists, album/playlist detail views). (84898fa3)
- Fixed mobile albums page showing yellow underlined text for album names and artist names. (24f02eba)
- Fixed mobile image loading showing error state while loading local files instead of proper placeholder. (24f02eba)
- Fixed mobile songs and favorites pages showing "BOTTOM OVERFLOWED BY 1.00 PIXELS" error by increasing item extent to match actual content height. (24f02eba)
- Fixed mobile search saving every keystroke as a recent search; now only committed searches (submit/tap) are saved. (13632164)
- Fixed adding local music on android.
- Fixed `use_build_context_synchronously` warnings in Quick Connect authentication flow.
- Fixed `use_build_context_synchronously` warning in local music settings artwork cache clearing.
- Fixed `use_build_context_synchronously` warning in settings local music scan completion.
- Fixed downloads not working for Navidrome/Subsonic servers by updating DownloadService to use MediaServiceManager for multi-platform support. (b99e67d7)
- Fixed overflow issues on Downloads page for album cards and track list actions. (61bb86e5)
- Fixed desktop volume slider UI not updating when dragging or clicking mute button. (bad1f1ac)
- Fixed VR headsets loading the Android Auto UI. (5ba4e282)
- Fixed Account Information section not displaying for Navidrome, Subsonic, Plex, and Swing Music servers. (2429249a)
- Fixed Windows volume slider bypassing system volume mixer by disabling WASAPI exclusive mode. (ce08ddeb)
- Fixed desktop light mode to apply across the UI instead of only partially updating. (7946d045)
- Fixed local music "Continue" button not navigating to home screen after successful login. (0941dc47)
- Fixed Subsonic/Navidrome login not navigating to home screen after successful authentication by adding explicit navigation. (a716ea23)
- Fixed mobile queue overlay showing yellow underlined text by adding proper Material wrapper and TextDecoration.none styles. (c7d79ab8)

### Changed
- Added "Smart back" audio toggle (mobile + desktop): if over 20% into a track, first back resets to 0:00; a quick second back goes to the previous track. (a5467766)
- Simplified desktop settings layout to show only implemented options and clean up unused toggles. (3f237ecc)
- Removed icons from home page section headers and shuffle buttons for cleaner mobile UI. (811625e9)
- Removed emojis from login screen feature pills for a more professional appearance.
- **Major codebase cleanup**: Removed all debug print statements (`kDebugMode` blocks) and verbose comments from 87 dart files across the entire codebase including screens, services, providers, widgets, models, and desktop folders. (f970fa45)
- Simplified navigation bar code structure.
- Removed unused `_debugLinuxMpv()` function (~145 lines) from main.dart.
- Dynamic Isle Player is now disabled by default. (c1b6919d)
- Moved the UI to a new folder UI. (f71f4032)
- Refactored mobile Settings screen to use reusable components. (9f98966d)
- Hide Downloads page/tab when using local music mode (since files are already local). (6137ede9)
- Replaced desktop home page quick access cards (Liked Songs, All Albums, All Artists, Shuffle All) with two focused buttons: "Shuffle All" and "Shuffle Favorites". (e031dca0)
- Removed Quick Access section from mobile library page for a cleaner layout. (3b87954c)

### Performance
- Cached `ImageFilter.blur` instances across mobile UI to prevent GPU recomputation on every frame (liquid_glass, mini_player, library, search, favorites). (e47c3a87)
- Converted `Consumer<AppState>` to `Selector<AppState>` with `shouldRebuild` in home, library, songs, and search screens to reduce unnecessary widget rebuilds. (e47c3a87)
- Added 300ms debounce timer to search input to reduce CPU usage during typing. (e47c3a87)
- Added `itemExtent` and `cacheExtent` to `ListView.builder` widgets in home screen for smoother scrolling. (e47c3a87)
- Changed `SliverList` to `SliverFixedExtentList` with fixed item heights in songs and favorites screens for better scroll performance. (e47c3a87)
- Wrapped expensive `BackdropFilter` widgets in `RepaintBoundary` to isolate repaints. (e47c3a87)

### Removed
- Removed non-functional Google Cardboard VR player feature (entire `lib/cardboard` folder and related settings). (0173a810)
- Removed non-functional audio settings: Normalize Volume, Gapless Playback, and Autoplay. (c213aea3)
- Removed Swing Music support. (08ae6998)
- Removed non-functional Collections and Genres sections from mobile library view. (0e8fabd5)

## 11.0.0

### Added

- **Desktop System Media Controls** - Control playback from your OS taskbar/system tray without focusing Doudou.
  - Windows: System Media Transport Controls (SMTC) via `audio_service_win` plugin
  - Linux: MPRIS (D-Bus media controls) via `audio_service_mpris` plugin
  - macOS: Control Center integration (built into `audio_service`)
- **Google Assistant Support** - Voice commands for Android via Google Assistant App Actions:
  - "Play music on Doudou"
  - "Play [artist/song/album] on Doudou"
  - "Play my favorites on Doudou"
  - "Shuffle my music on Doudou"
  - "Next/Previous song on Doudou"
  - "Pause/Resume music on Doudou"
- **Autoplay** - Automatically plays similar music when the queue ends (same artist, album, or random tracks from library). Can be toggled in Audio Settings.
- Added favorite button to the desktop fullscreen Now Playing overlay. (afb2d83f)
- Added favorite button to the desktop player bar.
- Added Easter Egg: Desktop Now Playing view flips horizontally when "The Mind Electric" plays its reversed section (before 2:50). (afb2d83f)

### Changed

- Refactored audio system from 4 platform-specific handlers (~4,200 lines) into a single cross-platform `UnifiedAudioHandler` (~1,550 lines). (474f4890)
- Changed app description to "Play your music with ease". (6f34f5ee)
- **Complete Desktop UI Redesign** with modern styling:
  - Reduced desktop layout code from ~4,055 lines to ~1,940 lines (52% reduction)
  - Modern sidebar with hover effects, accent color highlighting, and organized library sections
  - Sleek bottom player bar with hoverable progress bar, track info, and playback controls
  - Full-screen Now Playing overlay with blurred album art background and tabbed queue/lyrics panel
  - Keyboard shortcuts: Space for play/pause, Ctrl+Arrow for skip
- Desktop Now Playing panel tabs (Up Next, Lyrics) now share the same album art background as the main player view. (859bebd5)
- Album, artist, and playlist detail views now render inline within the desktop layout instead of navigating to a separate page. (b56cb2e0)
- Desktop sidebar is now scrollable when the window height is very small.
- Desktop player bar is now hidden when no music is playing.

### Fixed

- Removed external service references (Spotify, YouTube Music) from code comments.
- Removed implementation-specific developer notes and bash script references from service files.
- Simplified verbose doc comments in UI components while keeping section headers.
- Fixed squished artist cards on desktop by implementing responsive grid (2-8 columns based on width). (0d21564c)
- Fixed "RenderAspectRatio has unbounded constraints" crash in desktop search results. (ff7056f8)
- Fixed mounted check issues causing setState calls after widget disposal in hover callbacks. (ff7056f8, 086b2a13)
- Fixed Now Playing overlay not updating when the current song changes. (039ad858)
- Fixed "BOTTOM OVERFLOWED BY X PIXELS" error on desktop album cards. (5b226455)
- Fixed sidebar overflowing when window is resized very short vertically.
- Fixed detail pages staying open when clicking a different sidebar item.
- Fixed Subsonic library only loading 500 tracks (now uses `search3` pagination to fetch complete library). (8bc4f130)
- Fixed macOS build failure caused by `audiotags` package linking errors (undefined symbols for x86_64). (56363d7e)
- Removed discontinued packages (`touch_bar`, `palette_generator`) and updated `file_picker`/`device_info_plus` to latest versions. (a90cd270)

## 10.0.0

### Added

- Added swipe left/right gesture on the mini player to skip to next or previous songs. (fb96255e)
- Added API key authentication for Jellyfin (X-Emby-Token) as an alternative to username/password login. (e5252af8, f180cbdf)
- Login screen now shows a toggle between "Account" and "API Key" auth methods for Jellyfin. (ac2c84d8)
- Added MarqueeText widget for auto-scrolling text display. (a43877f7)
- Added iOS-style haptic feedback when tapping navbar buttons. (17ed71e6, df3ff7f1)
- Added Developer Website button in Settings to open the Openlyst website. (1f6564ea)
- Added Quick Connect support for Jellyfin - login by entering a code displayed in your Jellyfin server dashboard. (871997c9, 2b339f4f)
- Added new `DesktopTheme` system with modern liquid glass styling for desktop. (18b7c89f)
- Added reusable desktop components: `DesktopGlassContainer`, `DesktopPlayButton`, `DesktopIconButton`, `DesktopNavItem`, `DesktopProgressSlider`, `DesktopGlassButton`. (18b7c89f)
- Added "Add to Playlist" button in desktop Now Playing screen to quickly add the current track to any playlist. (8efd71f2)
- Added new music card components: `MusicCard`, `MusicListTile`, `FeaturedMusicCard`, `QuickAccessCard` with hover effects and glow. (b1ff699a, 42892e85)
- **Local Music Support** - Play music directly from local filesystem directories without a media server. (1c9955d6)
- Added `LocalMusicService` for scanning and playing local audio files (MP3, FLAC, WAV, OGG, M4A, AAC, WMA, OPUS, AIFF, ALAC, APE, WEBM). (1c9955d6)
- Added `AlbumArtService` for fetching album artwork from multiple sources:
  - Embedded metadata extraction using audiotags package
  - Local image files (cover.jpg, folder.png, etc.)
  - Online providers: MusicBrainz and Cover Art Archive APIs
- Added Local Music settings screen for managing music directories. (bcc4e8c4)
- Added artwork settings with online artwork toggle and cache management. (7d5fcc53)
- **Local Playlists** - Full playlist support for local music with create, rename, delete, add/remove tracks, and reorder functionality. (2216573f)
- Added playlist persistence for local music using SharedPreferences. (2216573f)
- **Swing Music Server Support** - Added support for [Swing Music](https://github.com/swingmx/swingmusic), a self-hosted music player and server.
  - Full authentication support using JWT tokens
  - Browse albums, artists, and tracks
  - Playlist management (create, rename, delete, add/remove tracks)
  - Search functionality
  - Favorites/starring support
  - Audio streaming via the Swing Music API

### Changed

- Desktop Now Playing album art glow now uses the dominant color extracted from the album artwork for a more dynamic and immersive visual effect.
- Redesigned the Favorites screen with iOS 26 liquid glass styling.
- Favorites screen now uses LiquidGradientBackground with glassmorphism effects.
- Updated Favorites empty state with glass card and gradient heart icon.
- Added stats card with track count badge to Favorites screen.
- Jellyfin service now reads app version from pubspec.yaml for User-Agent headers instead of hardcoded "1.0.0".
- Now Playing screen title now displays on a single line with YouTube Music-style scrolling for long titles. (78df0dec)
- Support button in Settings now opens the Communist Party of Ireland website. (10f075e3)
- **Complete desktop UI redesign** with modern liquid glass aesthetic matching mobile styling. (11099bb4)
- Desktop sidebar now uses frosted glass effect with gradient accent colors.
- Desktop bottom player bar redesigned with glass effect, gradient progress slider, and modern controls.
- Desktop Now Playing screen updated with album art glow effects and modern styling.
- Desktop home page updated with `QuickAccessCard` components and time-based greeting.
- Desktop page templates now support gradient headers.
- **Desktop Settings** now adapts to local music mode - shows directory management, rescan, and artwork options instead of server settings. (1d277d2f)
- **Mobile Settings** Account Information section now shows local music info (directories count, music source) when using local music. (9269e04b)
- Settings sidebar shows "Local Music" with folder icon when in local mode instead of "Server". (9ff29a05)
- Login screen server type cards now have standardized 88x100 pixel dimensions with proper centering. (4714a507)
- Login screen server type section now scrolls horizontally on desktop to prevent overflow. (68651dfa)
- `CachedImageWidget` and `CachedImage` now support local file paths (file:// URLs and absolute paths). (d26c1f36, 470d0cbe)
- Improved logout functionality to fully clear all persisted data including local music cache. (b814d205)
- Updated to new Openlyst url. (729930a1)

### Fixed

- Fixed download button not responding when tapped (download service listener not connected to AppState).
- Fixed Settings screen logout button being covered by navbar and mini player. (3b2026db)
- Fixed account login failing after attempting API key authentication (stale X-Emby-Token header). (bbe9e07b)
- Fixed album/artist cards overflowing by 4 pixels on desktop home page.
- Fixed "Callback invoked after it has been deleted" crash when changing tracks on desktop by recreating the AudioPlayer instance for each track, fully isolating native media_kit/mpv callbacks.
- Fixed track duration timestamps in desktop Now Playing "Up Next" queue showing incorrect values (was treating milliseconds as seconds).
- Fixed Subsonic track durations displaying incorrectly (Subsonic API returns seconds, now properly converted to milliseconds).
- Fixed Subsonic service skipping the 2nd song in queue.
- Fixed Subsonic favoriting not persisting (track refresh was replacing starred tracks with new random songs).
- Fixed Subsonic API implementation to spec - shuffle all and favorites now properly fetch all tracks using search3 pagination and getStarred2 endpoints instead of only loading random songs. (8a024e26)
- Fixed local music album art not displaying (CachedNetworkImage only worked with HTTP URLs, not local file paths).
- Fixed local music cache serialization losing imageUrl paths due to Jellyfin-specific JSON format. (48fc51fa)
- Fixed Continue button not working on Local Music Settings screen during initial setup.
- Fixed server type cards overflowing on narrow desktop windows. (68651dfa)
- Fixed desktop lyrics scrolling off-screen or going too low by adding proper clipping and scroll physics constraints. (e288db4c)

## 9.0.0

### Changed

- Redesign the desktop style sheet. (16ef524c)
- New search page for desktop. (4596b098)
- Redesigned the login page for desktop and mobile. (a3314de3)

### Removed

- Removed downloads from the repo.

## 8.2.0

### Added
- Added support for multiple languages. (148083a9)
- Added support for English. (148083a9)
- Added support for Russian. (f1a6e0b5)

### Changed
- Load in either the desktop or mobile UI depending on screen size rather then system. (efff49f0)

### Fixed
- Fixed builds expireing. So now build will no longer be broken after a week. (d263f891)

### Removed
- Removed big screen UI for mobile. (5effff7b)

## 8.1.0

### Added
- Added a demo mode button to the login page. (9a30b218)
- Added keyboard shortcuts on the now playing screen:
  - `Shift+N` - Skip to next song
  - `Space` - Play/Pause
  - `F` - Toggle favorite
- Added keyboard shortcuts for navigation on the now playing screen. (c5fcf9a0)

### Changed
- Redesigned the now_playing screen for desktops as the theme was seen as bad by early testers.
- Preload lyrics. (9a567fb7)

### Fixed
- Fixed shuffle and repeat buttons not working on the desktop now playing screen. (3abfbb56)

## 8.0.0

The stable out.

### Added
- Added build support for Fastforge. (b95f554e)
- Build support for **deb**, **rpm**, and **appimage**. (b95f554e)
- Support for building OpenHarmony packages. (37529de2, 7695b180)
- Adds basic support for phoneVR headsets. (624e70cd)

### Changed
- Changed final realse builds to have to include a ``final`` var in order to build from main branch. (be714590)
- Refactored names of changelogs to markdown.
- Desktop album, playlists, and others use one template details file. (43ab6d49)
- Desktop details page now uses a fully scrollabe rather then a content template. (8d0bb4f1)
- Desktop now_playing is now fullscreened
- Redesigned the now_playing screen on desktop.
- Added favorites button to now_playing on desktop.
- Made the controols on the now_playing more compact.
- Build details page from top to down.
- Rewrote the the build script. (8fc9598e, d49ba0ff)
- Load app icon in settings.
- Changed unknown version from "6.0.0" to a unknown error.

### Removed
- Remove subtitle from settings version.

## 7.0.0

### Added
- Comprehensive logging system with file rotation and export capabilities
- Mobile and desktop log viewer in settings
- Detailed playback logging for troubleshooting music playback issues
- Queue operation logging for debugging playlist management
- User-configurable logging toggle (disabled by default for performance) (593089bb)
- New desktop UI
- Show the number of times songs have been played (e5ec1e36)
- Plex service (186e74a7)
- Navidrome service (8c852f23)
- Added the ability to favorite songs (48fb2712, cb7b30e6)
- Added debugging info for favorites
- Ability to download songs on desktop
- Use real history for the mobile search page (26546325)
- Redesigned the mobile search page (6cd5b338)
- Allow custom colours for desktop accents (191e8ee8)

### Changed

- New description
- Logging is disabled by default and can be enabled in settings
- Centralized logic for API requests
- Rewrote the Jellyfin service
- Refactored most of the backend for desktop/mobile network connections (ef272c92)
- Refactored the Jellyfin favorite song functionality (0d5f87d3)
- Refactored `now_playing` to use `app_state` for favorites (0d5f87d3)
- Refactored Plex service for generated URLs
- Fixed race issues when pausing music
- Redesigned mobile home page
- Redesigned mobile library page
- Complete rewrite of EVERY audio service file
- Added smooth scaling animation to desktop now playing screen opening and closing with elastic curve and opacity effects for enhanced user experience. (700c7826)
- Completely redesigned login screen with elegant responsive design supporting both desktop and mobile layouts. Features animated gradient backgrounds, smooth transitions, modern Material Design elements, and improved visual hierarchy for better user experience. (a3314de3)
- Fixed mobile login screen black screen issue by adding proper MaterialApp wrapper and fixing layout constraints with appropriate scrolling behavior.
- Added minimal mobile login header with "Doudou - Welcome" text and slide-in animation for better branding while maintaining clean, focused mobile experience. (a5cfe5f3)
- Mobile login screen now respects phone's system theme (light/dark mode) while desktop maintains custom MaterialApp theming. (90ea6ccf)
- Build realse rather the debug.
- Movies player services to thier own folder.

### Removed
- Removed crossfades
- Removed debugging for images
- Removed debugging for audio states

### Fixed
- Fixed skipping on Linux
- Improved playback diagnostics with comprehensive logging throughout the audio system
- Fixed a bug that often caused the audio player to not work when using local addresses (692bb86e)
- Fixed local addresses often failing (692bb86e)
- Fixed clutter in the debugging terminal (68bc6529)
- Fixed main album art using old Jellyfin code (3867c530)
- Fixed switching queues breaking the audio stream (ccd57be8)
- Fixed Custom Spinlock System: Replaced 9 custom spinlock implementations with proper async Mutex system to eliminate busy-wait loops causing CPU spikes and deadlocks
- Fixed Concurrent Player Operations: Implemented AudioOperationQueue to prevent "Loading interrupted" errors from concurrent _resetPlayerStateCompletely and _tryGaplessPlayback operations (6bef4b6c)
- Fixed User Intent vs Player State Desynchronization: Implemented AudioStateMachine to prevent UI showing play button while audio is paused, ensuring synchronized user intent tracking (e77cfa34)
- Fixed Concatenation Race Conditions: Added operation cancellation tokens to gapless playback operations to prevent conflicts when new audio source changes interrupt ongoing concatenating transitions (e77cfa34)
- Fixed Android Bypass Mode Race: Replaced mutable boolean flags with immutable AndroidServiceManager state machine to prevent inconsistent platform-specific behavior during AudioService errors (92654323)
- Fixed Preloader Race Conditions: Implemented reference counting system in AudioPreloader to prevent cleanup of audio sources while they're being prepared or used by the player (daf06c4a)
- Fixed Queue Modification Race: Added proper mutex synchronization to all AudioQueueManager operations to prevent concurrent queue modifications during shuffle, add, remove operations (aa62ad24)
- Fixed Player Position Race: Implemented atomic position updates with debouncing and seek protection to prevent position jumps during seek operations and buffering events (27ab082b)
- Fixed State Persistence Race: Added debouncing to state persistence calls with StatePersistenceManager to prevent file corruption during rapid state transitions (dcbba1e0)
- Fixed Radio Mode Race Conditions: Implemented synchronized RadioModeStateManager to prevent radio mode UI state from becoming inconsistent with actual streaming behavior during mode transitions (d9f8c941)
- Fixed Touch Bar Race Conditions: Added synchronized TouchBarUpdateManager to prevent concurrent Touch Bar updates during rapid track changes from causing visual glitches on macOS
- Fixed Download Service Race: Implemented DownloadServiceCoordinator to prevent download operations from interfering with active audio streaming by protecting tracks during playback (0e0c8a18)
- Fixed bug for forground services audio_ui's may not update causing ui state on mobile to break until tick update. (82b28dd2)
- Fixed desktop automatic track advancement failing when network timeouts occur. Added retry logic with fallback to transcoded streams and skip to next track on persistent failures to prevent silent playback stops. (82b28dd2)
- Fixed web version audio playback failing due to CORS restrictions by implementing direct download URL fallback for better browser compatibility with Jellyfin media servers. (15870e1c)
- Fixed web version track switching playing multiple audio streams simultaneously by ensuring previous audio source is properly stopped before loading new tracks. (15870e1c)
- Fixed web version audio controls being unresponsive by implementing immediate UI state updates with asynchronous audio operations, matching mobile and desktop handler behavior patterns. (15870e1c)

## 6.0.0

### Added
- Added a button to reload all data from the Jellyfin server. (50ff6304)
- Added an animation that plays when album art changes size. (e040dc1b)
- Added a background for the "Now Playing" screen. (db042d70)
- Automatically build `.apk` files.
- Added an indication if a song is playing locally (downloaded) or streaming.
- Added a "Shuffle Favorites" button for downloaded songs.
- Added new options to the drop-down menu on the "Now Playing" screen. (fd9888be)
- Added a kebab menu (three dots) to the album details page with a download option. (8eee7175)
- Enhanced the kebab menu with "Play Next," "Play Later," and "Add to Favorites" options. (acf3844f)
- Added Android Auto support.
- Added support for the macOS platform. (67933ca7)
- Added a new desktop sidebar. (70afc1fb)
- Added web builds. (59c589f2)

### Changed
- Lyrics are now greyed out if none are available.
- Devices are now locked to vertical orientation.
- Album art is smaller when the song is paused.
- The entire audio backend was refactored, which should hopefully lead to fewer bugs.
- The home page was redesigned.
- The album name is now displayed as the title on the album details page. (d52ca56c)
- "Play All" was changed to "Play" on the album details page. (cc3dbe47)
- The "Play" and "Shuffle" buttons are now bolded on the album details page. (9ccaa5c8, d4799b93)
- The "Download Album" button was moved to the kebab menu in the navigation bar. (83777c9e)
- The "Now Playing" screen was completely redesigned with an improved layout and spacing.
- The mini-player will no longer show when a keyboard is open. (f5366960)
- The search page was completely redesigned with unified results and recent searches. (27e5d7f8)
- Uses a template for the album and playlist screens.

### Removed
- The music visualizer was removed (this is not possible with the current audio provider). (b5bdea60)
- The "Now Playing" option was removed from the settings screen.
- The ability to scroll on the "Now Playing" page was removed. (e26b24bf)
- The year was removed from the album details page. (dbc02d1c)

### Fixed
- Fixed synced lyrics text being hidden in some cases.
- Fixed an issue where offline mode was never set to true.
- Fixed autoplay. (1be46550)
- Fixed recently added albums not showing correctly. (37b49e84)
- Fixed the gapless audio playback. (27e5d7f8)
- Fixed the lyrics overlay so it automatically reloads when the track changes during playback. (c0d67382)
- Fixed images for top results not working on the search page. (c0d67382)
- The search page now shows clean, unified results without section headers.
- Fixed iOS being unable to play audio. (6f98c5c0)
- Fixed the "Now Playing" screen overflowing when a large font size is used. (b6b17383)
- Fixed Linux builds not properly initializing the database. (8e21cdc3)

## 5.0.0

### Added
- Pop-out for tracks. (b00bece1)
- **"Add to Queue"** button. (b2e7d47b)
- **"Play Next"** button. (cdbb2ba8)
- Download manager. (014ae7d0)
- Ability to download playlists.
- "Play All" and "Shuffle" buttons for downloaded songs. (2ed66e5d)
- Ability to download albums.
- Navigate to the album by clicking the album name in **Now Playing**. (f5b9db0f)
- Navigate to the artist page by clicking the artist name in **Now Playing**. (7bf4929d)
- Offline mode that keeps users logged in and restricts functionality to downloaded content when connectivity is lost. (0aa6327f)
- **Global Search**: Search across artists, albums, songs, and playlists (af4a611d)

### Changed
- Embedded the visualizer instead of using a separate page.
- Changed the visualizer to a bar style. (ef4dbe4d)
- Added a universal partial component for tracks. (e0d3201e)
- Album detail page now uses the shared track list template.
- Song page now uses the shared track list template.
- Favorites page now uses the shared track list template.
- Scaled album art for better display. (58ed4a58)
- Plays local versions of songs if already downloaded.
- Displays more privacy-conscious data for account info (less identifiable/doxxing content). (dff385d5)
- Changed app ID to reflect new FOSS group. (d7b7d605)
- Displays subtitle as "**Album – Artist**". (c6fb93c7)
- Navbar now has a glass (blurred) effect. (d0bed757)
- Mini-player now has a glass (blurred) effect. (d0bed757)
- Moved account information into its own file/module. (15f3cbad)
- Added scroll effect for album name and artist in Now Playing. (a1fd171f)
- Downloaded albums now reuse the existing album detail screen.
- Downloaded playlists now reuse the playlist screen.
- Moved the queue to its own .dart file.

### Removed
- Removed **Download** and **Favorite** buttons from track list views. (ec05310e)
- Removed **Display Settings** from the Settings screen. (db2da7aa)
- Removed **Audio Quality** options from the Settings screen. (f400e2bb)
- Removed **Settings** icon from the Library screen. (56556b60)

### Fixed
- Fixed playback of favorites from the dedicated favorites page. (29aaf1ae)
- Fixed screen breakage when overlays were active.
- Fixed background playback issues. (c7dd603f)
- Fixed the download page not displaying properly. (ab25a5f8)
- Fixed downloads getting stuck at 100%.
- Fixed **Cancel Download** button functionality. (7789bd94)
- Fixed **Redo Download** button functionality. (3da9bfc2)

## 4.0.0

### Added
- Navigate to the album's page from the search page. (014ab09c)
- Added a button to remove a playlist. (750fe5e4)
- Added the ability to rename a playlist. (644b7b21)
- Added function to normalise audio. (dce81f7e)
- Added real functionality to the favourite button on the playing screen. (b183a00b)

### Changed
- Show the mini-player on the playlist screen. (f3bf86e2)
- Display the mini-player on the songs page. (bbf5b891)
- Music visualiser now uses the colours from the album art. (4839b78c)

### Fixed
- Fixed playlist screen not showing tracks. (08839e19)
- Fixed next song playing when not open. (ef24dd45)
