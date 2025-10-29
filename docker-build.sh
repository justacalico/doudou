#!/bin/bash

# Docker build and push script for Doudou
set -e  # Exit on any error

# Configuration
IMAGE_NAME="doudou"
DOCKER_USERNAME="httpanimations"
DOCKER_REPO="$DOCKER_USERNAME/$IMAGE_NAME"
VERSION="7.0.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🎵 Building Doudou Docker image...${NC}"

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo -e "${RED}❌ Error: pubspec.yaml not found. Make sure you're in the Doudou project root directory.${NC}"
    exit 1
fi

# Clean previous builds
echo -e "${YELLOW}🧹 Cleaning previous builds...${NC}"
flutter clean
rm -rf build/

echo -e "${BLUE}🐳 Building Docker image...${NC}"
docker build --network=host -t $IMAGE_NAME .

echo -e "${BLUE}🏷️  Tagging image...${NC}"
docker tag $IMAGE_NAME $DOCKER_REPO:latest
docker tag $IMAGE_NAME $DOCKER_REPO:$VERSION

echo -e "${BLUE}🚀 Pushing to Docker Hub...${NC}"
docker push $DOCKER_REPO:latest
docker push $DOCKER_REPO:$VERSION

echo -e "${GREEN}✅ Successfully built and pushed $DOCKER_REPO:latest and $DOCKER_REPO:$VERSION${NC}"
echo ""
echo -e "${YELLOW}📋 Usage Instructions:${NC}"
echo ""
echo -e "${BLUE}To run the container:${NC}"
echo "  docker run -p 34273:34273 $DOCKER_REPO:latest"
echo ""
echo -e "${BLUE}Or with host networking:${NC}"
echo "  docker run --network host $DOCKER_REPO:latest"
echo ""
echo -e "${BLUE}To run in background (daemon mode):${NC}"
echo "  docker run -d -p 34273:34273 --name doudou-web $DOCKER_REPO:latest"
echo ""
echo -e "${BLUE}To view logs:${NC}"
echo "  docker logs doudou-web"
echo ""
echo -e "${BLUE}To stop the container:${NC}"
echo "  docker stop doudou-web"
echo ""
echo -e "${GREEN}🌐 Access the web app at: http://localhost:34273${NC}"
echo ""
echo -e "${YELLOW}💡 Note: Make sure your Jellyfin/Plex/Navidrome server is accessible from the container${NC}"