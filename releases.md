# Releases

## Version 6.0.0

### Download Links

| Platform | Download |
|----------|----------|
| **Android** | [Download APK](https://gitlab.com/Openlyst/doudou/-/jobs/artifacts/9801d626eb5dd23eb6cdc146adc5a2f78631817f/download?job=build_release_linux) |
| **Linux** | [Download](https://gitlab.com/Openlyst/doudou/-/jobs/artifacts/9801d626eb5dd23eb6cdc146adc5a2f78631817f/download?job=build_release_linux) |
| **Web** | [Download Web App](https://gitlab.com/Openlyst/doudou/-/jobs/artifacts/9801d626eb5dd23eb6cdc146adc5a2f78631817f/download?job=build_debug_web) |
| **Windows** | [Source Code](https://gitlab.com/Openlyst/doudou/-/archive/pipeline-2070928152/doudou-pipeline-2070928152.tar.gz) |
| **macOS** | [Source Code](https://gitlab.com/Openlyst/doudou/-/archive/pipeline-2070928152/doudou-pipeline-2070928152.tar.gz) |
| **iOS** | [Source Code](https://gitlab.com/Openlyst/doudou/-/archive/pipeline-2070928152/doudou-pipeline-2070928152.tar.gz) |

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
| **Android** | *Coming soon* |
| **Linux** | *Coming soon* |
| **Web** | *Coming soon* |
| **Windows** | *Coming soon* |
| **macOS** | *Coming soon* |
| **iOS** | *Coming soon* |

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
| **Android** | *https://github.com/HttpAnimation/awdawd/releases/download/4.0.0/doudou-flutter-4.0.0-android-debug.apk* |
| **Linux** | *Coming soon* |
| **Web** | *Coming soon* |
| **Windows** | *Coming soon* |
| **macOS** | *Coming soon* |
| **iOS** | *Coming soon* |

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
| **Android** | *https://github.com/HttpAnimation/awdawd/releases/download/3.0.0/doudou-flutter-3.0.0-android-debug.apk* |
| **Linux** | *Coming soon* |
| **Web** | *Coming soon* |
| **Windows** | *Coming soon* |
| **macOS** | *Coming soon* |
| **iOS** | *Coming soon* |

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
| **Android** | *https://github.com/HttpAnimation/awdawd/releases/download/2.0.0/doudou-flutter-2.0.0-android-debug.apk* |
| **Linux** | *Coming soon* |
| **Web** | *Coming soon* |
| **Windows** | *Coming soon* |
| **macOS** | *Coming soon* |
| **iOS** | *Coming soon* |

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
| **Android** | *https://github.com/HttpAnimation/awdawd/raw/refs/heads/main/doudou-flutter-1.0.0-android.apk* |
| **Linux** | *Coming soon* |
| **Web** | *Coming soon* |
| **Windows** | *Coming soon* |
| **macOS** | *Coming soon* |
| **iOS** | *Coming soon* |

### Release Notes
- *After many months of hard work the app is finally ready for public usage. Some features are still not implemented but I am working on it*

---