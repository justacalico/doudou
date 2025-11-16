# Google Cardboard VR Mode - 360° 3D Experience

This directory contains the full 360-degree 3D VR mode implementation for Doudou, optimized for Google Cardboard headsets with head tracking.

## Structure

```
lib/cardboard/
├── pages/
│   └── vr_player.dart              # Main VR player with 3D scene integration
├── services/
│   └── vr_scene_manager.dart       # 3D scene management and head tracking
└── widgets/
    ├── vr_3d_environment.dart      # 360° 3D environment renderer
    ├── vr_album_art.dart           # Album artwork display for VR
    ├── vr_player_controls.dart     # Playback controls optimized for VR
    └── vr_track_info.dart          # Track information display for VR
```

## Features

### 360-Degree 3D Environment
- **Full 360° panoramic view** with head tracking
- **Gyroscope integration** for real-time head movement tracking
- **Stereoscopic rendering** with proper left/right eye separation
- **3D particle system** with floating particles in space
- **Dynamic environment** that responds to head movement

### Head Tracking
- Real-time gyroscope-based head tracking
- Yaw, pitch, and roll support for full 6DOF movement
- Calibration system to recenter view
- Smooth interpolation for comfortable viewing
- Gimbal lock prevention for stable tracking

### Immersive 3D Scene
- **Space-like environment** with star field background
- **Panoramic rings** that create depth perception
- **Floating UI panels** positioned in 3D space
- **Particle effects** that move with your head
- **Dynamic lighting** with purple/cosmic theme

### Player Controls
- Toggleable overlay controls (tap to show/hide)
- Auto-hide after 5 seconds for immersion
- Large, accessible touch targets
- Play/pause, skip previous/next controls
- Seekable progress bar with time display
- Recenter view button for calibration

### Visual Design
- Deep space theme with purple accents
- Dynamic star field with varying brightness
- Glowing particle effects
- 3D-projected UI elements
- Optimized for OLED screens

### System Integration
- Forces landscape orientation when in VR mode
- Hides system UI for immersive experience
- Restores normal orientation on exit
- Real-time scene updates (60 FPS)
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
