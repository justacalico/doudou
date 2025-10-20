# 🎵 Doudou

A beautiful, privacy-focused music player for your personal media server. Stream your music collection from Jellyfin, Plex, or Navidrome with a modern interface designed for all your devices.

<div align="center">

![Platform Support](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Linux%20%7C%20Windows-blue)
![License](https://img.shields.io/badge/License-GPL--3.0-green)
![Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B?logo=flutter)
![Jellyfin](https://img.shields.io/badge/Jellyfin-00A4DC?logo=jellyfin)
![Plex](https://img.shields.io/badge/Plex-E5A00D?logo=plex)
![Navidrome](https://img.shields.io/badge/Navidrome-663399)

</div>

## 🎵 Supported Media Servers

- **🟢 Jellyfin** - Complete feature support, recommended
- **🟡 Plex** - Full streaming support with Plex Pass
- **🟢 Navidrome** - Full SubSonic API compatibility

## ✨ Features

### 🎵 Music Experience
- Beautiful, intuitive interface
- Gapless playback and crossfade
- Queue management with drag-and-drop
- Radio mode for music discovery
- Smart preloading for seamless playback

### 🔒 Privacy First
- Zero data collection or tracking
- Self-hosted - your music stays private
- Offline downloads available
- No external dependencies

### 📱 Cross-Platform
- **Desktop**: Adaptive UI for macOS, Linux, Windows
- **Mobile**: Android and iOS support
- **Car Integration**: Android Auto ready
- **Background Playback**: Continue music while multitasking

### 🎧 Audio Quality
- Multiple formats: MP3, FLAC, AAC, OGG, M4A
- Automatic transcoding when needed
- Volume normalization
- Professional audio transitions

## 🚀 Getting Started

### Requirements
- **Media Server**: Jellyfin 10.8+, Plex (with Plex Pass), or Navidrome 0.48+
- **Platform**: Android 5.0+, iOS 12.0+, macOS 10.15+, Linux, or Windows 10+
- Network access to your media server

### Installation

#### Package Managers

**Android - RepStore**
1. Install [RepStore](https://gitlab.com/HttpAnimations/repstore)
2. Search for "Doudou" and install

**macOS - Homebrew**
```bash
brew tap Openlyst/macos https://gitlab.com/Openlyst/repos/homebrew/macos.git
brew install --cask doudou
```

**iOS - AltStore**
1. Install [AltStore](https://altstore.io/)
2. Add repository: `https://gitlab.com/Openlyst/repos/altstore/-/raw/main/altstore.json`
3. Install Doudou

#### Direct Downloads
- **Stable releases**: See [releases](releases.md)
- **Latest builds**: [GitLab Releases](https://gitlab.com/Openlyst/doudou/-/releases)

#### Build from Source
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

# Or use Flutter commands directly
flutter build apk              # Android APK
flutter build ios              # iOS app
flutter build macos            # macOS app
flutter build linux            # Linux executable
flutter build windows          # Windows executable
```

### Quick Setup
1. **Install** Doudou on your device
2. **Launch** the app and tap "Add Server"
3. **Choose** your server type (Jellyfin, Plex, or Navidrome)
4. **Enter** your server URL (e.g., `http://192.168.1.100:8096`)
5. **Login** with your username and password
6. **Enjoy** your music collection with an interface optimized for your device!

> **💡 Tips:** 
> - Make sure your media server is accessible from your device's network
> - Desktop users will automatically get the enhanced desktop interface
> - For remote access, consider setting up a VPN or reverse proxy

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
- Your media server (music streaming and metadata)
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
│   ├── models/          # Data models (Server APIs)
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

For production releases:

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
```

#### Required Environment Variables
| Variable | Description | Example |
|----------|-------------|---------|
| `KEYSTORE_PASSWORD` | Keystore file password | `your_keystore_password` |
| `KEY_PASSWORD` | Signing key password | `your_key_password` |  
| `KEY_ALIAS` | Key alias name | `doudou` |
| `KEYSTORE_PATH` | Keystore file path | `android/app/key.jks` |

> **🔐 Security:** Signing files and passwords are automatically excluded from version control via `.gitignore`.

## 📱 Distribution

> **📱 iOS Users:** While we don't distribute through the App Store, you can build the app from source using Xcode. See the development section for instructions.

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
| `INTERNET` | Connect to media server | Yes |
| `ACCESS_NETWORK_STATE` | Check connectivity status | Yes |
| `WAKE_LOCK` | Background audio playback | Yes |
| `FOREGROUND_SERVICE` | Media notification controls | Yes |
| `FOREGROUND_SERVICE_MEDIA_PLAYBOOK` | Audio service (Android 14+) | Yes |

#### iOS & macOS
- **Network Access** - Connect to media server
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

## � Support & Community

### Getting Help
- 🐛 **Bug Reports:** [GitLab Issues](https://gitlab.com/Openlyst/doudou/issues)
- 💬 **Discussions:** [GitLab Discussions](https://gitlab.com/Openlyst/doudou/-/discussions)
- 📧 **Direct Contact:** [Email Support](mailto:support@openlyst.com)
- 📖 **Documentation:** [Project Wiki](https://gitlab.com/Openlyst/doudou/-/wikis/home)

### Media Server Communities
- 🌐 **Jellyfin:** [jellyfin.org](https://jellyfin.org/) | [Forum](https://forum.jellyfin.org/) | [Discord](https://discord.gg/zHBxVSXdBV)
- 🌐 **Plex:** [plex.tv](https://plex.tv/) | [Community](https://forums.plex.tv/) | [Reddit](https://reddit.com/r/PleX)
- 🌐 **Navidrome:** [navidrome.org](https://navidrome.org/) | [GitHub](https://github.com/navidrome/navidrome) | [Discord](https://discord.gg/xh7j7yF)

### Frequently Asked Questions

<details>
<summary><strong>Q: Which media servers are supported?</strong></summary>
A: Doudou supports Jellyfin, Plex, and Navidrome servers. Each server type is auto-detected during setup, providing a seamless experience regardless of your choice.
</details>

<details>
<summary><strong>Q: Does this work over the internet (remote access)?</strong></summary>
A: Yes, as long as your media server is accessible from your device's network. Consider using a VPN or properly configured reverse proxy for security.
</details>

<details>
<summary><strong>Q: Why can't I see all my music?</strong></summary>
A: Check your server's library scanning and user permissions. The user account must have access to music libraries. For Plex users, ensure your Plex Pass includes music features.
</details>

<details>
<summary><strong>Q: Does the desktop version look different?</strong></summary>
A: Yes! Desktop platforms (macOS, Linux, Windows) automatically get an enhanced interface optimized for larger screens with improved navigation and layout.
</details>

<details>
<summary><strong>Q: How do I enable offline downloads?</strong></summary>
A: Long-press any track, album, or playlist and select "Download for offline listening." Downloads are stored locally on your device.
</details>

## 🙏 Acknowledgments

This project wouldn't be possible without these amazing open-source projects:

### Core Technologies
- **[Jellyfin](https://jellyfin.org/)** - Free software media system
- **[Plex](https://plex.tv/)** - Popular media server platform  
- **[Navidrome](https://navidrome.org/)** - Modern music server and streamer
- **[Flutter](https://flutter.dev/)** - Google's UI toolkit for building natively compiled applications
- **[Dart](https://dart.dev/)** - The programming language optimized for apps on multiple platforms

### Audio Libraries
- **[just_audio](https://pub.dev/packages/just_audio)** - Feature-rich audio player for Flutter
- **[audio_service](https://pub.dev/packages/audio_service)** - Background audio and system media controls  
- **[audio_session](https://pub.dev/packages/audio_session)** - Audio session management and interruption handling

### UI & Utilities
- **[provider](https://pub.dev/packages/provider)** - State management solution
- **[cached_network_image](https://pub.dev/packages/cached_network_image)** - Image caching and loading
- **[shared_preferences](https://pub.dev/packages/shared_preferences)** - Persistent key-value storage

### Community & Inspiration
- **Media Server Communities** - Jellyfin, Plex, and Navidrome for creating amazing self-hosted media ecosystems
- **Flutter Community** - For continuous improvements and plugins
- **Open Source Contributors** - Everyone who makes privacy-respecting software possible

## 📄 License

This project is licensed under the **GNU General Public License v3.0** - see the [LICENSE](LICENSE) file for complete details.

### What this means:
- ✅ **Free to use** for personal and commercial purposes
- ✅ **Free to modify** and distribute
- ✅ **Source code** must remain available
- ✅ **Derivative works** must use the same license
- ❌ **No warranty** or liability provided

---

<div align="center">

**Made with ❤️ for the Jellyfin community**

*Self-hosted music, beautifully presented*

[![GitLab](https://img.shields.io/badge/GitLab-FCA326?style=for-the-badge&logo=gitlab&logoColor=white)](https://gitlab.com/Openlyst/doudou)
[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Jellyfin](https://img.shields.io/badge/Jellyfin-00A4DC?style=for-the-badge&logo=jellyfin&logoColor=white)](https://jellyfin.org)

</div>
