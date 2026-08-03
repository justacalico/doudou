# Changelog

All notable changes to Doudou are recorded here. This file consolidates the
previously per-version files that lived under `changelog/`.

## 21.0.0

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

## 20.0.1

- Bump version to 20.0.1
- Apks with 16k alignment

## 20.0.0

### Added
- Confirmation dialog before deleting a server.
- Protocol dropdown (HTTPS/HTTP) when adding or editing a server, defaulting to HTTPS.
- Server URL input now automatically strips existing protocol prefixes.
- "Your favorites" track row section on the home screen for all providers.
- App icon displayed next to the app name in the App Info settings section.
- Heart button in the mobile mini player to quickly favorite/unfavorite the current song.
- `PLAYSTORE` compile flag that directs the update dialog download button to the Google Play Store instead of the website when building Android releases.
- `NoOpBackend` stub to gracefully handle the app when no media server is configured.
- Hidden easter egg to unlock the YouTube Music provider on Play Store builds (long-press the app icon in Settings → App Info).

### Changed
- Removed sliding transition animations when switching between main tabs and content pages for a snappier experience.
- Redesigned bottom navigation bar with a cleaner, more compact custom design and integrated mini player.
- Mobile mini player is now a full-width flat bar instead of a floating pill, with reduced height and smaller album art.
- Now playing screen no longer auto-opens on mobile when pressing play, matching desktop behavior.
- Theme mode selector changed from dialog to dropdown with custom styling.
- All dropdowns redesigned with custom icons, colors, and rounded corners.
- Removed redundant "Active" badge from Servers settings and desktop two-pane selected section indicator.
- Favourites quick action card hidden when user has zero favorites.
- Replaced "Shuffle all" quick action with "Start radio" for YouTube Music servers.
- YouTube Music users now see a hybrid home feed combining personalized local sections and YouTube Music content.
- Default synced lyrics highlight style changed to karaoke.
- "Random" removed from radio labels to avoid implying random song selection.
- CI pipeline made manual to reduce costs.
- Removed redundant YouTube Music add server dialog since it does not require login credentials.
- Removed the compact short desktop mini player state that appeared before the mobile shell took over.
- YouTube Music is hidden from the "Add Server" provider picker when building with `PLAYSTORE=true`.
- Fresh installs no longer create a default YouTube Music server when building with `PLAYSTORE=true`.

### Fixed
- Status bar overlap on mobile.
- Settings screen layout not extending full height in two-pane view.
- Theme switching properly updates all UI providers.
- ListTile rendering and ink splash issues.
- UI unresponsiveness caused by improper reactive widget nesting.
- Bottom navbar not navigating away when on settings sub-pages on mobile.
- Settings header alignment on mobile.
- Back button visibility in light mode.
- Now playing bottom bar icon visibility in light mode.
- Home screen quick action card borders not visible in light mode.
- Search bar background and border colors in light mode.
- Switch/toggle "on" state visibility in light mode.
- Home screen favorite count not updating reactively.
- Incorrect "Your library is empty" message showing when library sections exist.
- Radio seeding from a random favorited song instead of a fallback chain.
- Nested scroll view issues in YouTube Music home feed.
- Desktop player song title overflow.
- Full-screen player title text wrapping.
- Localization strings showing literal `\n` instead of rendering as newlines.
- Radio mode button now hidden on the now playing bar when not connected to a YouTube Music host.
- Window controls (close, minimize, maximize) not working on macOS.
- YouTube Music search results page showing blank due to parsing logic not handling itemSectionRenderer sections.
- YouTube Music community playlists search parameters updated to use double-letter codes matching ytmusicapi reference implementation.
- "Add Server" button now visible even when no servers are configured.

## 19.0.0

- Settings panels are now scrollable.
- Adds a new radio mode for YouTube Music
- Ensure other servers can't affect other servers
- YouTube Music will show some songs if you have nothing added
- Fix the desktop bottom bar favorite button not updating when clicked until state refreshed
- The navbar actions are now centered
- Switching servers will cancel the current queue
- Don't show sections with 0 data in the song info panel.
- Format timestamp for song info.
- Hide quick action cards if they have 0 data.
- Fix mini player not updating UI states.
- Show the time stamps in the desktop player.
- Detailed artist view will scroll with the user content
- Fix library songs/artists/downloads tabs appearing empty when using non-English locale.
- Fix queue crashes when switching servers with an empty or single-item queue.
- Dont show the username on the top with the back button.

## 18.0.0

- Show song details in the system tray.
- Removes top text from home page.
- Updated description.
- Updated version.
- Updated system tray package.
- Remove the scroll bar form the sidebar on desktop.
- Fix the lyric service not working from non yt music servers.
- Polished the lyrics display UI.
- Click on album art to open the full screen player.
- Polish the add to playlist screen.
- Opening the queue will open to the current song playing.
- New window controller for desktop (linux, macos, windows).
- Polished sidebar design for desktop.
- Polished playing bar design for desktop.
- Fix the downloads button like being a differnt scale and size and stuff from the rest of the icons.
- Updated description to "Stream music correctly."
- Updated the new version dialog design.
- Remove wasted space in the home screen.
- Remove the hover message on the sidebar.

## 17.0.0

- Fix macOS youtube music playback
- Set a smaller default window size for macOS
- fix add to playlist window not matching the theme of the app

## 16.2.0

- Navbar design tweaks
- Skeleton refactor for pages up to 50% faster in some pages
- New animations for changing pages
- Fixed the universal back button on subpages in the settings screen
- Search bar now supports themeing
- Fixed downloads screen
- Fixed songs and artists pages from loading
- Premade playlists now repsond to themes
- Span custom art

## 16.1.0

- en_AU patches
- Fix album art animations
- Fix Animations not being smooth
- Removed getX
- Fixed andriod back buttons on some sub pages.

## 16.0.0

- Brand new app
- Everything has been rewritten to just work. We are done with bugs and unimplamented features

## 15.1.0

- fixed nav bar

## 15.0.0

### Highlights

- **YouTube Music**: New provider (select in Server type). Search and stream without login. Home shows Harmony-style layout with Quick picks, Popular playlists, Trending; search shows Artists, Playlists, Songs.
- **General options** (Settings > General): Toggles for Lyrics, Downloads, Volume on player bar, Queue button, Shuffle & repeat (desktop). YouTube Music can be re-enabled on Windows/Linux (off by default on desktop).
- **Onboarding**: Language → Theme (System/Light/Dark/OLED) → Accent colour → Get Started. Localized (English, 中文, Русский). When not logged in: welcome message and no-server screen after Get Started.
- **Multi-server**: Add, edit, remove, switch saved servers without reload. Settings > Server lists saved servers; legacy single-server prefs migrate on first load.
- **Detail headers**: Gradient derived from cover image (dominant color, darkened). Fades in over 280ms; no flicker. Shuffle/Play are circular icon-only; Shuffle in horizontal scroll on narrow panels.
- **Artist/album/playlist**: Clickable artist names (no underline) open artist page when in library. Albums/Songs tab is animated segmented control (purple pill, 220ms). Tab bar full width, equal segments.
- **Now playing**: Single responsive screen (mobile & desktop, breakpoint 900px). Compact: carousel, progress, controls, queue/favorite/lyrics/more. Expanded: album + controls left, Up Next / Lyrics right. Download in more-options: start, cancel, or delete download. Volume control. Close button clears queue and stops playback.
- **Now playing polish (release pass)**:
  - Desktop uses blurred artwork background and improved spacing for smaller heights.
  - Play/pause visual treatment unified (no gradient orb styling).
  - Volume controls support keyboard shortcuts and toggle-style panels.
  - Queue and lyrics panels now hide/show contextually based on availability.
- **YouTube Music follow-based home**:
  - Home supports followed content and guidance when library is empty.
  - Follow actions for artist/album/playlist with per-server persistence.
  - Mix-style playlists are excluded from follow surfaces.
- **Search**: Full-width bar. Shows albums, artists, songs for all providers; YouTube Music also shows community playlists. Server URL validation rejects YouTube Music with clear message.
- **Dates**: Year/month/day (e.g. 2025/02/21) for album Added, Settings build date, log names.

### Design & UI

- **Organic refined** look: AppTokens (Plus Jakarta Sans + Nunito, teal accent, warm dark palette, soft radii). Same tokens on desktop and mobile; light, dark, OLED.
- **OLED**: Pure black (#000000) everywhere when OLED theme selected. Dark mode uses charcoal (#1C1C1E).
- **Gemini-style**: Dark palette (#0a0a0c page, #0e0e11 sidebar, etc.). Sidebar: purple logo box, rounded nav tiles, Library label, Settings at bottom. Settings sidebar: section headers, rounded cards, status (e.g. Connected).
- **Dialogs**: Apple-style frosted glass (blur, rounded corners, scale/fade). showAppDialog / showAppConfirmDialog / showAppChoiceDialog (Apple* deprecated). Select Language, Theme, accent/custom color redesigned.
- **Mobile**: extendBody so content under nav/player bars; bars use frosted glass. Bottom padding so content not covered by nav bar.
- **Empty states**: Full-width centered icon and text. Home: no header; content starts with quick access and sections.
- **Settings**: iOS-style grouped list (Server, Playback, Appearance, About), sub-pages. Connection shows Jellyfin username (User.Name) or "Logged in". Connection box adapts by provider (Local, YouTube Music, Jellyfin/Plex/Subsonic).
- **Queue/lyrics overlays**:
  - Current track is pinned at the top of queue presentations.
  - Lyrics open at the current playback position.
  - Lyrics tabs/buttons are hidden when lyrics are unavailable.

### Fixes

- **Queue**: Clear queue also clears current track and emits null so player bar hides.
- **Layout**: Mobile nav no longer overflows on resize (Expanded + FittedBox). KeyedSubtree on breakpoint switch avoids _elements.contains assertion.
- **Dialogs**: showAppleDialog (and Add/Edit server) use actionsBuilder so Navigator.pop uses dialog context—fixes "Looking up a deactivated widget's ancestor" when caller screen already closed.
- **Search**: Bar no longer Expanded inside PageTemplate (layout crash); use fixed width (320px).
- **Server settings**: Subsonic/Navidrome config data shown via displayServerUrl and displayUsername on login/restore.
- **Now playing**: Album/artist lines under title have no underline. Lyrics: no yellow underline (TextDecoration.none).
- **Now playing**: Volume overlay no longer blocks slider drag; tapping outside closes the overlay.
- **Now playing**: Added mobile parity for The Mind Electric easter egg behavior.
- **Settings**: Reliable scrolling (AlwaysScrollableScrollPhysics, ConstrainedBox). Add/switch server no longer kicks you off Settings (shell keeps selection).

### Removed

- Android Auto, voice commands (Google Assistant, deep links, MEDIA_PLAY_FROM_SEARCH, shortcuts).
- Dynamic Isle / mini player island. Standalone Local Music screen (config in Settings only).
- Refresh buttons (Library, Albums, Artists, Playlists, Tracks, detail, Rescan). Login screen (main shell always; Connect/Disconnect in Settings).
- Unused: cached_image.dart, apple_design/glassmorphism.dart. General settings section (OLED/Show album art moved to Theme dialog). Mobile-only UI.

### Linux

- YouTube Music disabled in Server type and saved list by default; if current server was YT Music on startup, app switches or disconnects.
- YouTube Music playback: media_kit (mpv), setlocale(LC_NUMERIC, "C") before mpv to avoid "Non-C locale" crash. Fallback: ~/.config/mpv/mpv.conf with ao=pulse,pipewire,alsa. Packaged .desktop uses LC_ALL=C.
- Other Linux playback: audioplayers (GStreamer). Install gstreamer, gst-plugins-base, gst-plugins-good, gst-libav.

### Refactors & performance

- **Single codebase**: One set of Dart UI for mobile and desktop; sidebar ≥768px, bottom nav on mobile. No ui/desktop vs ui/mobile split. Navigation in lib/services; theme in lib/ui/theme.
- **Dialog API**: showAppDialog, showAppConfirmDialog, showAppChoiceDialog, AppDialogOption. Theme/layout in app_tokens.dart, desktop_theme.dart.
- **Startup**: System info logging after first frame. Isolates for dominant color, cache/API JSON (Jellyfin, local). List keys, lazy tab loading, Selector for playlists/artists/albums. Now playing: AnimatedBuilder for skip/snap-back (no setState per tick); blur limited to header.
- **YouTube Music**: Prefer 96–160 kbps stream; position-based completion fallback on mobile for auto-play/next.
- **Lint**: mounted checks after async (media_details, settings_page); braces in now_playing lyrics.
- **Cleanup**: Add-to-playlist consolidated (Create New Playlist in DesktopLayout; used from now-playing and home). ArtistDetailScreen vs ArtistDetailsPage clarified. Page template title: TextDecoration.none.

## 14.0.0

- New UI for both desktop and mobile.
- Don't show desktop sidebar when on small screens.
- Remove logging.
- Expand the about Doudou section.
- Port the old navbar.
- Settings scales.
- New app layouts.
- Port the now playing screen.
- Spec bump to 14.0.0.
- Mobile track now goes left from right.
- Lyrics icon is now a microphone; only shown when lyrics are available.
- Fixed animation when reversing a song.
- Updated dependencies: dio, clipboard, vibration, file_picker.

## 13.0.0

- Spec bump to **13.0.0**.
- Complete UI rewrite with a new adaptive shell and fully replaced login/library/settings screens.
- Added platform-native app modes: Material for Android and Cupertino for iOS.
- Added shared UI section definitions for mobile and desktop, with separate layout files for each.
- Added responsive state-safe navigation so current section/search state persists when switching layouts.
- Unified theme + localization controls in the rewritten settings screen (light/dark/system and language selection).
- Removed the entire legacy `lib/UI` implementation so only the rewritten UI stack is active.
- Added top-bar shuffle controls (Shuffle All + Shuffle Favorites) and removed refresh actions from nav/header areas.
- Added Settings option to switch UI style between System, Material, and Cupertino.
- Refined Cupertino rendering for a more native iOS/macOS look by using Cupertino scaffolding and controls throughout the rewritten shell.
- Fixed multiple overflow/jank issues in cards, section headers, tiles, and now-playing controls.
- Reduced mobile navigation crowding by using compact label behavior on smaller widths.
- Simplified the mobile UI controls by reducing top-bar and per-track action clutter.
- Reduced mobile bottom navigation to core destinations only.
- Improved Home overview card scaling so it adapts cleanly across narrow and wide layouts.
- Added reusable detailed views for albums, playlists, and artists.
- Added navigation paths from tracks/cards/lists into album and artist detail views.
- Fix yellow underlined text on the arist_detailed view page.
- Fixed mobile artists page showing yellow underlined text by applying consistent text-decoration overrides.
- Fixed yellow underlied text on the playlist page.
- Fixed bug on android where the langage setting would override the app's lanage.
- No play icon on the artist page on the desktop page.
- Placeholder artist icon.
- Don't show albums on deatiled_artist page when no albums are applyable.
- Implemented updated desktop Library empty-state cards for Genres and Years to match the new design.
- Use a template for tracks on mobile.
- Made mobile bottom-nav labels always visible so section names are shown on all widths.
- Updated Cupertino mobile bottom navigation to a floating rounded style.
- Added mobile Home quick actions for Shuffle All and Shuffle Favorites.
- Added a playlist-aware track action to remove individual songs directly from a playlist.
- Made track context options open immediately on right-click/secondary-click.
- Fixed detail header content being covered by the top navigation bar on pages like playlist details.
- Updated detailed page top-bar styling to better match the liquid glass theme.
- Made detailed page album-art glow colors dynamically derive from each cover image instead of a fixed purple glow.
- Applied the same album-art-derived glow color behavior to the now-playing carousel artwork.
- Fully integrated shuffle and loop/repeat mode state handling across now-playing UI, audio handler, and queue management.
- Fixed multiple reliability gaps: local playlist operations now work in media service manager, desktop playlist play/shuffle actions are functional, queue shuffle indices stay correct after removals, and duplicate audio listeners in app state are prevented.

## 12.1.0

- Spec bump to **12.1.0**.
- Redesigned shuffle buttons on home page to better match the glass-morphism theme.
- Fixed lyrics not loading on desktop - now properly fetches and displays synced lyrics.

## 12.0.1

- Updated donate URL | https://openlyst.ink/support
- Version bump to 12.0.1
- Haptic feedback for favorite button

## 12.0.0

### Added
- Added Downloads page to desktop UI with full download management support.
- Added Download button to track context menu in desktop UI for offline listening.
- Added track options menu to desktop now playing bar with queue, playlist, album, artist, and download actions.
- Added "Check for Updates" feature to mobile and desktop settings that checks the OpenLyst API for new versions.
- Added album art carousel to mobile now playing screen with rotary-style animation; swipe or tap side albums to change tracks.

### Fixed
- Fixed "No CupertinoLocalizations found" error on mobile pages by using GlobalCupertinoLocalizations delegate.
- Fixed Windows unable to play any music by initializing JustAudioMediaKit for all desktop platforms (Windows, macOS, Linux).
- Fixed Windows local music playback by using correct `file:///` URI format for Windows paths.
- Fixed SMTC artwork loading errors on Windows when playing local music files.
- Fixed local music album covers not displaying on desktop by adding support for file:// URIs in image widgets.
- Fixed local music metadata (title, artist, album, duration) not being read from ID3 tags by adding `audiotags` package.
- Fixed local music albums with various artists creating duplicate album entries by using album artist or folder path for grouping.
- Fixed local music embedded album art not being extracted from audio files.
- Fixed desktop home page "See All" buttons and Quick Access cards not navigating to their respective pages.
- Fixed desktop play bar and now playing overlay not showing album art for local music files.
- Fixed mobile UI not displaying album art for local music files (home, playlists, queue, track lists, album/playlist detail views).
- Fixed mobile albums page showing yellow underlined text for album names and artist names.
- Fixed mobile image loading showing error state while loading local files instead of proper placeholder.
- Fixed mobile songs and favorites pages showing "BOTTOM OVERFLOWED BY 1.00 PIXELS" error by increasing item extent to match actual content height.
- Fixed mobile search saving every keystroke as a recent search; now only committed searches (submit/tap) are saved.
- Fixed adding local music on android.
- Fixed `use_build_context_synchronously` warnings in Quick Connect authentication flow.
- Fixed `use_build_context_synchronously` warning in local music settings artwork cache clearing.
- Fixed `use_build_context_synchronously` warning in settings local music scan completion.
- Fixed downloads not working for Navidrome/Subsonic servers by updating DownloadService to use MediaServiceManager for multi-platform support.
- Fixed overflow issues on Downloads page for album cards and track list actions.
- Fixed desktop volume slider UI not updating when dragging or clicking mute button.
- Fixed VR headsets loading the Android Auto UI.
- Fixed Account Information section not displaying for Navidrome, Subsonic, Plex, and Swing Music servers.
- Fixed Windows volume slider bypassing system volume mixer by disabling WASAPI exclusive mode.
- Fixed desktop light mode to apply across the UI instead of only partially updating.
- Fixed local music "Continue" button not navigating to home screen after successful login.
- Fixed Subsonic/Navidrome login not navigating to home screen after successful authentication by adding explicit navigation.
- Fixed mobile queue overlay showing yellow underlined text by adding proper Material wrapper and TextDecoration.none styles.

### Changed
- Added "Smart back" audio toggle (mobile + desktop): if over 20% into a track, first back resets to 0:00; a quick second back goes to the previous track.
- Simplified desktop settings layout to show only implemented options and clean up unused toggles.
- Removed icons from home page section headers and shuffle buttons for cleaner mobile UI.
- Removed emojis from login screen feature pills for a more professional appearance.
- **Major codebase cleanup**: Removed all debug print statements (`kDebugMode` blocks) and verbose comments from 87 dart files across the entire codebase including screens, services, providers, widgets, models, and desktop folders.
- Simplified navigation bar code structure.
- Removed unused `_debugLinuxMpv()` function (~145 lines) from main.dart.
- Dynamic Isle Player is now disabled by default.
- Moved the UI to a new folder UI.
- Refactored mobile Settings screen to use reusable components.
- Hide Downloads page/tab when using local music mode (since files are already local).
- Replaced desktop home page quick access cards (Liked Songs, All Albums, All Artists, Shuffle All) with two focused buttons: "Shuffle All" and "Shuffle Favorites".
- Removed Quick Access section from mobile library page for a cleaner layout.

### Performance
- Cached `ImageFilter.blur` instances across mobile UI to prevent GPU recomputation on every frame (liquid_glass, mini_player, library, search, favorites).
- Converted `Consumer<AppState>` to `Selector<AppState>` with `shouldRebuild` in home, library, songs, and search screens to reduce unnecessary widget rebuilds.
- Added 300ms debounce timer to search input to reduce CPU usage during typing.
- Added `itemExtent` and `cacheExtent` to `ListView.builder` widgets in home screen for smoother scrolling.
- Changed `SliverList` to `SliverFixedExtentList` with fixed item heights in songs and favorites screens for better scroll performance.
- Wrapped expensive `BackdropFilter` widgets in `RepaintBoundary` to isolate repaints.

### Removed
- Removed non-functional Google Cardboard VR player feature (entire `lib/cardboard` folder and related settings).
- Removed non-functional audio settings: Normalize Volume, Gapless Playback, and Autoplay.
- Removed Swing Music support.
- Removed non-functional Collections and Genres sections from mobile library view.

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
- Added favorite button to the desktop fullscreen Now Playing overlay.
- Added favorite button to the desktop player bar.
- Added Easter Egg: Desktop Now Playing view flips horizontally when "The Mind Electric" plays its reversed section (before 2:50).

### Changed

- Refactored audio system from 4 platform-specific handlers (~4,200 lines) into a single cross-platform `UnifiedAudioHandler` (~1,550 lines).
- Changed app description to "Play your music with ease".
- **Complete Desktop UI Redesign** with modern styling:
  - Reduced desktop layout code from ~4,055 lines to ~1,940 lines (52% reduction)
  - Modern sidebar with hover effects, accent color highlighting, and organized library sections
  - Sleek bottom player bar with hoverable progress bar, track info, and playback controls
  - Full-screen Now Playing overlay with blurred album art background and tabbed queue/lyrics panel
  - Keyboard shortcuts: Space for play/pause, Ctrl+Arrow for skip
- Desktop Now Playing panel tabs (Up Next, Lyrics) now share the same album art background as the main player view.
- Album, artist, and playlist detail views now render inline within the desktop layout instead of navigating to a separate page.
- Desktop sidebar is now scrollable when the window height is very small.
- Desktop player bar is now hidden when no music is playing.

### Fixed

- Removed external service references (Spotify, YouTube Music) from code comments.
- Removed implementation-specific developer notes and bash script references from service files.
- Simplified verbose doc comments in UI components while keeping section headers.
- Fixed squished artist cards on desktop by implementing responsive grid (2-8 columns based on width).
- Fixed "RenderAspectRatio has unbounded constraints" crash in desktop search results.
- Fixed mounted check issues causing setState calls after widget disposal in hover callbacks.
- Fixed Now Playing overlay not updating when the current song changes.
- Fixed "BOTTOM OVERFLOWED BY X PIXELS" error on desktop album cards.
- Fixed sidebar overflowing when window is resized very short vertically.
- Fixed detail pages staying open when clicking a different sidebar item.
- Fixed Subsonic library only loading 500 tracks (now uses `search3` pagination to fetch complete library).
- Fixed macOS build failure caused by `audiotags` package linking errors (undefined symbols for x86_64).
- Removed discontinued packages (`touch_bar`, `palette_generator`) and updated `file_picker`/`device_info_plus` to latest versions.

## 10.0.0

### Added

- Added swipe left/right gesture on the mini player to skip to next or previous songs.
- Added API key authentication for Jellyfin (X-Emby-Token) as an alternative to username/password login.
- Login screen now shows a toggle between "Account" and "API Key" auth methods for Jellyfin.
- Added MarqueeText widget for auto-scrolling text display.
- Added iOS-style haptic feedback when tapping navbar buttons.
- Added Developer Website button in Settings to open the Openlyst website.
- Added Quick Connect support for Jellyfin - login by entering a code displayed in your Jellyfin server dashboard.
- Added new `DesktopTheme` system with modern liquid glass styling for desktop.
- Added reusable desktop components: `DesktopGlassContainer`, `DesktopPlayButton`, `DesktopIconButton`, `DesktopNavItem`, `DesktopProgressSlider`, `DesktopGlassButton`.
- Added "Add to Playlist" button in desktop Now Playing screen to quickly add the current track to any playlist.
- Added new music card components: `MusicCard`, `MusicListTile`, `FeaturedMusicCard`, `QuickAccessCard` with hover effects and glow.
- **Local Music Support** - Play music directly from local filesystem directories without a media server.
- Added `LocalMusicService` for scanning and playing local audio files (MP3, FLAC, WAV, OGG, M4A, AAC, WMA, OPUS, AIFF, ALAC, APE, WEBM).
- Added `AlbumArtService` for fetching album artwork from multiple sources:
  - Embedded metadata extraction using audiotags package
  - Local image files (cover.jpg, folder.png, etc.)
  - Online providers: MusicBrainz and Cover Art Archive APIs
- Added Local Music settings screen for managing music directories.
- Added artwork settings with online artwork toggle and cache management.
- **Local Playlists** - Full playlist support for local music with create, rename, delete, add/remove tracks, and reorder functionality.
- Added playlist persistence for local music using SharedPreferences.
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
- Now Playing screen title now displays on a single line with YouTube Music-style scrolling for long titles.
- Support button in Settings now opens the Communist Party of Ireland website.
- **Complete desktop UI redesign** with modern liquid glass aesthetic matching mobile styling.
- Desktop sidebar now uses frosted glass effect with gradient accent colors.
- Desktop bottom player bar redesigned with glass effect, gradient progress slider, and modern controls.
- Desktop Now Playing screen updated with album art glow effects and modern styling.
- Desktop home page updated with `QuickAccessCard` components and time-based greeting.
- Desktop page templates now support gradient headers.
- **Desktop Settings** now adapts to local music mode - shows directory management, rescan, and artwork options instead of server settings.
- **Mobile Settings** Account Information section now shows local music info (directories count, music source) when using local music.
- Settings sidebar shows "Local Music" with folder icon when in local mode instead of "Server".
- Login screen server type cards now have standardized 88x100 pixel dimensions with proper centering.
- Login screen server type section now scrolls horizontally on desktop to prevent overflow.
- `CachedImageWidget` and `CachedImage` now support local file paths (file:// URLs and absolute paths).
- Improved logout functionality to fully clear all persisted data including local music cache.
- Updated to new Openlyst url.

### Fixed

- Fixed download button not responding when tapped (download service listener not connected to AppState).
- Fixed Settings screen logout button being covered by navbar and mini player.
- Fixed account login failing after attempting API key authentication (stale X-Emby-Token header).
- Fixed album/artist cards overflowing by 4 pixels on desktop home page.
- Fixed "Callback invoked after it has been deleted" crash when changing tracks on desktop by recreating the AudioPlayer instance for each track, fully isolating native media_kit/mpv callbacks.
- Fixed track duration timestamps in desktop Now Playing "Up Next" queue showing incorrect values (was treating milliseconds as seconds).
- Fixed Subsonic track durations displaying incorrectly (Subsonic API returns seconds, now properly converted to milliseconds).
- Fixed Subsonic service skipping the 2nd song in queue.
- Fixed Subsonic favoriting not persisting (track refresh was replacing starred tracks with new random songs).
- Fixed Subsonic API implementation to spec - shuffle all and favorites now properly fetch all tracks using search3 pagination and getStarred2 endpoints instead of only loading random songs.
- Fixed local music album art not displaying (CachedNetworkImage only worked with HTTP URLs, not local file paths).
- Fixed local music cache serialization losing imageUrl paths due to Jellyfin-specific JSON format.
- Fixed Continue button not working on Local Music Settings screen during initial setup.
- Fixed server type cards overflowing on narrow desktop windows.
- Fixed desktop lyrics scrolling off-screen or going too low by adding proper clipping and scroll physics constraints.

## 9.0.0

### Changed

- Redesign the desktop style sheet.
- New search page for desktop.
- Redesigned the login page for desktop and mobile.

### Removed

- Removed downloads from the repo.

## 8.2.0

### Added
- Added support for multiple languages.
- Added support for English.
- Added support for Russian.

### Changed
- Load in either the desktop or mobile UI depending on screen size rather then system.

### Fixed
- Fixed builds expireing. So now build will no longer be broken after a week.

### Removed
- Removed big screen UI for mobile.

## 8.1.0

### Added
- Added a demo mode button to the login page.
- Added keyboard shortcuts on the now playing screen:
  - `Shift+N` - Skip to next song
  - `Space` - Play/Pause
  - `F` - Toggle favorite

### Changed
- Redesigned the now_playing screen for desktops as the theme was seen as bad by early testers.
- Preload lyrics.

### Fixed
- Fixed shuffle and repeat buttons not working on the desktop now playing screen.

## 8.0.0

The stable out.

### Added
- Added build support for Fastforge.
- Build support for **deb**, **rpm**, and **appimage**.
- Support for building OpenHarmony packages.
- Adds basic support for phoneVR headsets.

### Changed
- Changed final realse builds to have to include a ``final`` var in order to build from main branch.
- Refactored names of changelogs to markdown.
- Desktop album, playlists, and others use one template details file.
- Desktop details page now uses a fully scrollabe rather then a content template.
- Desktop now_playing is now fullscreened
- Redesigned the now_playing screen on desktop.
- Added favorites button to now_playing on desktop.
- Made the controols on the now_playing more compact.
- Build details page from top to down.
- Rewrote the the build script.
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
- User-configurable logging toggle (disabled by default for performance)
- New desktop UI
- Show the number of times songs have been played
- Plex service
- Navidrome service
- Added the ability to favorite songs
- Added debugging info for favorites
- Ability to download songs on desktop
- Use real history for the mobile search page
- Redesigned the mobile search page
- Allow custom colours for desktop accents

### Changed

- New description
- Logging is disabled by default and can be enabled in settings
- Centralized logic for API requests
- Rewrote the Jellyfin service
- Refactored most of the backend for desktop/mobile network connections
- Refactored the Jellyfin favorite song functionality
- Refactored `now_playing` to use `app_state` for favorites
- Refactored Plex service for generated URLs
- Fixed race issues when pausing music
- Redesigned mobile home page
- Redesigned mobile library page
- Complete rewrite of EVERY audio service file
- Added smooth scaling animation to desktop now playing screen opening and closing with elastic curve and opacity effects for enhanced user experience.
- Completely redesigned login screen with elegant responsive design supporting both desktop and mobile layouts. Features animated gradient backgrounds, smooth transitions, modern Material Design elements, and improved visual hierarchy for better user experience.
- Fixed mobile login screen black screen issue by adding proper MaterialApp wrapper and fixing layout constraints with appropriate scrolling behavior.
- Added minimal mobile login header with "Doudou - Welcome" text and slide-in animation for better branding while maintaining clean, focused mobile experience.
- Mobile login screen now respects phone's system theme (light/dark mode) while desktop maintains custom MaterialApp theming.
- Build realse rather the debug.
- Movies player services to thier own folder.

### Removed
- Removed crossfades
- Removed debugging for images
- Removed debugging for audio states

### Fixed
- Fixed skipping on Linux
- Improved playback diagnostics with comprehensive logging throughout the audio system
- Fixed a bug that often caused the audio player to not work when using local addresses
- Fixed local addresses often failing
- Fixed clutter in the debugging terminal
- Fixed main album art using old Jellyfin code
- Fixed switching queues breaking the audio stream
- Fixed Custom Spinlock System: Replaced 9 custom spinlock implementations with proper async Mutex system to eliminate busy-wait loops causing CPU spikes and deadlocks
- Fixed Concurrent Player Operations: Implemented AudioOperationQueue to prevent "Loading interrupted" errors from concurrent _resetPlayerStateCompletely and _tryGaplessPlayback operations
- Fixed User Intent vs Player State Desynchronization: Implemented AudioStateMachine to prevent UI showing play button while audio is paused, ensuring synchronized user intent tracking
- Fixed Concatenation Race Conditions: Added operation cancellation tokens to gapless playback operations to prevent conflicts when new audio source changes interrupt ongoing concatenating transitions
- Fixed Android Bypass Mode Race: Replaced mutable boolean flags with immutable AndroidServiceManager state machine to prevent inconsistent platform-specific behavior during AudioService errors
- Fixed Preloader Race Conditions: Implemented reference counting system in AudioPreloader to prevent cleanup of audio sources while they're being prepared or used by the player
- Fixed Queue Modification Race: Added proper mutex synchronization to all AudioQueueManager operations to prevent concurrent queue modifications during shuffle, add, remove operations
- Fixed Player Position Race: Implemented atomic position updates with debouncing and seek protection to prevent position jumps during seek operations and buffering events
- Fixed State Persistence Race: Added debouncing to state persistence calls with StatePersistenceManager to prevent file corruption during rapid state transitions
- Fixed Radio Mode Race Conditions: Implemented synchronized RadioModeStateManager to prevent radio mode UI state from becoming inconsistent with actual streaming behavior during mode transitions
- Fixed Touch Bar Race Conditions: Added synchronized TouchBarUpdateManager to prevent concurrent Touch Bar updates during rapid track changes from causing visual glitches on macOS
- Fixed Download Service Race: Implemented DownloadServiceCoordinator to prevent download operations from interfering with active audio streaming by protecting tracks during playback
- Fixed bug for forground services audio_ui's may not update causing ui state on mobile to break until tick update.
- Fixed desktop automatic track advancement failing when network timeouts occur. Added retry logic with fallback to transcoded streams and skip to next track on persistent failures to prevent silent playback stops.
- Fixed web version audio playback failing due to CORS restrictions by implementing direct download URL fallback for better browser compatibility with Jellyfin media servers.
- Fixed web version track switching playing multiple audio streams simultaneously by ensuring previous audio source is properly stopped before loading new tracks.
- Fixed web version audio controls being unresponsive by implementing immediate UI state updates with asynchronous audio operations, matching mobile and desktop handler behavior patterns.

## 6.0.0

### Added
- Added a button to reload all data from the Jellyfin server.
- Added an animation that plays when album art changes size.
- Added a background for the "Now Playing" screen.
- Automatically build `.apk` files.
- Added an indication if a song is playing locally (downloaded) or streaming.
- Added a "Shuffle Favorites" button for downloaded songs.
- Added new options to the drop-down menu on the "Now Playing" screen.
- Added a kebab menu (three dots) to the album details page with a download option.
- Enhanced the kebab menu with "Play Next," "Play Later," and "Add to Favorites" options.
- Added Android Auto support.
- Added support for the macOS platform.
- Added a new desktop sidebar.
- Added web builds.

### Changed
- Lyrics are now greyed out if none are available.
- Devices are now locked to vertical orientation.
- Album art is smaller when the song is paused.
- The entire audio backend was refactored, which should hopefully lead to fewer bugs.
- The home page was redesigned.
- The album name is now displayed as the title on the album details page.
- "Play All" was changed to "Play" on the album details page.
- The "Play" and "Shuffle" buttons are now bolded on the album details page.
- The "Download Album" button was moved to the kebab menu in the navigation bar.
- The "Now Playing" screen was completely redesigned with an improved layout and spacing.
- The mini-player will no longer show when a keyboard is open.
- The search page was completely redesigned with unified results and recent searches.
- Uses a template for the album and playlist screens.

### Removed
- The music visualizer was removed (this is not possible with the current audio provider).
- The "Now Playing" option was removed from the settings screen.
- The ability to scroll on the "Now Playing" page was removed.
- The year was removed from the album details page.

### Fixed
- Fixed synced lyrics text being hidden in some cases.
- Fixed an issue where offline mode was never set to true.
- Fixed autoplay.
- Fixed recently added albums not showing correctly.
- Fixed the gapless audio playback.
- Fixed the lyrics overlay so it automatically reloads when the track changes during playback.
- Fixed images for top results not working on the search page.
- The search page now shows clean, unified results without section headers.
- Fixed iOS being unable to play audio.
- Fixed the "Now Playing" screen overflowing when a large font size is used.
- Fixed Linux builds not properly initializing the database.

## 5.0.0

### Added
- Pop-out for tracks.
- **"Add to Queue"** button.
- **"Play Next"** button.
- Download manager.
- Ability to download playlists.
- "Play All" and "Shuffle" buttons for downloaded songs.
- Ability to download albums.
- Navigate to the album by clicking the album name in **Now Playing**.
- Navigate to the artist page by clicking the artist name in **Now Playing**.
- Offline mode that keeps users logged in and restricts functionality to downloaded content when connectivity is lost.
- **Global Search**: Search across artists, albums, songs, and playlists

### Changed
- Embedded the visualizer instead of using a separate page.
- Changed the visualizer to a bar style.
- Added a universal partial component for tracks.
- Album detail page now uses the shared track list template.
- Song page now uses the shared track list template.
- Favorites page now uses the shared track list template.
- Scaled album art for better display.
- Plays local versions of songs if already downloaded.
- Displays more privacy-conscious data for account info (less identifiable/doxxing content).
- Changed app ID to reflect new FOSS group.
- Displays subtitle as "**Album – Artist**".
- Navbar now has a glass (blurred) effect.
- Mini-player now has a glass (blurred) effect.
- Moved account information into its own file/module.
- Added scroll effect for album name and artist in Now Playing.
- Downloaded albums now reuse the existing album detail screen.
- Downloaded playlists now reuse the playlist screen.
- Moved the queue to its own .dart file.

### Removed
- Removed **Download** and **Favorite** buttons from track list views.
- Removed **Display Settings** from the Settings screen.
- Removed **Audio Quality** options from the Settings screen.
- Removed **Settings** icon from the Library screen.

### Fixed
- Fixed playback of favorites from the dedicated favorites page.
- Fixed screen breakage when overlays were active.
- Fixed background playback issues.
- Fixed the download page not displaying properly.
- Fixed downloads getting stuck at 100%.
- Fixed **Cancel Download** button functionality.
- Fixed **Redo Download** button functionality.

## 4.0.0

### Added
- Navigate to the album's page from the search page.
- Added a button to remove a playlist.
- Added the ability to rename a playlist.
- Added function to normalise audio.
- Added real functionality to the favourite button on the playing screen.

### Changed
- Show the mini-player on the playlist screen.
- Display the mini-player on the songs page.
- Music visualiser now uses the colours from the album art.

### Fixed
- Fixed playlist screen not showing tracks.
- Fixed next song playing when not open.
