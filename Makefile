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

# Android build
.PHONY: android
android: $(BUILD_DIR)
	@echo "Building Android APK for version $(VERSION)..."
	flutter build apk --release
	@echo "Copying APK to $(BUILD_DIR)/doudou-flutter-$(VERSION)-android.apk"
	cp build/app/outputs/flutter-apk/app-release.apk $(BUILD_DIR)/doudou-flutter-$(VERSION)-android.apk
	@echo "Android build complete!"

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
	@echo "  mobile     Build Android and iOS packages"
	@echo "  android    Build Android APK only"
	@echo "  ios        Build iOS IPA only"
	@echo "  desktop    Build Windows, macOS and Linux packages"
	@echo "  windows    Build Windows package only"
	@echo "  macos      Build macOS package only"
	@echo "  linux      Build Linux package only"
	@echo "  clean      Clean Flutter build directories"
	@echo "  clean-all  Clean Flutter and version build directories"
	@echo ""
	@echo "Options:"
	@echo "  VERSION    Extracted from pubspec.yaml"
	@echo ""
	@echo "Example:"
	@echo "  make android"
	@echo "  make linux"
