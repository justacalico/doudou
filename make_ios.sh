#!/bin/sh

# Stop the script if any command fails
set -e

# --- 1. Get App Info from pubspec.yaml ---

# Use grep and awk to find the 'name:' and 'version:' lines
# and pull out the values.
APP_NAME=$(grep 'name:' pubspec.yaml | head -n 1 | awk '{print $2}')
# The version is like '1.0.0+1'. We split it into name (1.0.0) and number (1).
VERSION_FULL=$(grep 'version:' pubspec.yaml | head -n 1 | awk '{print $2}')
VERSION_NAME=$(echo "$VERSION_FULL" | cut -d '+' -f 1)
VERSION_NUMBER=$(echo "$VERSION_FULL" | cut -d '+' -f 2)

# Set the name for the final .ipa file
IPA_FILENAME="${APP_NAME}_v${VERSION_NAME}_build${VERSION_NUMBER}.ipa"
DIST_DIR="dist"

echo "--- Starting IPA Build ---"
echo "App Name: $APP_NAME"
echo "Version: $VERSION_NAME"
echo "Build Number: $VERSION_NUMBER"

# --- 2. Clean and Get Packages ---
flutter clean
flutter pub get

# --- 3. Build the IPA ---
# Build without codesigning first, then sign manually
flutter build ios --release \
  --build-name="$VERSION_NAME" \
  --build-number="$VERSION_NUMBER" \
  --no-codesign

# --- 4. Sign the app bundle and create IPA ---
echo "Signing the app bundle..."

APP_PATH="./build/ios/iphoneos/Runner.app"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: Could not find the built .app at $APP_PATH"
    exit 1
fi

# Sign all frameworks and dylibs first
echo "Signing embedded frameworks and libraries..."
find "$APP_PATH" -name "*.framework" -o -name "*.dylib" | while read -r item; do
    if [ -e "$item" ]; then
        echo "Signing: $item"
        codesign --force --deep --sign - "$item"
    fi
done

# Sign any app extensions
find "$APP_PATH/PlugIns" -name "*.appex" 2>/dev/null | while read -r appex; do
    if [ -e "$appex" ]; then
        echo "Signing extension: $appex"
        codesign --force --deep --sign - "$appex"
    fi
done

# Sign the main app bundle
echo "Signing main app bundle..."
codesign --force --deep --sign - "$APP_PATH"

# Verify the signature
echo "Verifying signature..."
codesign --verify --deep --strict "$APP_PATH" && echo "Signature is valid!" || echo "Warning: Signature verification failed"

# --- 5. Create the IPA ---
echo "Creating IPA..."

# Create Payload directory structure
PAYLOAD_DIR="./build/ios/Payload"
rm -rf "$PAYLOAD_DIR"
mkdir -p "$PAYLOAD_DIR"

# Copy the signed .app to Payload
cp -r "$APP_PATH" "$PAYLOAD_DIR/"

# Create 'dist' folder if needed
echo "Creating folder: $DIST_DIR"
mkdir -p "$DIST_DIR"

# Create the IPA (it's just a zip file with .ipa extension)
cd "./build/ios"
zip -r -q "../../$DIST_DIR/$IPA_FILENAME" "Payload"
cd "../.."

# Clean up
rm -rf "$PAYLOAD_DIR"

echo "Success! Signed IPA is here: $DIST_DIR/$IPA_FILENAME"
echo "You can now install this IPA using AltStore or Sideloadly."