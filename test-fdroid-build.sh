#!/bin/bash

# F-Droid build test script
# This script helps test if your app builds correctly for F-Droid

set -e

echo "🔧 Testing F-Droid build compatibility..."

# Check if we're in the project root
if [[ ! -f "pubspec.yaml" ]]; then
    echo "❌ Error: Run this script from the project root directory"
    exit 1
fi

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean
cd android && ./gradlew clean && cd ..

# Get dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Build APK without signing (F-Droid style)
echo "🏗️ Building APK (unsigned, F-Droid style)..."
cd android
./gradlew assembleRelease
cd ..

# Check if APK was created
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [[ -f "$APK_PATH" ]]; then
    echo "✅ Success! APK built at: $APK_PATH"
    echo "📋 APK info:"
    ls -lh "$APK_PATH"
else
    echo "❌ Error: APK not found at expected location"
    exit 1
fi

echo ""
echo "🎉 F-Droid build test completed successfully!"
echo "Your app should build fine on F-Droid's build servers."
echo ""
echo "Next steps:"
echo "1. Fork https://gitlab.com/fdroid/fdroiddata"
echo "2. Copy metadata/gitlab.openlyst.doudou.yml to the forked repo's metadata/ folder"
echo "3. Create a merge request"
echo "4. Wait for F-Droid team review"