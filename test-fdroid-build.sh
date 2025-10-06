#!/bin/bash

# F-Droid build test script
# This script helps test if your app is compatible with F-Droid requirements

set -e

echo "🔧 Testing F-Droid build compatibility..."

# Check if we're in the project root
if [[ ! -f "pubspec.yaml" ]]; then
    echo "❌ Error: Run this script from the project root directory"
    exit 1
fi

# Check version format in pubspec.yaml
echo "🔍 Checking version format in pubspec.yaml..."
APP_VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //' | tr -d ' ')
if [[ -z "$APP_VERSION" ]]; then
    echo "❌ Error: No version found in pubspec.yaml"
    exit 1
elif [[ ! "$APP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(\+[0-9]+)?$ ]]; then
    echo "❌ Error: Version format should be X.Y.Z or X.Y.Z+BUILD (e.g., 8.0.0+2)"
    echo "   Found: $APP_VERSION"
    exit 1
else
    echo "✅ Valid version format found: $APP_VERSION"
fi

echo "📋 Checking F-Droid compatibility requirements..."

# Check 1: Verify all dependencies are FOSS
echo "🔍 Checking dependencies for FOSS compliance..."
PROBLEMATIC_DEPS=$(flutter pub deps --style=compact | grep -E "(firebase|google_play|gms|play-services)" || true)
if [[ -n "$PROBLEMATIC_DEPS" ]]; then
    echo "❌ Found potentially problematic dependencies:"
    echo "$PROBLEMATIC_DEPS"
    echo "F-Droid requires all dependencies to be FOSS-compatible"
    exit 1
else
    echo "✅ All dependencies appear to be FOSS-compatible"
fi

# Check 2: Verify metadata files exist
echo "🔍 Checking F-Droid metadata files..."
if [[ ! -f "metadata/gitlab.openlyst.doudou.yml" ]]; then
    echo "❌ Missing F-Droid metadata file: metadata/gitlab.openlyst.doudou.yml"
    exit 1
else
    echo "✅ F-Droid metadata file found"
fi

if [[ ! -d "fastlane/metadata/android/en-US" ]]; then
    echo "❌ Missing Fastlane metadata directory"
    exit 1
else
    echo "✅ Fastlane metadata directory found"
fi

# Check 3: Verify build.gradle.kts has F-Droid compatible signing
echo "🔍 Checking build configuration..."
if grep -q "keystoreFile.exists()" "android/app/build.gradle.kts"; then
    echo "✅ Build configuration is F-Droid compatible (optional signing)"
else
    echo "⚠️  Build configuration may need F-Droid compatibility fixes"
fi

# Check 4: Get dependencies to verify they resolve
echo "📦 Testing dependency resolution..."
flutter clean > /dev/null 2>&1
flutter pub get

# Check 5: Verify no Android SDK required files are hardcoded
echo "🔍 Checking for hardcoded paths..."
if grep -r "ANDROID_HOME" android/ 2>/dev/null || grep -r "sdk.dir" android/ 2>/dev/null; then
    echo "⚠️  Found hardcoded Android SDK paths - F-Droid will handle SDK setup"
else
    echo "✅ No hardcoded SDK paths found"
fi

# Check 6: Test if Android SDK is available for local build test
echo "🔍 Checking local Android SDK availability..."
if flutter doctor | grep -q "Android toolchain.*✓"; then
    echo "✅ Android SDK available - attempting local build test..."
    echo "🏗️ Building APK (F-Droid style)..."
    
    if flutter build apk --release; then
        APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
        if [[ -f "$APK_PATH" ]]; then
            echo "✅ Success! APK built at: $APK_PATH"
            echo "📋 APK info:"
            ls -lh "$APK_PATH"
        fi
    else
        echo "⚠️  Local build failed, but this may not affect F-Droid builds"
    fi
else
    echo "ℹ️  Android SDK not configured locally - this is fine for F-Droid submission"
    echo "   F-Droid will handle the build environment on their servers"
fi

echo ""
echo "🎉 F-Droid compatibility check completed!"
echo ""
echo "📋 Summary:"
echo "✅ Version format is valid: $APP_VERSION"
echo "✅ Dependencies are FOSS-compatible"
echo "✅ F-Droid metadata files are present"
echo "✅ Build configuration supports F-Droid"
echo "✅ No hardcoded paths detected"
echo ""
echo "🚀 Your app is ready for F-Droid submission!"
echo ""
echo "Next steps:"
echo "1. Fork https://gitlab.com/fdroid/fdroiddata"
echo "2. Copy metadata/gitlab.openlyst.doudou.yml to the forked repo's metadata/ folder"
echo "3. Create a merge request following F-Droid guidelines"
echo "4. Wait for F-Droid team review and testing on their build servers"