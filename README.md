# 🎵 Doudou

**Your personal music player that puts privacy first.**

Stream your music collection from your own media server with a beautiful, modern interface that works on all your devices. No tracking, no ads, no cloud services - just your music.

<div align="center">

![Platform Support](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Linux%20%7C%20Windows-blue)
![License](https://img.shields.io/badge/License-GPL--3.0-green)
![Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B?logo=flutter)
![Jellyfin](https://img.shields.io/badge/Jellyfin-00A4DC?logo=jellyfin)
![Plex](https://img.shields.io/badge/Plex-E5A00D?logo=plex)
![Subsonic](https://img.shields.io/badge/Subsonic-663399)
![Local](https://img.shields.io/badge/Local%20Files-4CAF50)

</div>

> **Quick Start**: Download for your platform → Connect to your server → Start listening to your music!

## 📱 Works with Your Media Server (or Without One!)

- **🟢 Jellyfin** - Full support (recommended)
- **🟢 Plex** - Working with limitations*
- **🟢 Subsonic** - Full SubSonic API compatibility
- **🟢 Local Files** - Play music directly from your device

*Plex support is functional, but some API calls are not implemented or are bugged.

### 🎵 Local Music Support
Don't have a media server? No problem! Doudou can play music directly from your local filesystem:
- **Supported formats**: MP3, FLAC, WAV, OGG, M4A, AAC, WMA, OPUS, AIFF, ALAC, APE, WEBM
- **Album artwork**: Automatically fetches from embedded metadata, local images, or online (MusicBrainz/Cover Art Archive)
- **Local playlists**: Create and manage playlists for your local music collection
- **No server required**: Perfect for users who just want to play their music files

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
- A media server running **Jellyfin 10.8+**, **Plex** (with Plex Pass), **Subsonic-compatible server**, or **Swing Music**
- A device running **Android 5.0+**, **iOS 12.0+**, **macOS 10.15+**, **Linux**, or **Windows 10+**
- Network connection to your media server

### Download Doudou

<div align="center">

### 🌐 **[Download for All Platforms](https://openlyst.ink/apps/doudou)**

Visit our download page to get Doudou for **Android**, **iOS**, **macOS**, **Windows**, **Linux**, and **Web**.

</div>

#### 🐳 **Self-Host the Web Version**

Want to run Doudou on your own server? Use our Docker image:

```bash
docker run -d -p 34273:34273 --name doudou-web httpanimations/doudou:latest
```

See [DOCKER.md](docs/DOCKER.md) for detailed deployment instructions.

### Connect to Your Server

1. **Open Doudou** and tap "Add Server"
2. **Select your server type** (Jellyfin, Plex, or Subsonic)
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
A: Not anymore! While Doudou works great with Jellyfin, Plex, or Subsonic servers, you can also use it to play local music files directly from your device.

**Q: Can I use this away from home?**  
A: Absolutely! As long as your server is accessible over the internet. Consider using a VPN for security.

**Q: What about offline listening?**  
A: Long-press any song, album, or playlist and select "Download for offline listening."

**Q: Is the desktop version different?**  
A: Yes! Desktop platforms get an enhanced interface optimized for larger screens and keyboard/mouse.

**Q: Which server works best?**  
A: Jellyfin offers the best experience with full feature support and it's completely free.

## � Need Help?

- 🐛 [Report a Bug](https://gitlab.com/Openlyst/doudou/issues)
- 💡 [Request a Feature](https://gitlab.com/Openlyst/doudou/issues)
- 💬 [Community Discussions](https://gitlab.com/Openlyst/doudou/-/discussions)
- 📧 [Email Support](mailto:support@openlyst.com)

---


## 🙏 Credits

Built with love using these incredible open-source projects:

- [Jellyfin](https://jellyfin.org/), [Plex](https://plex.tv/), [Subsonic](http://www.subsonic.org/) - Media servers
- [Flutter](https://flutter.dev/) - Cross-platform framework  

<div align="center">

**Made with ❤️ for self-hosted music**

[![GitLab](https://img.shields.io/badge/GitLab-FCA326?style=for-the-badge&logo=gitlab&logoColor=white)](https://gitlab.com/Openlyst/doudou)
[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)

</div>
