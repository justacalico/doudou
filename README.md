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
git clone https://gitlab.com/Openlyst/doudou.git
cd doudou
flutter pub get
flutter run

# Build for specific platforms
make android    # Android APK
make ios        # iOS app  
make macos      # macOS app
make linux      # Linux app
make windows    # Windows app
```

### Setup
1. Install Doudou on your device
2. Launch and tap "Add Server"
3. Choose your server type (Jellyfin/Plex/Navidrome)
4. Enter server URL (e.g., `http://192.168.1.100:8096`)
5. Login with your credentials
6. Start streaming your music!

## 🔒 Privacy

**Zero Data Collection**
- No personal information collected
- No usage analytics or tracking
- No crash reports or telemetry
- No advertising or third-party trackers
- No cloud dependencies

**What Stays Local**
- Server connection details
- User preferences
- Downloaded music files
- Playback history and favorites
- All cache and temporary files

Doudou only communicates with your media server - no external services.

## 🛠️ Development

### Setup
```bash
# Prerequisites: Flutter 3.8.0+, Dart 3.0.0+
git clone https://gitlab.com/Openlyst/doudou.git
cd doudou
flutter pub get
flutter run
```

### Project Structure
```
lib/
├── models/      # Data models
├── providers/   # State management  
├── screens/     # UI screens
├── services/    # Business logic
└── widgets/     # Reusable components
```

### Building
```bash
# Development
make android        # Android APK
make ios           # iOS app
make macos         # macOS app
make linux         # Linux app
make windows       # Windows app

# Production (Android)
make generate-keystore  # One-time setup
make setup-signing     # Configure signing
source setup-signing.sh
make android-signed    # Signed APK
```

## 📱 Permissions

### Android
- **Internet** - Connect to media server
- **Network State** - Check connectivity 
- **Wake Lock** - Background playback
- **Foreground Service** - Media controls

### iOS/macOS
- **Network Access** - Server connection
- **Background Audio** - Continue playback
- **Media Controls** - Lock screen/control center

## 🤝 Contributing

Contributions welcome! Help improve Doudou with:
- 🐛 Bug reports and feature requests
- 💻 Code improvements and new features
- 🌍 Translations to your language
- 📚 Documentation improvements
- 🧪 Testing on different platforms

### Workflow
1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Make changes with clear commits
4. Test thoroughly
5. Submit merge request

Follow [Dart style guide](https://dart.dev/guides/language/effective-dart/style) and ensure cross-platform compatibility.

## 📞 Support

- 🐛 [Bug Reports](https://gitlab.com/Openlyst/doudou/issues)
- 💬 [Discussions](https://gitlab.com/Openlyst/doudou/-/discussions)
- 📧 [Email Support](mailto:support@openlyst.com)

### FAQ

**Q: Which servers are supported?**  
A: Jellyfin, Plex (with Plex Pass), and Navidrome are fully supported.

**Q: Can I use this remotely?**  
A: Yes, if your server is accessible over the internet. Use a VPN or reverse proxy for security.

**Q: Desktop interface different?**  
A: Yes, desktop platforms get an enhanced UI optimized for larger screens.

**Q: Offline downloads?**  
A: Long-press any item and select "Download for offline listening."

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
