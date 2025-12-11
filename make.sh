#!/bin/bash
# Zed Dist (make) - Build script for Doudou using FastForge
# Usage: ./make -platform [package_type]
# Examples:
#   ./make -linux appimage
#   ./make -linux deb
#   ./make -macos dmg
#   ./make -windows msix
#   ./make -android apk
#   ./make -android aab
#   ./make -ios ipa

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    echo -e "${BLUE}Zed Dist - Doudou Build Tool${NC}"
    echo ""
    echo "Usage: $0 -platform [package_type]"
    echo ""
    echo "Platforms and package types:"
    echo "  -linux       appimage, deb, rpm, zip"
    echo "  -macos       dmg, pkg, zip, app"
    echo "  -windows     msix, exe, zip"
    echo "  -android     apk, aab"
    echo "  -ios         ipa, app"
    echo "  -ohos        hap, app"
    echo ""
    echo "Examples:"
    echo "  $0 -linux appimage"
    echo "  $0 -macos dmg"
    echo "  $0 -windows msix"
    echo "  $0 -android apk"
    echo "  $0 -ios ipa"
    echo "  $0 -ohos hap"
    echo ""
    exit 1
}

# Check if fastforge is installed
check_fastforge() {
    if ! command -v fastforge &> /dev/null && ! command -v $HOME/.pub-cache/bin/fastforge &> /dev/null; then
        echo -e "${RED}Error: FastForge is not installed${NC}"
        echo "Install it with: dart pub global activate fastforge"
        exit 1
    fi
    
    # Use fastforge from PATH or from .pub-cache
    if command -v fastforge &> /dev/null; then
        FASTFORGE_CMD="fastforge"
    else
        FASTFORGE_CMD="$HOME/.pub-cache/bin/fastforge"
    fi
}

# Parse arguments
if [ $# -lt 1 ]; then
    usage
fi

PLATFORM=""
PACKAGE_TYPE=""

# Parse command line arguments
while [ $# -gt 0 ]; do
    case $1 in
        -linux)
            PLATFORM="linux"
            PACKAGE_TYPE="${2:-appimage}"
            shift
            ;;
        -macos)
            PLATFORM="macos"
            PACKAGE_TYPE="${2:-dmg}"
            shift
            ;;
        -windows)
            PLATFORM="windows"
            PACKAGE_TYPE="${2:-msix}"
            shift
            ;;
        -android)
            PLATFORM="android"
            PACKAGE_TYPE="${2:-apk}"
            shift
            ;;
        -ios)
            PLATFORM="ios"
            PACKAGE_TYPE="${2:-ipa}"
            shift
            ;;
        -ohos)
            PLATFORM="ohos"
            PACKAGE_TYPE="${2:-hap}"
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            # If it's not a flag, treat it as package type
            if [ -z "$PACKAGE_TYPE" ] && [ -n "$PLATFORM" ]; then
                PACKAGE_TYPE="$1"
            fi
            ;;
    esac
    shift
done

# Validate platform was provided
if [ -z "$PLATFORM" ]; then
    echo -e "${RED}Error: No platform specified${NC}"
    usage
fi

# Check fastforge installation
check_fastforge

# Display build info
echo -e "${BLUE}╔════════════════════════════════════╗${NC}"
echo -e "${BLUE}║    Doudou Build - Zed Dist        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Platform:${NC} $PLATFORM"
echo -e "${GREEN}Package Type:${NC} $PACKAGE_TYPE"
echo ""

# Additional build arguments for specific platforms
BUILD_ARGS=""

case $PLATFORM in
    ios)
        if [ "$PACKAGE_TYPE" = "ipa" ]; then
            # Build iOS without code signing - creates .app bundle
            echo -e "${YELLOW}Building iOS app...${NC}"
            echo ""
            
            # Run flutter build ios with 
            flutter build ios  --release
            BUILD_STATUS=$?
            
            if [ $BUILD_STATUS -eq 0 ]; then
                # Create dist directory
                mkdir -p dist
                
                # Get version from pubspec
                VERSION=$(grep '^version:' pubspec.yaml | head -n1 | sed 's/^version:[[:space:]]*//;s/["'"'"']//g' | cut -d'+' -f1)
                
                # Create an unsigned IPA from the .app bundle
                APP_PATH="build/ios/iphoneos/Runner.app"
                if [ -d "$APP_PATH" ]; then
                    echo -e "${YELLOW}Creating unsigned IPA from .app bundle...${NC}"
                    
                    # Create Payload directory structure
                    TEMP_DIR=$(mktemp -d)
                    mkdir -p "$TEMP_DIR/Payload"
                    cp -r "$APP_PATH" "$TEMP_DIR/Payload/"
                    
                    # Create the IPA (which is just a zip file)
                    IPA_NAME="doudou-${VERSION}.ipa"
                    cd "$TEMP_DIR"
                    zip -r -q "$IPA_NAME" Payload
                    cd - > /dev/null
                    mv "$TEMP_DIR/$IPA_NAME" "dist/$IPA_NAME"
                    rm -rf "$TEMP_DIR"
                    
                    echo ""
                    echo -e "${GREEN}╔════════════════════════════════════╗${NC}"
                    echo -e "${GREEN}║      Build Successful! 🎉         ║${NC}"
                    echo -e "${GREEN}╚════════════════════════════════════╝${NC}"
                    echo ""
                    echo -e "${GREEN}Output:${NC} dist/$IPA_NAME"
                    echo ""
                    echo -e "${YELLOW}Note: This is an unsigned IPA. To install on a device:${NC}"
                    echo -e "  - Use AltStore, Sideloadly, or similar tools"
                    echo -e "  - Or sign it with your own certificate"
                    exit 0
                else
                    echo -e "${RED}Error: .app bundle not found at $APP_PATH${NC}"
                    exit 1
                fi
            else
                echo ""
                echo -e "${RED}╔════════════════════════════════════╗${NC}"
                echo -e "${RED}║       Build Failed! ❌            ║${NC}"
                echo -e "${RED}╚════════════════════════════════════╝${NC}"
                exit 1
            fi
        fi
        ;;
esac

# Build command
echo -e "${YELLOW}Running FastForge...${NC}"
echo ""

BUILD_CMD="$FASTFORGE_CMD package --platform $PLATFORM --targets $PACKAGE_TYPE $BUILD_ARGS"
echo -e "${BLUE}Command:${NC} $BUILD_CMD"
echo ""

# Execute the build
# Run the build but allow a fallback for RPM layout issues (FastForge/rpmbuild mismatch)
set +e
eval $BUILD_CMD
BUILD_STATUS=$?
set -e

if [ $BUILD_STATUS -eq 0 ]; then
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║      Build Successful! 🎉         ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}Output directory:${NC} dist/"
    echo ""

    # Try to show the output files
    if [ -d "dist" ]; then
        echo -e "${GREEN}Built packages:${NC}"
        find dist -type f \( -name "*.AppImage" -o -name "*.deb" -o -name "*.rpm" -o -name "*.dmg" -o -name "*.pkg" -o -name "*.msix" -o -name "*.exe" -o -name "*.apk" -o -name "*.aab" -o -name "*.ipa" -o -name "*.zip" \) -exec ls -lh {} \; 2>/dev/null || echo "  (Run 'ls -lh dist/' to see output files)"
    fi
    exit 0
fi

# If we get here, fastforge failed. Provide a helpful retry for RPM targets.
if [ "$PLATFORM" = "linux" ] && [ "$PACKAGE_TYPE" = "rpm" ]; then
    echo -e "${YELLOW}FastForge RPM packaging failed — attempting automatic rpmbuild layout fix...${NC}"

    # Read package name/version from pubspec.yaml
    if [ -f pubspec.yaml ]; then
        NAME=$(grep '^name:' pubspec.yaml | head -n1 | sed 's/^name:[[:space:]]*//;s/["'"'"']//g')
        VERSION=$(grep '^version:' pubspec.yaml | head -n1 | sed 's/^version:[[:space:]]*//;s/["'"'"']//g')
    fi

    # Fallbacks
    NAME=${NAME:-doudou}
    VERSION=${VERSION:-}

    TOP="$(pwd)/dist/${VERSION}/${NAME}-${VERSION}-linux_rpm/rpmbuild"

    echo "Looking for rpmbuild topdir: $TOP"

    # Check if fastforge placed the bundle under BUILD/<name> instead of BUILD/<name>-<version>-build/<name>
    if [ -d "$TOP/BUILD/$NAME" ]; then
        echo "Detected build files in wrong location. Fixing spec file and retrying..."
        
        # Fix the spec file to reference parent directory where fastforge placed the files
        # The spec runs from BUILD/<name>-<version>-build/ but files are in BUILD/
        SPEC_FILE="$TOP/SPECS/${NAME}.spec"
        if [ -f "$SPEC_FILE" ]; then
            # Replace "cp -r %{name}/*" with "cp -r ../%{name}/*" to look in parent BUILD dir
            sed -i 's|cp -r %{name}/|cp -r ../%{name}/|g' "$SPEC_FILE"
            sed -i 's|cp -r %{name}\.|cp -r ../%{name}.|g' "$SPEC_FILE"
            sed -i 's|cp -r %{name}\.desktop|cp -r ../%{name}.desktop|g' "$SPEC_FILE"
            sed -i 's|cp -r %{name}\.png|cp -r ../%{name}.png|g' "$SPEC_FILE"
            sed -i 's|cp -r %{name}\*\.xml|cp -r ../%{name}*.xml|g' "$SPEC_FILE"
        fi

        echo "Re-running rpmbuild to finish packaging..."
        rpmbuild --define "_topdir $TOP" -bb "$SPEC_FILE"
        RPM_STATUS=$?
        if [ $RPM_STATUS -eq 0 ]; then
            echo ""
            echo -e "${GREEN}╔════════════════════════════════════╗${NC}"
            echo -e "${GREEN}║      RPM Build Successful! 🎉     ║${NC}"
            echo -e "${GREEN}╚════════════════════════════════════╝${NC}"
            echo ""
            echo -e "${GREEN}Output directory:${NC} dist/"
            
            # Show the built RPM
            find "$TOP/RPMS" -name "*.rpm" -exec ls -lh {} \; 2>/dev/null
            exit 0
        else
            echo -e "${RED}Automatic rpmbuild retry failed.${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}No build directory found at $TOP/BUILD/$NAME — cannot auto-fix.${NC}"
    fi
fi

echo ""
echo -e "${RED}╔════════════════════════════════════╗${NC}"
echo -e "${RED}║       Build Failed! ❌            ║${NC}"
echo -e "${RED}╚════════════════════════════════════╝${NC}"
exit 1
