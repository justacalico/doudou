# Google Play Store Deployment Guide

## Prerequisites

- Google Play Developer account ($25 one-time fee)
- App signed with upload key
- App assets (icons, screenshots, feature graphic)

## 1. Create Upload Keystore

Generate a new keystore for signing your app:

```bash
keytool -genkey -v -keystore android/upload-keystore.jks \
        -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

You'll be prompted for:
- Keystore password (save this!)
- Key password (can be same as keystore)
- Your name/organization details

## 2. Configure Signing

Edit `android/key.properties` with your keystore details:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=../upload-keystore.jks
```

**⚠️ IMPORTANT:** Never commit `key.properties` or `*.jks` files to git!

## 3. Build App Bundle

Build the release bundle for Play Store:

```bash
flutter build appbundle --release
```

The bundle will be at: `build/app/outputs/bundle/release/app-release.aab`

## 4. Required Play Store Assets

### App Icons
Already configured in `android/app/src/main/res/mipmap-*/`

### Screenshots (Required)
- Phone: 2-8 screenshots, 16:9 or 9:16 aspect ratio
  - Min: 320px, Max: 3840px on any side
- Tablet 7": 1-8 screenshots (optional but recommended)
- Tablet 10": 1-8 screenshots (optional but recommended)

### Feature Graphic (Required)
- Size: 1024 x 500 px
- PNG or JPEG, no alpha
- Used in Play Store listings

### Hi-res Icon
- Size: 512 x 512 px
- PNG with alpha (32-bit)

## 5. Play Console Setup

1. Go to [Google Play Console](https://play.google.com/console)
2. Create new app
3. Fill in app details:
   - App name: `Doudou`
   - Default language: English
   - App or game: App
   - Free or paid: Free

### Store Listing
- Short description (80 chars max): `Stream your Jellyfin music library with style`
- Full description (4000 chars max): See below
- App category: Music & Audio
- Content rating: Complete questionnaire
- Privacy policy URL: Required

### Suggested Full Description
```
Doudou is a beautiful, feature-rich music player for your Jellyfin media server.

🎵 KEY FEATURES:
• Stream your entire music library from Jellyfin
• Background playback with media controls
• Offline caching for your favorite tracks
• Beautiful, intuitive interface
• Cross-platform support (Android, iOS, Desktop)
• Android Auto support for car playback
• VR mode for Google Cardboard
• Android TV support

🎨 DESIGN:
• Material Design 3 with dynamic theming
• Dark mode support
• Album art display with blur effects
• Smooth animations and transitions

🔒 PRIVACY:
• Connects directly to your Jellyfin server
• No data collection or tracking
• Your media stays on your server

Perfect for Jellyfin users who want a dedicated, polished music experience on Android.
```

## 6. App Content Declarations

### Privacy Policy
Required for apps that:
- Access personal/sensitive data
- Handle user-generated content

Create one at: `docs/privacy-policy.md` (already exists)

### Content Rating
Complete the IARC questionnaire in Play Console

### Target Audience
- Select "18 and over" if no specific youth features
- Or complete the family policy requirements

### Data Safety
Declare what data your app collects:
- Network access (Jellyfin connection)
- Device identifiers (optional analytics)
- Audio playback

## 7. Release Tracks

### Internal Testing
- Up to 100 testers
- Immediate availability
- Good for initial testing

### Closed Testing
- Invite-only with email lists
- Requires review before changes

### Open Testing
- Anyone can join via link
- Good for public beta

### Production
- Full public release
- Requires full review

## 8. Release Checklist

- [ ] Create upload keystore
- [ ] Configure `key.properties`
- [ ] Update version in `pubspec.yaml`
- [ ] Build release bundle
- [ ] Create store listing
- [ ] Add screenshots (phone, tablet)
- [ ] Add feature graphic
- [ ] Complete content rating
- [ ] Add privacy policy URL
- [ ] Complete data safety form
- [ ] Submit for review

## 9. Version Management

Update version in `pubspec.yaml`:
```yaml
version: 8.0.0+1  # version+buildNumber
```

- `version`: Shown to users (e.g., 8.0.0)
- `buildNumber`: Must increment for each upload (e.g., 1, 2, 3...)

## 10. Troubleshooting

### Build fails with signing error
- Verify `key.properties` paths are correct
- Ensure keystore file exists at specified location

### Upload rejected for version code
- Increment the build number in `pubspec.yaml`
- Each upload must have a higher version code

### App rejected for policy violation
- Review rejection reason in Play Console
- Common issues: missing privacy policy, incorrect content rating

## Quick Commands

```bash
# Build release bundle
flutter build appbundle --release

# Build APK (for testing)
flutter build apk --release

# Analyze bundle size
flutter build appbundle --analyze-size

# List connected devices
flutter devices
```

## Useful Links

- [Play Console](https://play.google.com/console)
- [Flutter Android Deployment](https://docs.flutter.dev/deployment/android)
- [Play Store Guidelines](https://play.google.com/about/developer-content-policy/)
- [App Signing](https://developer.android.com/studio/publish/app-signing)
