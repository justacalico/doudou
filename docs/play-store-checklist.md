# 🏪 Google Play Store Preparation Checklist

## ✅ Completed Items

### 1. **App Signing** ✅
- Created proper release signing configuration in `android/app/build.gradle.kts`
- Added Makefile targets for signed builds:
  - `make generate-keystore` - Create signing keystore
  - `make setup-signing` - Create environment variables script
  - `make android-signed` - Build signed APK
  - `make android-bundle` - Build App Bundle for Play Store
- Added security measures to prevent credential leaks in `.gitignore`

### 2. **Privacy Policy** ✅ 
- Created comprehensive privacy policy in `docs/privacy-policy.md`
- Clearly states NO data collection
- Addresses all required sections

### 3. **Bundle Identifier** ✅
- Changed from `com.example.doudou` to `gitlab.openlyst.doudou`
- Updated in both Android (`build.gradle.kts`) and iOS (`project.pbxproj`)
- Moved MainActivity to correct package structure

### 4. **App Store Listing** ✅
- Created detailed listing information in `docs/app-store-listing.md`
- Includes description, features, screenshots plan

### 5. **Data Safety Information** ✅
- Documented that app collects NO data
- Listed required permissions with justifications
- Created data safety template

### 6. **Terms of Service** ✅
- Basic terms created (can be enhanced)
- Covers usage, liability, and service terms

### 7. **Network Security** ✅
- Proper network security configuration
- Only allows cleartext for local/private networks
- Requires HTTPS for external connections

## 📋 Still Need to Complete

### 1. **App Icons** 🚧
- Create proper app icons for all resolutions
- Replace default Flutter launcher icons
- Files needed:
  - `android/app/src/main/res/mipmap-*/ic_launcher.png`
  - `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

### 2. **Screenshots** 📸
- Take high-quality screenshots of the app
- Multiple device sizes and orientations
- Feature highlights (login, library, player, queue)

### 3. **App Description** ✍️
- Write compelling Play Store description
- Highlight key features and privacy focus
- Include relevant keywords

### 4. **Testing** 🧪
- Test on multiple Android devices
- Test release build thoroughly
- Verify all permissions work correctly

### 5. **Error Handling** ⚠️
- Add better network error handling
- Graceful handling of server disconnections
- User-friendly error messages

## 🚀 Quick Start Guide

### For Development:
```bash
# Clone and setup
git clone [repo]
cd doudou
flutter pub get

# Build debug version
make android
```

### For Release:
```bash
# One-time setup
make generate-keystore
make setup-signing

# Edit setup-signing.sh with real passwords
nano setup-signing.sh

# Build for Play Store
source setup-signing.sh
make android-bundle
```

## 📁 File Locations

- **Privacy Policy**: `docs/privacy-policy.md`
- **Terms of Service**: `docs/terms-of-service.md`
- **App Store Listing**: `docs/app-store-listing.md`
- **Data Safety**: `docs/data-safety-info.md`
- **Build Scripts**: `Makefile`
- **Signing Config**: `android/app/build.gradle.kts`

## 🔐 Security Notes

- Never commit `setup-signing.sh` or keystore files
- Keep keystore password secure and backed up
- Use strong passwords for signing keys
- Store keystore file safely (you'll need it for app updates)

## 🎯 Next Steps

1. **Generate keystore**: `make generate-keystore`
2. **Create signing script**: `make setup-signing`
3. **Create app icons** (use icon generator tools)
4. **Take screenshots** (use emulator or real device)
5. **Test release build** thoroughly
6. **Submit to Play Store** with all required assets

---

**Status**: Ready for app icons, screenshots, and final testing before Play Store submission!
