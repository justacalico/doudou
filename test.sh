#!/bin/bash

# Android Gradle Plugin Version Fix Script
# This script fixes common AGP version issues in Flutter projects

echo "🔍 Checking Android Gradle Plugin version in your Flutter project..."

# Check if we're in a Flutter project
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: Not in a Flutter project directory (no pubspec.yaml found)"
    exit 1
fi

if [ ! -d "android" ]; then
    echo "❌ Error: No android directory found"
    exit 1
fi

echo "✅ Flutter project detected"

# Function to check and fix AGP version in files
fix_agp_version() {
    local file="$1"
    local working_version="8.7.0"  # Known working version as of September 2024
    
    if [ -f "$file" ]; then
        echo "📝 Checking $file..."
        
        # Check current version
        if grep -q "com.android.application.*8\.7\.3" "$file"; then
            echo "🔧 Found AGP 8.7.3 in $file, replacing with $working_version..."
            # Backup original file
            cp "$file" "$file.backup.$(date +%s)"
            
            # Replace problematic versions
            sed -i.tmp "s/com\.android\.application.*version.*['\"]8\.7\.3['\"]/ id(\"com.android.application\") version \"$working_version\"/g" "$file"
            sed -i.tmp "s/com\.android\.library.*version.*['\"]8\.7\.3['\"]/ id(\"com.android.library\") version \"$working_version\"/g" "$file"
            
            echo "✅ Updated $file to use AGP $working_version"
            rm "$file.tmp" 2>/dev/null || true
        else
            # Check what version is currently being used
            current_version=$(grep -o "com\.android\.application.*version.*['\"][0-9.]*['\"]" "$file" | grep -o "[0-9.]*" | head -1)
            if [ -n "$current_version" ]; then
                echo "ℹ️  Current AGP version in $file: $current_version"
                
                # Check if it's a problematic version
                case "$current_version" in
                    "8.7.3"|"8.8."*|"8.9."*|"8.10."*|"8.11."*|"8.12."*)
                        echo "⚠️  Version $current_version might not be available, consider using $working_version"
                        ;;
                    "8.7.0"|"8.6."*|"8.5."*|"8.4."*)
                        echo "✅ Version $current_version should work fine"
                        ;;
                    *)
                        echo "ℹ️  Version $current_version - please verify it's available"
                        ;;
                esac
            else
                echo "ℹ️  No AGP version found in $file"
            fi
        fi
    else
        echo "⚠️  File $file not found"
    fi
}

# Check and fix common files
echo ""
echo "🔍 Checking Android Gradle configuration files..."

# Check settings.gradle.kts (Kotlin DSL)
fix_agp_version "android/settings.gradle.kts"

# Check settings.gradle (Groovy DSL)
fix_agp_version "android/settings.gradle"

# Check app/build.gradle.kts
fix_agp_version "android/app/build.gradle.kts"

# Check app/build.gradle
fix_agp_version "android/app/build.gradle"

# Check build.gradle in root android folder
fix_agp_version "android/build.gradle"
fix_agp_version "android/build.gradle.kts"

echo ""
echo "🧹 Cleaning Android build cache..."
if [ -d "android" ]; then
    cd android
    if [ -f "gradlew" ]; then
        echo "Running gradle clean..."
        ./gradlew clean --no-daemon 2>/dev/null || echo "⚠️  Gradle clean failed (this might be expected)"
    fi
    cd ..
fi

# Clean Flutter build cache
echo "🧹 Cleaning Flutter build cache..."
flutter clean 2>/dev/null || echo "⚠️  Flutter clean failed"

echo ""
echo "📋 Summary:"
echo "1. ✅ Checked and fixed AGP version issues"
echo "2. 🧹 Cleaned build caches" 
echo "3. 💡 Next steps:"
echo "   - Run 'flutter pub get' to refresh dependencies"
echo "   - Try building with 'flutter build apk --debug'"
echo "   - If issues persist, check network connectivity to maven.google.com"
echo ""
echo "🔗 Helpful commands:"
echo "   flutter doctor -v                    # Check Flutter setup"
echo "   cd android && ./gradlew --version    # Check Gradle version"
echo "   flutter build apk --debug -v        # Build with verbose output"

echo ""
echo "✅ Script completed!"