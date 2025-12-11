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
# This command builds the app, sets the version/build number, and creates the .ipa in a default location.
# You will need an ExportOptions.plist file in your 'ios' directory for this to work smoothly.
flutter build ipa --release \
  --build-name="$VERSION_NAME" \
  --build-number="$VERSION_NUMBER"

# --- 4. Create 'dist' folder if needed and Move the IPA ---

# The flutter build ipa command creates the .ipa in 'build/ios/ipa'
BUILD_PATH="./build/ios/ipa/*.ipa"

echo "Creating folder: $DIST_DIR"
mkdir -p "$DIST_DIR"

echo "Moving IPA to $DIST_DIR with new name: $IPA_FILENAME"
# Find the .ipa file created by Flutter and rename/move it
IPA_FILE_PATH=$(find ./build/ios/ipa/ -name "*.ipa" -print -quit)

if [ -f "$IPA_FILE_PATH" ]; then
    mv "$IPA_FILE_PATH" "./$DIST_DIR/$IPA_FILENAME"
    echo "Success! IPA is here: $DIST_DIR/$IPA_FILENAME"
else
    echo "Error: Could not find the built IPA file in $BUILD_PATH"
    exit 1
fi