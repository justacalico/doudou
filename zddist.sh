#!/bin/bash
# Zed Dist (zddist) - Build script for Doudou using FastForge
# Usage: ./zddist -platform [package_type]
# Examples:
#   ./zddist -linux appimage
#   ./zddist -linux deb
#   ./zddist -macos dmg
#   ./zddist -windows msix
#   ./zddist -android apk
#   ./zddist -android aab
#   ./zddist -ios ipa

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
            # Check if exportOptions.plist exists
            if [ -f "ios/exportOptions.plist" ]; then
                BUILD_ARGS="--build-export-options-plist ios/exportOptions.plist"
            else
                echo -e "${YELLOW}Warning: ios/exportOptions.plist not found${NC}"
                echo "You may need to create it for signing the IPA"
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
if eval $BUILD_CMD; then
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
else
    echo ""
    echo -e "${RED}╔════════════════════════════════════╗${NC}"
    echo -e "${RED}║       Build Failed! ❌            ║${NC}"
    echo -e "${RED}╚════════════════════════════════════╝${NC}"
    exit 1
fi
