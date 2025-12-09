# 🎵 Doudou

**Your personal music player that puts privacy first.**

Stream your music collection from your own media server with a beautiful, modern interface that works on all your devices. No tracking, no ads, no cloud services - just your music.

<div align="center">

![Platform Support](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Linux%20%7C%20Windows-blue)
![License](https://img.shields.io/badge/License-GPL--3.0-green)
![Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B?logo=flutter)
![Jellyfin](https://img.shields.io/badge/Jellyfin-00A4DC?logo=jellyfin)
![Plex](https://img.shields.io/badge/Plex-E5A00D?logo=plex)
![Navidrome](https://img.shields.io/badge/Navidrome-663399)

</div>

> **Quick Start**: Download for your platform → Connect to your server → Start listening to your music!

## 📱 Works with Your Media Server

- **🟢 Jellyfin** - Full support (recommended)
- **🟢 Plex** - Working with limitations*
- **🟢 Navidrome** - Full SubSonic compatibility

*Plex support is functional, but some API calls are not implemented or are bugged.

## ✨ Why Choose Doudou?

### 🔒 **Privacy Focused**
- **Zero tracking** - No data collection, analytics, or ads
- **Your music stays yours** - Everything runs on your own server
- **No cloud services** - Direct connection to your media server only

### 🎵 **Great Music Experience**
- **Beautiful interface** - Modern design that adapts to your device
- **Seamless playback** - Gapless audio with smooth crossfades
- **Smart features** - Drag-and-drop queue management and radio mode
- **High quality audio** - Supports MP3, FLAC, AAC, OGG, M4A with automatic transcoding

### 📱 **Works Everywhere**
- **All platforms** - Android, iOS, macOS, Linux, Windows
- **Car integration** - Android Auto support
- **Background playback** - Music continues while you use other apps
- **Offline listening** - Download your favorites for offline playback

## 🚀 Get Started in Minutes

### What You Need
- A media server running **Jellyfin 10.8+**, **Plex** (with Plex Pass), or **Navidrome 0.48+**
- A device running **Android 5.0+**, **iOS 12.0+**, **macOS 10.15+**, **Linux**, or **Windows 10+**
- Network connection to your media server

### Download Doudou

Choose the easiest option for your platform:

#### 📱 **Mobile & Tablets**

**Android**
- Install [RepStore](https://gitlab.com/HttpAnimations/repstore) → Search "Doudou" → Install
- Or download APK from [releases](releases.md)

**iPhone & iPad**
- Install [AltStore](https://altstore.io/)
- Add repository: `https://gitlab.com/Openlyst/repos/altstore/-/raw/main/altstore.json`
- Install Doudou from AltStore

#### 💻 **Desktop**

**macOS**
```bash
brew tap Openlyst/macos https://gitlab.com/Openlyst/repos/homebrew/macos.git
brew install --cask doudou
```

**Windows & Linux**
- Download from [GitLab Releases](https://gitlab.com/Openlyst/doudou/-/releases)

#### 🌐 **Web Version (Docker)**

For easy web deployment, use our pre-built Docker image:

```bash
# Quick start - run on port 34273
docker run -d -p 34273:34273 --name doudou-web httpanimations/doudou:latest

# Access at http://localhost:34273
```

**With Docker Compose:**
```bash
# Download docker-compose.yml from the repository
curl -O https://raw.githubusercontent.com/HttpAnimations/doudou/main/docker-compose.yml
docker-compose up -d
```

**Benefits of the web version:**
- ✅ No installation needed - runs in any modern browser
- ✅ Works on any device with a web browser
- ✅ Easy to deploy on your server alongside Jellyfin/Plex
- ✅ Automatic updates by pulling the latest Docker image

See [DOCKER.md](DOCKER.md) for detailed deployment instructions.

### Connect to Your Server

1. **Open Doudou** and tap "Add Server"
2. **Select your server type** (Jellyfin, Plex, or Navidrome)
3. **Enter your server address** (like `http://192.168.1.100:8096`)
4. **Sign in** with your username and password
5. **Start enjoying your music!**

That's it! Doudou will sync your library and you can start streaming immediately.

## 🔒 Your Privacy Matters

**We don't collect ANY data:**
- ❌ No personal information
- ❌ No listening habits or analytics  
- ❌ No crash reports or telemetry
- ❌ No ads or third-party trackers
- ❌ No cloud services or external connections

**Everything stays on your devices:**
- ✅ Server connection settings
- ✅ Your music preferences
- ✅ Downloaded songs
- ✅ Listening history and favorites
- ✅ App settings and cache

**Simple promise:** Doudou only talks to your media server. That's it.

## ❓ Frequently Asked Questions

**Q: Do I need my own server?**  
A: Yes, Doudou connects to your self-hosted Jellyfin, Plex, or Navidrome server.

**Q: Can I use this away from home?**  
A: Absolutely! As long as your server is accessible over the internet. Consider using a VPN for security.

**Q: What about offline listening?**  
A: Long-press any song, album, or playlist and select "Download for offline listening."

**Q: Is the desktop version different?**  
A: Yes! Desktop platforms get an enhanced interface optimized for larger screens and keyboard/mouse.

**Q: Which server works best?**  
A: Jellyfin offers the best experience with full feature support and it's completely free.

## 📱 App Permissions

**Android**
- Internet & network access (connect to your server)
- Background audio & wake lock (music continues playing)
- Foreground service (media controls in notification)

**iPhone & iPad**
- Network access (connect to your server)  
- Background audio (music continues playing)
- Media controls (lock screen & control center)

## 🤝 Help Make Doudou Better

Love using Doudou? Here's how you can help:

- 🐛 **Report bugs** or suggest features
- 🌍 **Translate** the app to your language
- ⭐ **Star the project** on GitLab
- 💬 **Share** with other self-hosted music fans
- 💻 **Contribute code** if you're a developer

[Report Issues](https://gitlab.com/Openlyst/doudou/issues) • [Join Discussions](https://gitlab.com/Openlyst/doudou/-/discussions)

## � Need Help?

- 🐛 [Report a Bug](https://gitlab.com/Openlyst/doudou/issues)
- 💡 [Request a Feature](https://gitlab.com/Openlyst/doudou/issues)
- 💬 [Community Discussions](https://gitlab.com/Openlyst/doudou/-/discussions)
- 📧 [Email Support](mailto:support@openlyst.com)

---

## �️ For Developers

**Building from source:**
```bash
git clone https://gitlab.com/Openlyst/doudou.git
cd doudou
flutter pub get
flutter gen-l10n
flutter run
```

**Requirements:** Flutter 3.8.0+, Dart 3.0.0+

**Build targets:** `make android`, `make ios`, `make macos`, `make linux`, `make windows`

See [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines.

## 🙏 Credits

Built with love using these incredible open-source projects:

- [Jellyfin](https://jellyfin.org/), [Plex](https://plex.tv/), [Navidrome](https://navidrome.org/) - Media servers
- [Flutter](https://flutter.dev/) - Cross-platform framework  
- [just_audio](https://pub.dev/packages/just_audio) - Audio engine
- [audio_service](https://pub.dev/packages/audio_service) - Background audio

Special thanks to the self-hosted and Flutter communities! 🎵

## 📄 License

**GPL-3.0** - Free and open source forever.

✅ Use, modify, and share freely  
✅ Source code stays open  
❌ No warranty provided  

See [LICENSE](LICENSE) for full details.

---

<div align="center">

**Made with ❤️ for self-hosted music**

[![GitLab](https://img.shields.io/badge/GitLab-FCA326?style=for-the-badge&logo=gitlab&logoColor=white)](https://gitlab.com/Openlyst/doudou)
[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)

</div>
