# Google Cardboard VR Mode

This directory contains the VR mode implementation for Doudou, optimized for Google Cardboard headsets.

## Structure

```
lib/cardboard/
├── pages/
│   └── vr_player.dart          # Main VR player screen with stereoscopic view
└── widgets/
    ├── vr_album_art.dart        # Album artwork display for VR
    ├── vr_player_controls.dart  # Playback controls optimized for VR
    └── vr_track_info.dart       # Track information display for VR
```

## Features

### Stereoscopic Display
- Side-by-side eye views for Google Cardboard
- Optimized spacing for comfortable VR viewing
- Immersive full-screen experience

### Player Controls
- Large, accessible touch targets
- Play/pause, skip previous/next controls
- Seekable progress bar with time display
- Responsive to audio playback state

### Visual Design
- Dark theme optimized for OLED screens
- Purple gradient accents matching Doudou's brand
- Glowing effects around album art and buttons
- Large, readable text for comfortable viewing distance

### System Integration
- Forces landscape orientation when in VR mode
- Hides system UI for immersive experience
- Restores normal orientation on exit
- Integrates with app's audio service

## Usage

### For Users

1. Start playing a track in Doudou
2. Go to Settings
3. Find "VR Mode" under "Player Interface" (mobile only)
4. Tap to launch VR mode
5. Insert phone into Google Cardboard headset
6. Use the exit button to return to normal mode

### For Developers

To launch VR mode programmatically:

```dart
Navigator.of(context).push(
  CupertinoPageRoute(
    builder: (context) => const VRPlayerScreen(),
    fullscreenDialog: true,
  ),
);
```

## Platform Support

- **Android**: ✅ Full support
- **iOS**: ✅ Full support
- **Web**: ❌ Not available (button hidden)
- **Desktop**: ❌ Not available (button hidden)

## Technical Implementation

### Screen Layout

The VR player uses a `Row` widget to create side-by-side views:
- Left eye view (left half of screen)
- Right eye view (right half of screen)

Both views show identical content, as basic Cardboard doesn't require true 3D rendering.

### Audio Integration

The VR player integrates directly with the app's `AppState` and `AudioServiceIntegration`:
- Listens to `mediaItem` stream for current track
- Listens to `playbackState` stream for play/pause status
- Listens to `positionStream` for progress updates
- Sends commands through audio handler (play, pause, skip, seek)

### System UI Management

```dart
// On enter VR mode
SystemChrome.setPreferredOrientations([
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
]);
SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

// On exit VR mode
SystemChrome.setPreferredOrientations([
  DeviceOrientation.portraitUp,
  DeviceOrientation.portraitDown,
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
]);
SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
```

## Future Enhancements

Possible improvements for VR mode:

1. **Gyroscope Integration**
   - Head tracking for 360° album art viewing
   - Spatial audio positioning

2. **3D Visualizations**
   - Audio spectrum analyzer in 3D space
   - Particle effects responsive to music

3. **Gesture Controls**
   - Swipe gestures for skip/seek
   - Pinch to adjust volume

4. **Queue Management**
   - View and reorder queue in VR
   - Browse library in VR mode

5. **Cardboard SDK Integration**
   - True stereoscopic 3D rendering
   - Lens distortion correction
   - Magnetic trigger support

## Dependencies

- `audio_service`: Audio playback control
- `flutter/services`: System UI and orientation management
- `provider`: State management integration

## Notes

- VR mode requires an active audio playback session
- Exit button is always visible for safety
- No track playing shows a fallback message
- Designed for comfortable extended viewing
