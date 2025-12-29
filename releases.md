# Releases


## README
Please head to [https://openlyst.ink/apps/doudou](https://openlyst.ink/apps/doudou) for new versions.

## Version 7.0.0

### Download Links

| Platform | Download |
|----------|----------|
| **Android** | [Download APK](https://github.com/HttpAnimation/awdawd/releases/download/6.0.0/doudou-flutter-7.0.0-apk.apk) |
| **Linux** | [Download](https://gitlab.com/Openlyst/doudou/-/jobs/11902858422/artifacts/download) |
| **Web** | [Download Web App](https://gitlab.com/Openlyst/doudou/-/blob/main/docs/DOCKER.md?ref_type=heads) |
| **Windows** | [Source Code](https://gitlab.com/Openlyst/doudou/-/archive/pipeline-2128734644/doudou-pipeline-2128734644.tar.gz) |
| **macOS** | [Download Universal](https://gitlab.com/Openlyst/doudou/-/jobs/11902791895/artifacts/raw/build/doudou-release-macos.tar.gz) |
| **iOS** | [Download IPA](https://github.com/HttpAnimation/awdawd/releases/download/6.0.0/doudou-flutter-7.0.0-ios.ipa) |

### Release Notes

# 7.0.0

## Added
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

## Changed

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

## Removed
- Removed crossfades
- Removed debugging for images
- Removed debugging for audio states

## Fixed
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

## Version 6.0.0

### Download Links

| Platform | Download |
|----------|----------|
| **Android** | [Download APK](https://gitlab.com/Openlyst/doudou/-/jobs/artifacts/9801d626eb5dd23eb6cdc146adc5a2f78631817f/download?job=build_release_linux) |
| **Linux** | [Download](https://gitlab.com/Openlyst/doudou/-/jobs/artifacts/9801d626eb5dd23eb6cdc146adc5a2f78631817f/download?job=build_release_linux) |
| **Web** | [Download Web App](https://gitlab.com/Openlyst/doudou/-/jobs/artifacts/9801d626eb5dd23eb6cdc146adc5a2f78631817f/download?job=build_debug_web) |
| **Windows** | [Source Code](https://gitlab.com/Openlyst/doudou/-/archive/pipeline-2070928152/doudou-pipeline-2070928152.tar.gz) |
| **macOS** | [Download Universal](https://github.com/HttpAnimation/awdawd/releases/download/6.0.0/doudou-flutter-6.0.0-macos.zip) |
| **iOS** | [Download IPA](https://github.com/HttpAnimation/awdawd/releases/download/6.0.0/doudou-flutter-6.0.0-ios.ipa) |

### Release Notes

## Added
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

## Changed
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

## Removed
- The music visualizer was removed (this is not possible with the current audio provider).
- The "Now Playing" option was removed from the settings screen.
- The ability to scroll on the "Now Playing" page was removed.
- The year was removed from the album details page.

## Fixed
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

---

## Version 5.0.0

### Download Links

| Platform | Download |
|----------|----------|
| **Android** | [Download APK](https://github.com/HttpAnimation/awdawd/releases/download/5.0.0/doudou-flutter-5.0.0-android-debug.apk) |
| **Linux** | Not available |
| **Web** | Not available |
| **Windows** | Not available |
| **macOS** | Not available |
| **iOS** | Not available |

### Release Notes

## Added
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

## Changed
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

## Removed
- Removed **Download** and **Favorite** buttons from track list views.  
- Removed **Display Settings** from the Settings screen.  
- Removed **Audio Quality** options from the Settings screen.  
- Removed **Settings** icon from the Library screen.

## Fixed
- Fixed playback of favorites from the dedicated favorites page.  
- Fixed screen breakage when overlays were active.  
- Fixed background playback issues.  
- Fixed the download page not displaying properly.  
- Fixed downloads getting stuck at 100%.  
- Fixed **Cancel Download** button functionality.  
- Fixed **Redo Download** button functionality.

---

## Version 4.0.0

### Download Links

| Platform | Download |
|----------|----------|
| **Android** | [Download APK](https://github.com/HttpAnimation/awdawd/releases/download/4.0.0/doudou-flutter-4.0.0-android-debug.apk) |
| **Linux** | Not available |
| **Web** | Not available |
| **Windows** | Not available |
| **macOS** | Not available |
| **iOS** | Not available |

### Release Notes

## Added
- Navigate to the album's page from the search page.
- Added a button to remove a playlist.
- Added the ability to rename a playlist.
- Added function to normalise audio.
- Added real functionality to the favourite button on the playing screen.

## Changed
- Show the mini-player on the playlist screen.
- Display the mini-player on the songs page.
- Music visualiser now uses the colours from the album art.

## Fixed
- Fixed playlist screen not showing tracks.
- Fixed next song playing when not open.

---

## Version 3.0.0

### Download Links

| Platform | Download |
|----------|----------|
| **Android** | [Download APK](https://github.com/HttpAnimation/awdawd/releases/download/3.0.0/doudou-flutter-3.0.0-android-debug.apk) |
| **Linux** | Not available |
| **Web** | Not available |
| **Windows** | Not available |
| **macOS** | Not available |
| **iOS** | Not available |

### Release Notes

## Added
- Added lyrics.
- Added looping.
- Added caching to images.
- Ability to go to the album page from an artist.

## Changed
- Made the queue into a widget rather than a page.
- Updated the favorites page with the new OLED theme.
- Updated the albums page with the new OLED theme.
- Updated the theme for the artist detail page.

## Fixed
- Fixed the queue having overflow issues.
- Fixed cached songs still needing to be loaded.
- Fixed albums not loading tracks in some cases.

---

## Version 2.0.0

### Download Links

| Platform | Download |
|----------|----------|
| **Android** | [Download APK](https://github.com/HttpAnimation/awdawd/releases/download/2.0.0/doudou-flutter-2.0.0-android-debug.apk) |
| **Linux** | Not available |
| **Web** | Not available |
| **Windows** | Not available |
| **macOS** | Not available |
| **iOS** | Not available |

### Release Notes

# Added
- Visulizer for music.

# Changed
- Pages support the OLED theme much better.

# Fixed
- Home page showing the same 6-7 albums
- Bug in the new audio stream is causing the app to break.

---

## Version 1.0.0

### Download Links

| Platform | Download |
|----------|----------|
| **Android** | [Download APK](https://github.com/HttpAnimation/awdawd/raw/refs/heads/main/doudou-flutter-1.0.0-android.apk) |
| **Linux** | Not available |
| **Web** | Not available |
| **Windows** | Not available |
| **macOS** | Not available |
| **iOS** | Not available |

### Release Notes
- *After many months of hard work the app is finally ready for public usage. Some features are still not implemented but I am working on it*

---