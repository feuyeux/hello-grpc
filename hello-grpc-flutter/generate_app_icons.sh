#!/bin/bash

# Flutter App Icon Generator Script
# Generates app icons for all platforms using red.png as source image

set -e  # Exit immediately on error

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Source image path
SOURCE_IMAGE="/Users/han/coding/hello-grpc/diagram/red.png"
FLUTTER_PROJECT_ROOT="/Users/han/coding/hello-grpc/hello-grpc-flutter"

# Function to create rounded corner icons
create_rounded_icon() {
    local input_image="$1"
    local output_image="$2"
    local size="$3"
    local radius=$((size / 8))  # 12.5% corner radius
    
    # Create rounded corners using a simpler ImageMagick approach
    magick "$input_image" \
        -resize "${size}x${size}" \
        \( -size "${size}x${size}" xc:none -fill white \
           -draw "roundrectangle 0,0 $((size-1)),$((size-1)) ${radius},${radius}" \) \
        -compose DstIn -composite \
        "$output_image"
}

echo -e "${GREEN}🚀 Starting Flutter app icon generation...${NC}"

# Check if source image exists
if [ ! -f "$SOURCE_IMAGE" ]; then
    echo -e "${RED}❌ Error: Source image not found: $SOURCE_IMAGE${NC}"
    exit 1
fi

# Check image info
echo -e "${YELLOW}📋 Source image info:${NC}"
file "$SOURCE_IMAGE"

# Switch to Flutter project directory
cd "$FLUTTER_PROJECT_ROOT"

echo -e "${GREEN}📁 Creating assets directory...${NC}"
# Create assets directory
mkdir -p assets/images

# Create rounded corner version for assets
create_rounded_icon "$SOURCE_IMAGE" assets/images/app_icon.png 512
echo -e "${GREEN}✅ Created rounded corner app icon in assets/images/app_icon.png${NC}"

echo -e "${GREEN}🤖 Generating Android icons...${NC}"
# Generate Android icons with rounded corners (different densities)
create_rounded_icon "$SOURCE_IMAGE" android/app/src/main/res/mipmap-mdpi/ic_launcher.png 48
create_rounded_icon "$SOURCE_IMAGE" android/app/src/main/res/mipmap-hdpi/ic_launcher.png 72
create_rounded_icon "$SOURCE_IMAGE" android/app/src/main/res/mipmap-xhdpi/ic_launcher.png 96
create_rounded_icon "$SOURCE_IMAGE" android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png 144
create_rounded_icon "$SOURCE_IMAGE" android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png 192
echo -e "${GREEN}✅ Android icons with rounded corners generated successfully${NC}"

echo -e "${GREEN}🍎 Generating iOS icons...${NC}"
# Remove existing iOS icons
rm -f ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-*.png

# Generate iOS icons with rounded corners (all required sizes)
IOS_ICON_DIR="ios/Runner/Assets.xcassets/AppIcon.appiconset"

create_rounded_icon "$SOURCE_IMAGE" "$IOS_ICON_DIR/Icon-App-20x20@1x.png" 20
create_rounded_icon "$SOURCE_IMAGE" "$IOS_ICON_DIR/Icon-App-20x20@2x.png" 40
create_rounded_icon "$SOURCE_IMAGE" "$IOS_ICON_DIR/Icon-App-20x20@3x.png" 60
create_rounded_icon "$SOURCE_IMAGE" "$IOS_ICON_DIR/Icon-App-29x29@1x.png" 29
create_rounded_icon "$SOURCE_IMAGE" "$IOS_ICON_DIR/Icon-App-29x29@2x.png" 58
create_rounded_icon "$SOURCE_IMAGE" "$IOS_ICON_DIR/Icon-App-29x29@3x.png" 87
create_rounded_icon "$SOURCE_IMAGE" "$IOS_ICON_DIR/Icon-App-40x40@1x.png" 40
create_rounded_icon "$SOURCE_IMAGE" "$IOS_ICON_DIR/Icon-App-40x40@2x.png" 80
create_rounded_icon "$SOURCE_IMAGE" "$IOS_ICON_DIR/Icon-App-40x40@3x.png" 120
create_rounded_icon "$SOURCE_IMAGE" "$IOS_ICON_DIR/Icon-App-60x60@2x.png" 120
create_rounded_icon "$SOURCE_IMAGE" "$IOS_ICON_DIR/Icon-App-60x60@3x.png" 180
create_rounded_icon "$SOURCE_IMAGE" "$IOS_ICON_DIR/Icon-App-76x76@1x.png" 76
create_rounded_icon "$SOURCE_IMAGE" "$IOS_ICON_DIR/Icon-App-76x76@2x.png" 152
create_rounded_icon "$SOURCE_IMAGE" "$IOS_ICON_DIR/Icon-App-83.5x83.5@2x.png" 167
create_rounded_icon "$SOURCE_IMAGE" "$IOS_ICON_DIR/Icon-App-1024x1024@1x.png" 1024
echo -e "${GREEN}✅ iOS icons with rounded corners generated successfully${NC}"

echo -e "${GREEN}💻 Generating macOS icons...${NC}"
# Generate macOS icons with rounded corners
MACOS_ICON_DIR="macos/Runner/Assets.xcassets/AppIcon.appiconset"

create_rounded_icon "$SOURCE_IMAGE" "$MACOS_ICON_DIR/app_icon_16.png" 16
create_rounded_icon "$SOURCE_IMAGE" "$MACOS_ICON_DIR/app_icon_32.png" 32
create_rounded_icon "$SOURCE_IMAGE" "$MACOS_ICON_DIR/app_icon_64.png" 64
create_rounded_icon "$SOURCE_IMAGE" "$MACOS_ICON_DIR/app_icon_128.png" 128
create_rounded_icon "$SOURCE_IMAGE" "$MACOS_ICON_DIR/app_icon_256.png" 256
create_rounded_icon "$SOURCE_IMAGE" "$MACOS_ICON_DIR/app_icon_512.png" 512
create_rounded_icon "$SOURCE_IMAGE" "$MACOS_ICON_DIR/app_icon_1024.png" 1024
echo -e "${GREEN}✅ macOS icons with rounded corners generated successfully${NC}"

echo -e "${GREEN}📝 Updating pubspec.yaml...${NC}"
# Check if pubspec.yaml already contains assets configuration
if ! grep -q "assets:" pubspec.yaml; then
    echo "  
  assets:
    - assets/images/" >> pubspec.yaml
    echo -e "${GREEN}✅ Added assets configuration to pubspec.yaml${NC}"
else
    echo -e "${YELLOW}⚠️  Assets configuration already exists in pubspec.yaml${NC}"
fi

echo -e "${GREEN}📊 Verifying generated icons...${NC}"
echo -e "${YELLOW}=== Android Icons ===${NC}"
ls -la android/app/src/main/res/mipmap-*/ic_launcher.png || echo "Android icons not found"

echo -e "${YELLOW}=== iOS Icons ===${NC}"
ls -la ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-*.png | head -5
echo "... (more iOS icons available)"

echo -e "${YELLOW}=== macOS Icons ===${NC}"
ls -la macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_*.png || echo "macOS icons not found"

echo -e "${YELLOW}=== Flutter Assets ===${NC}"
ls -la assets/images/ || echo "Flutter assets not found"

echo -e "${GREEN}🎉 Icon generation with rounded corners completed!${NC}"
echo -e "${YELLOW}💡 All icons have been generated with rounded corners (12.5% radius)${NC}"
