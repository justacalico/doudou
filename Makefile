# Doudou Flutter Build Makefile

# Extract version from pubspec.yaml
VERSION = $(shell grep 'version:' pubspec.yaml | sed -e 's/version:[^0-9]*\([0-9.]*\).*/\1/')

# Build directory (relative to project for permission reasons)
BUILD_DIR = ./builds/$(VERSION)
# Get absolute path for the build directory
ABS_BUILD_DIR = $(shell pwd)/builds/$(VERSION)

# Build targets
.PHONY: all
all: android ios

# Create build directory
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Android build (unsigned/debug)
.PHONY: android
android: $(BUILD_DIR)
	@echo "Building unsigned Android APK for version $(VERSION)..."
	@echo "Using Android SDK at: $(ANDROID_SDK_ROOT)"
	flutter config --android-sdk="$(ANDROID_SDK_ROOT)"
	flutter build apk --debug
	@echo "Copying APK to $(BUILD_DIR)/doudou-flutter-$(VERSION)-android-debug.apk"
	cp build/app/outputs/flutter-apk/app-debug.apk $(BUILD_DIR)/doudou-flutter-$(VERSION)-android-debug.apk
	@echo "Unsigned Android build complete!"

# Android release build (unsigned)
.PHONY: android-release
android-release: $(BUILD_DIR)
	@echo "Building unsigned release Android APK for version $(VERSION)..."
	@echo "Using Android SDK at: $(ANDROID_SDK_ROOT)"
	flutter config --android-sdk="$(ANDROID_SDK_ROOT)"
	flutter build apk --release --no-shrink
	@echo "Copying APK to $(BUILD_DIR)/doudou-flutter-$(VERSION)-android-release-unsigned.apk"
	cp build/app/outputs/flutter-apk/app-release.apk $(BUILD_DIR)/doudou-flutter-$(VERSION)-android-release-unsigned.apk
	@echo "Unsigned release Android build complete!"

# Android signed release build
.PHONY: android-signed
android-signed: $(BUILD_DIR)
	@echo "Building signed Android APK for version $(VERSION)..."
	@echo "Checking keystore environment variables..."
	@if [ -z "$(KEYSTORE_PASSWORD)" ]; then echo "Error: KEYSTORE_PASSWORD not set"; exit 1; fi
	@if [ -z "$(KEY_PASSWORD)" ]; then echo "Error: KEY_PASSWORD not set"; exit 1; fi
	@if [ -z "$(KEY_ALIAS)" ]; then echo "Error: KEY_ALIAS not set"; exit 1; fi
	@if [ -z "$(KEYSTORE_PATH)" ]; then echo "Error: KEYSTORE_PATH not set"; exit 1; fi
	@if [ ! -f "android/app/$(KEYSTORE_PATH)" ]; then echo "Error: Keystore file not found at android/app/$(KEYSTORE_PATH)"; exit 1; fi
	@echo "Building with keystore: $(KEYSTORE_PATH), alias: $(KEY_ALIAS)"
	flutter build apk --release \
		--dart-define=KEYSTORE_PASSWORD=$(KEYSTORE_PASSWORD) \
		--dart-define=KEY_PASSWORD=$(KEY_PASSWORD) \
		--dart-define=KEY_ALIAS=$(KEY_ALIAS) \
		--dart-define=KEYSTORE_PATH=$(KEYSTORE_PATH)
	@echo "Copying signed APK to $(BUILD_DIR)/doudou-flutter-$(VERSION)-android-signed.apk"
	cp build/app/outputs/flutter-apk/app-release.apk $(BUILD_DIR)/doudou-flutter-$(VERSION)-android-signed.apk
	@echo "Signed Android build complete!"

# Android App Bundle (for Play Store)
.PHONY: android-bundle
android-bundle: $(BUILD_DIR)
	@echo "Building Android App Bundle for version $(VERSION)..."
	@echo "Checking keystore environment variables..."
	@if [ -z "$(KEYSTORE_PASSWORD)" ]; then echo "Error: KEYSTORE_PASSWORD not set"; exit 1; fi
	@if [ -z "$(KEY_PASSWORD)" ]; then echo "Error: KEY_PASSWORD not set"; exit 1; fi
	@if [ -z "$(KEY_ALIAS)" ]; then echo "Error: KEY_ALIAS not set"; exit 1; fi
	@if [ -z "$(KEYSTORE_PATH)" ]; then echo "Error: KEYSTORE_PATH not set"; exit 1; fi
	@if [ ! -f "android/app/$(KEYSTORE_PATH)" ]; then echo "Error: Keystore file not found at android/app/$(KEYSTORE_PATH)"; exit 1; fi
	@echo "Building App Bundle with keystore: $(KEYSTORE_PATH), alias: $(KEY_ALIAS)"
	flutter build appbundle --release \
		--dart-define=KEYSTORE_PASSWORD=$(KEYSTORE_PASSWORD) \
		--dart-define=KEY_PASSWORD=$(KEY_PASSWORD) \
		--dart-define=KEY_ALIAS=$(KEY_ALIAS) \
		--dart-define=KEYSTORE_PATH=$(KEYSTORE_PATH)
	@echo "Copying App Bundle to $(BUILD_DIR)/doudou-flutter-$(VERSION)-android.aab"
	cp build/app/outputs/bundle/release/app-release.aab $(BUILD_DIR)/doudou-flutter-$(VERSION)-android.aab
	@echo "Android App Bundle build complete!"

# Generate keystore (one-time setup)
.PHONY: generate-keystore
generate-keystore:
	@echo "Generating new Android keystore..."
	@mkdir -p android/app
	@if [ -f "android/app/key.jks" ]; then echo "Keystore already exists at android/app/key.jks"; exit 1; fi
	keytool -genkey -v -keystore android/app/key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias doudou
	@echo "Keystore generated at android/app/key.jks"
	@echo ""
	@echo "Remember to export your keystore password environment variables:"
	@echo "export KEYSTORE_PASSWORD='your_password'"
	@echo "export KEY_PASSWORD='your_key_password'"
	@echo "export KEY_ALIAS='doudou'"
	@echo "export KEYSTORE_PATH='android/app/key.jks'"

# Setup environment variables script
.PHONY: setup-signing
setup-signing:
	@echo "Creating setup script for Android signing..."
	@echo "#!/bin/bash" > setup-signing.sh
	@echo "# Android Signing Environment Variables Setup" >> setup-signing.sh
	@echo "# Edit the values below and run: source setup-signing.sh" >> setup-signing.sh
	@echo "" >> setup-signing.sh
	@echo "export KEYSTORE_PASSWORD='your_keystore_password_here'" >> setup-signing.sh
	@echo "export KEY_PASSWORD='your_key_password_here'" >> setup-signing.sh
	@echo "export KEY_ALIAS='doudou'" >> setup-signing.sh
	@echo "export KEYSTORE_PATH='android/app/key.jks'" >> setup-signing.sh
	@echo "" >> setup-signing.sh
	@echo "echo 'Android signing environment variables set!'" >> setup-signing.sh
	@echo "echo 'KEYSTORE_PATH: \$$KEYSTORE_PATH'" >> setup-signing.sh
	@echo "echo 'KEY_ALIAS: \$$KEY_ALIAS'" >> setup-signing.sh
	@chmod +x setup-signing.sh
	@echo "Setup script created: setup-signing.sh"
	@echo ""
	@echo "To use:"
	@echo "1. Edit setup-signing.sh with your actual passwords"
	@echo "2. Run: source setup-signing.sh"
	@echo "3. Run: make android-signed"

# iOS build
.PHONY: ios
ios: $(BUILD_DIR)
	@echo "Building iOS app for version $(VERSION)..."
	flutter build ios --release --no-codesign
	
	@echo "Creating IPA package..."
	# Create temporary Payload directory
	mkdir -p $(BUILD_DIR)/Payload
	
	# Copy .app bundle to Payload directory
	cp -R build/ios/iphoneos/Runner.app $(BUILD_DIR)/Payload/
	
	# Create zip (IPA) file from Payload
	cd $(BUILD_DIR) && zip -r doudou-flutter-$(VERSION)-ios.ipa Payload
	
	# Clean up temporary Payload directory
	rm -rf $(BUILD_DIR)/Payload
	
	@echo "iOS build complete!"

# Windows build
.PHONY: windows
windows: $(BUILD_DIR)
	@echo "Building Windows app for version $(VERSION)..."
	flutter build windows --release
	@echo "Creating zip archive for Windows..."
	cd build/windows/x64/runner/Release && zip -r $(ABS_BUILD_DIR)/doudou-flutter-$(VERSION)-windows.zip ./*
	@echo "Windows build complete!"

# macOS build
.PHONY: macos
macos: $(BUILD_DIR)
	@echo "Building macOS app for version $(VERSION)..."
	flutter build macos --release
	@echo "Creating zip archive for macOS..."
	cd build/macos/Build/Products/Release && zip -r $(ABS_BUILD_DIR)/doudou-flutter-$(VERSION)-macos.zip Doudou.app
	@echo "macOS build complete!"

# Linux build
.PHONY: linux
linux: $(BUILD_DIR)
	@echo "Building Linux app for version $(VERSION)..."
	flutter build linux --release
	@echo "Creating tarball for Linux..."
	cd build/linux/x64/release/bundle && tar -czvf $(ABS_BUILD_DIR)/doudou-flutter-$(VERSION)-linux.tar.gz ./*
	@echo "Linux build complete!"

# Mobile builds only
.PHONY: mobile
mobile: android ios
	@echo "Mobile builds complete!"

# Desktop builds only
.PHONY: desktop
desktop: windows macos linux
	@echo "Desktop builds complete!"

# Clean build
.PHONY: clean
clean:
	flutter clean
	rm -rf build/
	@echo "Cleaned Flutter build directories"

# Clean all including builds directory
.PHONY: clean-all
clean-all: clean
	rm -rf $(BUILD_DIR)
	@echo "Cleaned build directory: $(BUILD_DIR)"

# Help
.PHONY: help
help:
	@echo "Doudou Flutter Build Makefile"
	@echo ""
	@echo "Usage:"
	@echo "  make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  mobile          Build Android and iOS packages"
	@echo "  android         Build unsigned Android APK (debug)"
	@echo "  android-release Build unsigned Android APK (release)"
	@echo "  android-signed  Build signed Android APK (requires keystore env vars)"
	@echo "  android-bundle  Build Android App Bundle for Play Store (requires keystore env vars)"
	@echo "  ios             Build iOS IPA only"
	@echo "  desktop         Build Windows, macOS and Linux packages"
	@echo "  windows         Build Windows package only"
	@echo "  macos           Build macOS package only"
	@echo "  linux           Build Linux package only"
	@echo "  generate-keystore  Generate new Android keystore (one-time setup)"
	@echo "  setup-signing   Create setup script for environment variables"
	@echo "  clean           Clean Flutter build directories"
	@echo "  clean-all       Clean Flutter and version build directories"
	@echo ""
	@echo "Android Signing Environment Variables (required for signed builds):"
	@echo "  KEYSTORE_PASSWORD   Password for the keystore file"
	@echo "  KEY_PASSWORD        Password for the signing key"
	@echo "  KEY_ALIAS           Alias name for the signing key (default: doudou)"
	@echo "  KEYSTORE_PATH       Path to keystore file (default: android/app/key.jks)"
	@echo ""
	@echo "Examples:"
	@echo "  make android                    # Unsigned debug APK"
	@echo "  make android-release            # Unsigned release APK"
	@echo "  make generate-keystore          # One-time keystore setup"
	@echo "  make setup-signing              # Create environment setup script"
	@echo "  # Edit setup-signing.sh, then:"
	@echo "  source setup-signing.sh         # Load environment variables"
	@echo "  make android-signed             # Production signed APK"
	@echo "  make android-bundle             # App Bundle for Play Store"
