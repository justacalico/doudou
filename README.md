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

#### Option 1: Official Releases *(Recommended)*
- 📱 **Google Play Store** - *Coming very soon!*
- 🍎 **Apple App Store** - *In review process*
- 💻 **GitHub Releases** - Download for desktop platforms

#### Option 2: Build from Source
Perfect for developers and early adopters who want the latest features.

```bash
# Clone the repository
git clone https://gitlab.com/Openlyst/doudou.git
cd doudou

# Install dependencies
flutter pub get

# Run in development mode
flutter run

# Build for your platform
make android    # Android APK
make ios        # iOS app
make macos      # macOS app
make linux      # Linux executable
make windows    # Windows executable
```

### Quick Setup
1. **Install** Doudou on your device
2. **Launch** the app and tap "Add Server"
3. **Enter** your Jellyfin server URL (e.g., `http://192.168.1.100:8096`)
4. **Login** with your Jellyfin username and password
5. **Enjoy** your music collection!

> **💡 Tip:** Make sure your Jellyfin server is accessible from your device's network. For remote access, consider setting up a VPN or reverse proxy.

## 🔒 Privacy & Security

### **Zero Data Collection Promise**
Doudou is built with privacy as a core principle:

- ✅ **No Personal Information** collected or transmitted
- ✅ **No Usage Analytics** or behavioral tracking
- ✅ **No Crash Reports** sent to external services
- ✅ **No Advertising** or third-party trackers
- ✅ **No Cloud Dependencies** - works entirely with your server

### **What Data Stays Local**
All application data remains on your device:
- Server connection details
- User preferences and settings
- Downloaded music files
- Playback history and favorites
- Cache and temporary files

### **Network Communications**
Doudou only communicates with:
- Your Jellyfin server (music streaming and metadata)
- No other external services or APIs

> **🛡️ Your Music, Your Rules:** Complete control over your music library and listening data.

## 🛠️ Development

### Development Environment Setup

```bash
# Prerequisites
flutter --version  # Ensure Flutter 3.8.0+
dart --version     # Ensure Dart 3.0.0+

# Clone and setup
git clone https://gitlab.com/Openlyst/doudou.git
cd doudou
flutter pub get

# Run on device/emulator
flutter run --debug    # Development build
flutter run --release  # Performance testing
```

### Project Structure
```
doudou/
├── lib/
│   ├── models/          # Data models (Jellyfin API)
│   ├── providers/       # State management
│   ├── screens/         # UI screens
│   ├── services/        # Business logic
│   └── widgets/         # Reusable components
├── android/             # Android-specific code
├── ios/                 # iOS-specific code
├── macos/              # macOS-specific code
├── linux/              # Linux-specific code
├── windows/            # Windows-specific code
└── docs/               # Documentation
```

### Building Releases

#### Android
```bash
# Development APK
make android

# Signed release (requires keystore setup)
make generate-keystore  # One-time setup
make setup-signing      # Configure environment
source setup-signing.sh # Load signing credentials  
make android-signed     # Signed APK
make android-bundle     # Play Store bundle
```

#### iOS & macOS
```bash
# iOS (requires Xcode and Apple Developer account)
make ios

# macOS
make macos
```

#### Desktop Platforms
```bash
make linux    # Linux AppImage/deb
make windows   # Windows installer
```

### Android Release Signing

For Google Play Store and production releases:

```bash
# 1. Generate signing keystore (one-time setup)
make generate-keystore

# 2. Create environment configuration
make setup-signing

# 3. Edit the generated script with your passwords
nano setup-signing.sh

# 4. Load signing environment
source setup-signing.sh

# 5. Build signed release
make android-signed    # Signed APK
make android-bundle    # App Bundle for Play Store
```

#### Required Environment Variables
| Variable | Description | Example |
|----------|-------------|---------|
| `KEYSTORE_PASSWORD` | Keystore file password | `your_keystore_password` |
| `KEY_PASSWORD` | Signing key password | `your_key_password` |  
| `KEY_ALIAS` | Key alias name | `doudou` |
| `KEYSTORE_PATH` | Keystore file path | `android/app/key.jks` |

> **🔐 Security:** Signing files and passwords are automatically excluded from version control via `.gitignore`.

## 📱 Store Information

### Google Play Store
- **Status:** Preparing for launch
- **Target:** Q4 2024
- **Content Rating:** Everyone
- **Category:** Music & Audio

### Apple App Store  
- **Status:** In review process
- **Target:** Q1 2025
- **Content Rating:** 4+
- **Category:** Music

### Data Safety Declaration
✅ **No data collection or sharing**
- No personal information collected
- No financial or payment data
- No location data accessed
- No device identifiers tracked
- No app activity or performance data

### App Permissions

#### Android
| Permission | Purpose | Required |
|------------|---------|----------|
| `INTERNET` | Connect to Jellyfin server | Yes |
| `ACCESS_NETWORK_STATE` | Check connectivity status | Yes |
| `WAKE_LOCK` | Background audio playback | Yes |
| `FOREGROUND_SERVICE` | Media notification controls | Yes |
| `FOREGROUND_SERVICE_MEDIA_PLAYBOOK` | Audio service (Android 14+) | Yes |

#### iOS & macOS
- **Network Access** - Connect to Jellyfin server
- **Background Audio** - Continue playback when app is backgrounded
- **Media Controls** - Lock screen and control center integration

## 🤝 Contributing

We welcome contributions from the community! Whether it's bug fixes, new features, translations, or documentation improvements.

### Ways to Contribute
- 🐛 **Report bugs** and suggest features via Issues
- 💻 **Submit code** improvements and new features  
- 🌍 **Translate** the app to your language
- 📚 **Improve documentation** and help guides
- 🎨 **Design** UI/UX improvements and icons
- 🧪 **Test** on different devices and platforms

### Development Workflow
1. **Fork** the repository on GitLab
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Make** your changes with clear commit messages
4. **Test** your changes thoroughly
5. **Submit** a merge request with a detailed description

### Code Guidelines
- Follow [Dart style guide](https://dart.dev/guides/language/effective-dart/style)
- Add comments for complex logic
- Write tests for new features
- Ensure cross-platform compatibility
- Update documentation as needed

### Testing Checklist
Before submitting a merge request:
- ✅ App builds successfully on target platforms
- ✅ No new lint warnings or errors
- ✅ Core functionality works (login, playback, navigation)
- ✅ No performance regressions
- ✅ Responsive design on different screen sizes

> **💡 First time contributor?** Look for issues labeled `good first issue` to get started!

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
