# 🎵 Doudou - Jellyfin Music Player

A beautiful, privacy-focused music player for your personal Jellyfin media server. Enjoy your self-hosted music collection with a modern, intuitive interface across all your devices.

<div align="center">

![Platform Support](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Linux%20%7C%20Windows-blue)
![License](https://img.shields.io/badge/License-GPL--3.0-green)
![Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B?logo=flutter)
![Jellyfin](https://img.shields.io/badge/Works%20with-Jellyfin-00A4DC?logo=jellyfin)

</div>

> **Note:** Icon is planned to be updated once a new design is created. Current icon serves as a placeholder and reference.

---

## ✨ Features

### 🎵 **Music Experience**
- **Beautiful Interface** - Clean, intuitive design inspired by modern music apps
- **Advanced Audio** - Smart crossfade, volume normalization, and gapless playback
- **Queue Management** - Add, remove, and reorder tracks with drag-and-drop support
- **Smart Preloading** - Intelligent buffering of next tracks for seamless playback
- **Radio Mode** - Endless music discovery based on your listening preferences

### 🔒 **Privacy & Control**
- **Zero Data Collection** - No analytics, no tracking, no telemetry
- **Self-Hosted** - Your music stays on your server, under your control
- **Offline Capable** - Download tracks for offline listening
- **Local Caching** - Smart caching reduces server load and improves performance

### 📱 **Platform Features**
- **Cross-Platform** - Android, iOS, macOS, Linux, Windows support
- **Background Playback** - Music continues while using other apps
- **Media Controls** - Lock screen, notification, and system media controls
- **Android Auto & CarPlay** - Safe driving integration *(Android Auto ready, CarPlay coming soon)*

### 🎧 **Audio Features**
- **Multiple Audio Formats** - MP3, FLAC, AAC, OGG, M4A, and more
- **Transcoding Support** - Automatic format conversion when needed
- **Custom Audio Session** - Optimized audio handling per platform
- **Crossfade & Gapless** - Professional-grade audio transitions

## 🚀 Getting Started

### Prerequisites
- **Jellyfin Server** version 10.8 or newer
- **Device Requirements:**
  - Android 5.0+ (API level 21)
  - iOS 12.0+
  - macOS 10.15+
  - Linux (various distributions)
  - Windows 10+ *(community tested)*
- Network connection to your Jellyfin server

### Installation
1. Download from Google Play Store *(coming VERY soon)*
2. Open Doudou and enter your Jellyfin server details
3. Login with your Jellyfin credentials
4. Start enjoying your music!

## 🔒 Privacy & Data

**We collect NO data whatsoever.**
- No personal information
- No usage analytics  
- No crash reporting to external services
- No advertising or tracking
- Your music stays between you and your server

All data (server settings, preferences) stays locally on your device.

## 🛠️ Development

### Building from Source

```bash
# Clone the repository
git clone https://gitlab.com/Openlyst/doudou.git
cd doudou

# Install dependencies
flutter pub get

# Run in development
flutter run

# Build
makae android
make ios
make linux
make macos
make windows
```

### Android Release Signing

For production builds and Google Play Store:

```bash
# 1. Generate a keystore (one-time setup)
make generate-keystore

# 2. Create environment setup script
make setup-signing

# 3. Edit setup-signing.sh with your actual passwords
nano setup-signing.sh

# 4. Load environment variables
source setup-signing.sh

# 5. Build signed APK
make android-signed

# 6. Build App Bundle for Play Store
make android-bundle
```

**Environment Variables Required:**
- `KEYSTORE_PASSWORD` - Password for the keystore file
- `KEY_PASSWORD` - Password for the signing key
- `KEY_ALIAS` - Alias name for the signing key (default: 'doudou')
- `KEYSTORE_PATH` - Path to keystore file (default: 'android/app/key.jks')

**Security Note:** Never commit signing files or passwords to version control. The keystore file and setup script are automatically excluded via `.gitignore`.

### Release Preparation

For Google Play Store release preparation:

```bash
# Generate release keystore
./scripts/generate-keystore.sh

# Build app bundle for Play Store
flutter build appbundle --release
```

See [Release Checklist](docs/release-checklist.md) for complete Play Store submission guide.

## 📋 Play Store Information

### Data Safety
✅ **This app does NOT collect any user data**
- No personal information
- No financial data
- No location data  
- No device identifiers
- No usage analytics

### Permissions
- **Internet** - Connect to your Jellyfin server
- **Network State** - Check connection status
- **Wake Lock** - Keep music playing in background
- **Foreground Service** - Background audio playback

### Content Rating
- **Everyone** - No objectionable content
- Music streaming app for personal media libraries

## 🤝 Contributing

We welcome contributions! Please follow the code style and test code before commiting.

### Development Setup
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📝 Legal

- [Privacy Policy](docs/privacy-policy.md)
- [Terms of Service](docs/terms-of-service.md)
- [Data Safety Information](docs/data-safety-info.md)

## 📞 Support

- **Issues:** [GitHub Issues](https://gitlab.com/Openlyst/doudou/issues)
  
## 🙏 Acknowledgments

- [Jellyfin Project](https://jellyfin.org/) - Amazing open-source media server
- [Flutter Team](https://flutter.dev/) - Excellent mobile development framework
- [just_audio](https://pub.dev/packages/just_audio) - Reliable audio playback
- [audio_service](https://pub.dev/packages/audio_service) - Background audio support

## 📄 License

This project is licensed under the GNU License - see the [LICENSE](LICENSE) file for details.

---

**Made with ❤️ for the Jellyfin community**

*Self-hosted music, beautifully presented*
