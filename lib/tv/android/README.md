# Android TV UI

This directory contains the Android TV-optimized user interface for Doudou.

## Structure

```
lib/tv/android/
├── pages/
│   ├── tv_home_screen.dart      # Main TV home with categories
│   └── tv_player_screen.dart    # Full-screen now playing
├── widgets/
│   ├── tv_album_card.dart       # Album/artist cards for TV
│   └── tv_focus_border.dart     # Focus indication for D-pad navigation
└── tv_main.dart                  # TV-specific app entry point
```

## Features

### 10-Foot UI Design
- Large text and UI elements optimized for TV viewing distance
- High contrast colors for better visibility
- Simplified navigation structure

### D-Pad Navigation
- Full remote control support
- Focus management with visual indicators
- Purple highlight border on focused elements
- Smooth navigation between UI elements

### TV-Optimized Screens

#### Home Screen
- Category tabs: Recent, Albums, Artists, Playlists, Tracks
- Grid layout for album/artist browsing
- List view for tracks
- Large, readable text
- Album art with shadows and visual effects

#### Player Screen
- Full-screen now playing interface
- Large album artwork (400x400px)
- Blurred background with album art
- Large, accessible playback controls
- Progress bar with seek support
- Skip forward/backward (10s/30s)
- Remote control integration

### Leanback Launcher Support
- Android TV launcher integration
- TV banner icon
- Dedicated TV manifest with leanback feature
- Touch screen marked as not required

## Building for Android TV

### Build TV Flavor

```bash
# Build APK for TV
flutter build apk --flavor tv

# Build App Bundle for TV
flutter build appbundle --flavor tv

# Run on TV device
flutter run --flavor tv
```

### Install on Android TV

```bash
# Connect to Android TV via adb
adb connect <TV_IP_ADDRESS>:5555

# Install APK
adb install build/app/outputs/flutter-apk/app-tv-release.apk
```

## Configuration

### Flavor Configuration

The TV flavor is configured in `android/app/build.gradle.kts`:

```kotlin
productFlavors {
    create("mobile") {
        dimension = "platform"
        applicationIdSuffix = ".mobile"
        versionNameSuffix = "-mobile"
    }
    create("tv") {
        dimension = "platform"
        applicationIdSuffix = ".tv"
        versionNameSuffix = "-tv"
        minSdk = 21
    }
}
```

### TV Manifest

TV-specific manifest at `android/app/src/tv/AndroidManifest.xml` includes:

- `android.software.leanback` feature (required)
- `android.hardware.touchscreen` feature (not required)
- `LEANBACK_LAUNCHER` intent filter
- TV banner resource
- Audio service configuration

## Remote Control Support

### Supported Keys

- **D-Pad**: Navigation (up, down, left, right)
- **Center/OK**: Select/activate
- **Back**: Navigate back
- **Play/Pause**: Toggle playback
- **Skip Previous/Next**: Change tracks
- **Fast Forward/Rewind**: Seek within track

### Focus Management

The `TVFocusBorder` widget provides:
- Visual feedback when focused
- Purple border with glow effect
- Smooth focus transitions
- Accessibility support

## Design Guidelines

### Typography
- Titles: 42-48px
- Subtitles: 28px
- Body text: 20-22px
- Labels: 16-18px

### Spacing
- Padding: 32-48px for main containers
- Margins: 16-24px between elements
- Card spacing: 24px

### Colors
- Background: Pure black (#000000)
- Cards: Dark gray (#212121, #1C1C1E)
- Primary: Purple (#9C27B0, #7B1FA2)
- Text: White with various opacities
- Focus: Purple with glow

### Grid Layouts
- Albums: 4 columns
- Artists: 5 columns (circular images)
- Aspect ratios optimized for TV screens

## Platform Detection

The app detects Android TV platform by:

1. Checking build flavor configuration
2. Screen size and aspect ratio
3. Feature detection (leanback)

## Audio Service Integration

- Background playback support
- Media session for remote controls
- Notification with playback controls
- Lock screen controls

## Future Enhancements

### Planned Features

1. **Voice Search**
   - Google Assistant integration
   - Voice commands for playback control

2. **Enhanced Navigation**
   - Quick navigation shortcuts
   - Recently played section
   - Continue playing cards

3. **Settings Screen**
   - TV-optimized settings interface
   - Server management
   - Audio settings

4. **Recommendations**
   - Home screen recommendations
   - Based on listening history
   - Trending content

5. **Queue Management**
   - Visual queue on TV
   - Drag and drop reordering (with remote)
   - Queue preview

6. **Picture-in-Picture**
   - Mini player while browsing
   - Album art display

## Testing

### TV Emulator

```bash
# Create Android TV AVD
avdmanager create avd -n AndroidTV -k "system-images;android-30;google_atv;x86"

# Launch emulator
emulator -avd AndroidTV
```

### Physical Device Testing

Test on actual Android TV devices:
- Google Chromecast with Google TV
- Nvidia Shield TV
- Android TV boxes
- Smart TVs with Android TV

## Performance Considerations

- Lazy loading for large libraries
- Image caching and optimization
- Smooth scrolling with grid views
- Efficient focus management
- Background service optimization

## Dependencies

Same as main app, with focus on:
- `provider`: State management
- `audio_service`: Background playback
- `just_audio`: Audio playback
- `cached_network_image`: Image caching
