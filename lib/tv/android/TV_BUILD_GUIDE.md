# Android TV Flavor Setup Guide

## Quick Start

### 1. Build the TV APK

```bash
# Build debug APK for TV
flutter build apk --debug --flavor tv

# Build release APK for TV
flutter build apk --release --flavor tv

# Build App Bundle for TV (for Play Store)
flutter build appbundle --release --flavor tv
```

### 2. Build Mobile APK (Default)

```bash
# Build mobile flavor
flutter build apk --release --flavor mobile
```

### 3. Run on Device/Emulator

```bash
# Run TV flavor
flutter run --flavor tv

# Run mobile flavor
flutter run --flavor mobile
```

## Android TV Setup

### Connect to Android TV Device

```bash
# Enable developer options on Android TV
# Settings > Device Preferences > About > Build (click 7 times)

# Enable ADB debugging
# Settings > Device Preferences > Developer options > USB debugging

# Connect via network ADB
adb connect <TV_IP_ADDRESS>:5555

# Verify connection
adb devices
```

### Install on TV

```bash
# Install APK
adb install build/app/outputs/flutter-apk/app-tv-release.apk

# Or push and install
adb push build/app/outputs/flutter-apk/app-tv-release.apk /sdcard/
adb shell pm install /sdcard/app-tv-release.apk
```

## Flavor Differences

### Mobile Flavor
- Application ID: `gitlab.openlyst.doudou.mobile`
- Standard mobile UI (Cupertino/Material)
- Touch-optimized interface
- Portrait and landscape support

### TV Flavor
- Application ID: `gitlab.openlyst.doudou.tv`
- 10-foot UI optimized for TV
- D-pad/remote control navigation
- Leanback launcher support
- Landscape only
- Minimum SDK 21

## Project Structure

```
android/app/
├── build.gradle.kts              # Flavor configuration
└── src/
    ├── main/                     # Shared resources
    │   ├── AndroidManifest.xml   # Mobile manifest
    │   └── res/                  # Mobile resources
    └── tv/                       # TV-specific
        ├── AndroidManifest.xml   # TV manifest with leanback
        └── res/                  # TV resources (banner, etc.)

lib/
├── main.dart                     # Mobile entry point
└── tv/
    └── android/
        ├── tv_main.dart          # TV entry point (optional)
        ├── pages/                # TV screens
        ├── widgets/              # TV components
        └── README.md             # TV UI documentation
```

## Features by Flavor

### Shared Features
- Jellyfin integration
- Audio playback
- Background service
- Media controls
- Caching

### TV-Specific Features
- Leanback launcher
- D-pad navigation
- TV-optimized layouts
- Remote control support
- Focus management
- 10-foot UI design

### Mobile-Specific Features
- Touch gestures
- Mobile-optimized layouts
- VR mode (Cardboard)
- Dynamic island player
- Portrait mode

## Testing

### Test on Emulator

```bash
# Create Android TV emulator
avdmanager create avd -n DoudouTV \
  -k "system-images;android-30;google_atv;x86" \
  -d "tv_1080p"

# Launch emulator
emulator -avd DoudouTV

# Run app
flutter run --flavor tv
```

### Test on Physical Device

Recommended devices:
- Google Chromecast with Google TV
- Nvidia Shield TV
- Xiaomi Mi Box
- Any Android TV device

## Building for Production

### Generate Signing Key

```bash
keytool -genkey -v -keystore ~/doudou-tv.keystore \
  -alias doudou-tv -keyalg RSA -keysize 2048 -validity 10000
```

### Configure Signing

Update `android/key.properties`:

```properties
storePassword=<your-store-password>
keyPassword=<your-key-password>
keyAlias=doudou-tv
storeFile=<path-to-keystore>
```

### Build Signed APK

```bash
flutter build apk --release --flavor tv
```

## Deployment

### Google Play Console

1. Create new app entry for TV version
2. Select "Android TV" as device category
3. Upload App Bundle
4. Add TV screenshots (1920x1080)
5. Add TV banner (320x180)
6. Fill TV-specific content rating
7. Publish

### Sideloading

```bash
# Share APK via file sharing service
# or
# Install directly via ADB

adb install -r build/app/outputs/flutter-apk/app-tv-release.apk
```

## Troubleshooting

### App doesn't appear in TV launcher
- Check `android.software.leanback` in manifest
- Verify `LEANBACK_LAUNCHER` intent filter
- Add TV banner resource

### Remote control not working
- Test D-pad navigation
- Check focus management
- Verify `android.hardware.touchscreen` is not required

### Build fails
```bash
# Clean build
flutter clean
cd android && ./gradlew clean
cd .. && flutter pub get

# Rebuild
flutter build apk --flavor tv
```

## Tips

- Always test on real TV hardware before release
- Use large text and UI elements (10-foot UI rule)
- Implement proper focus management
- Support all remote control keys
- Test with different screen sizes
- Optimize for limited processing power
- Use proper TV banner (320x180px)
