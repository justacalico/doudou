# 🚀 Google Play Store Release Checklist for Doudou

## 📋 Pre-Release Checklist

### ✅ Code & Build
- [ ] All features tested and working
- [ ] Skip-to-previous behavior implemented (restart at 20% or double-tap)
- [ ] 10-track preloading working
- [ ] Error handling for network issues implemented
- [ ] App builds successfully in release mode
- [ ] No debug code or console logs in production

### 🔐 Signing & Security
- [ ] Release keystore generated (`./scripts/generate-keystore.sh`)
- [ ] Environment variables set for keystore credentials
- [ ] Build configuration updated to use release signing
- [ ] Keystore file backed up securely
- [ ] Test release build signs correctly

### 📄 Legal & Privacy
- [ ] Privacy policy completed and hosted
- [ ] Terms of service completed and hosted
- [ ] Data safety information prepared
- [ ] Content rating questionnaire completed

### 🎨 App Store Assets
- [ ] App icon (512x512 for Play Store)
- [ ] Feature graphic (1024x500)
- [ ] Screenshots (at least 2, up to 8):
  - [ ] Login screen
  - [ ] Home/library view
  - [ ] Now playing screen
  - [ ] Queue management
  - [ ] Settings screen
- [ ] App description written
- [ ] Keywords selected

## 🏗️ Build Commands

### Generate Release Keystore
```bash
./scripts/generate-keystore.sh
```

### Set Environment Variables
```bash
export KEYSTORE_PASSWORD='your_password'
export KEY_PASSWORD='your_key_password'
export KEY_ALIAS='doudou'
export KEYSTORE_PATH='android/app/key.jks'
```

### Build Release APK
```bash
flutter build apk --release
```

### Build Release App Bundle (Recommended for Play Store)
```bash
flutter build appbundle --release
```

## 📱 Play Store Submission

### Store Listing
- [ ] App title: "Doudou - Jellyfin Music Player"
- [ ] Short description (80 chars max)
- [ ] Full description (4000 chars max)
- [ ] Screenshots uploaded (phone + tablet if available)
- [ ] Feature graphic uploaded
- [ ] App icon uploaded

### App Content
- [ ] Content rating completed
- [ ] Target audience selected
- [ ] Category: Music & Audio
- [ ] Tags/keywords added

### Privacy & Policy
- [ ] Privacy policy URL added
- [ ] Data safety form completed:
  - ✅ "This app does NOT collect any user data"
  - ✅ No data sharing with third parties
  - ✅ No advertising or analytics
- [ ] Permissions justified:
  - Internet: "Connect to your Jellyfin server"
  - Network state: "Check connection status"
  - Wake lock: "Keep music playing"
  - Foreground service: "Background audio playback"

### App Bundle
- [ ] Release AAB uploaded
- [ ] Release notes written
- [ ] Version code incremented
- [ ] Rollout percentage set (start with 20%)

## 🔄 Post-Release

### Monitoring
- [ ] Check for crashes in Play Console
- [ ] Monitor user reviews and ratings
- [ ] Verify app functionality on different devices
- [ ] Check download and installation stats

### Updates
- [ ] Plan regular updates
- [ ] Respond to user feedback
- [ ] Monitor Jellyfin compatibility
- [ ] Keep dependencies updated

## 📋 Play Store Data Safety Responses

**Personal Information:** ❌ None collected
**Financial Info:** ❌ None collected  
**Health & Fitness:** ❌ None collected
**Messages:** ❌ None collected
**Photos & Videos:** ❌ None collected
**Audio Files:** ❌ None collected (streams only)
**Files & Documents:** ❌ None collected
**Calendar:** ❌ None collected
**Contacts:** ❌ None collected
**App Activity:** ❌ None collected
**Web Browsing:** ❌ None collected
**App Performance:** ❌ None collected
**Device IDs:** ❌ None collected

**Data Security:** 
- ✅ Data encrypted in transit to Jellyfin server
- ✅ No data stored on external servers
- ✅ Local data deleted when app uninstalled

## 🎯 Success Metrics

### Launch Goals
- [ ] App approved and published
- [ ] No major crashes reported
- [ ] 4+ star average rating
- [ ] Positive user feedback
- [ ] 100+ downloads in first month

### Long-term Goals
- [ ] 1000+ downloads
- [ ] Feature requests from users
- [ ] Community contributions
- [ ] Jellyfin community recognition

---

**📞 Support Information:**
- Email: [your-email@domain.com]
- GitHub: https://github.com/[username]/doudou
- Issues: https://github.com/[username]/doudou/issues

**🔗 Important Links:**
- Privacy Policy: [your-privacy-policy-url]
- Terms of Service: [your-terms-url]
- Source Code: https://github.com/[username]/doudou
