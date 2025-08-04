#!/bin/bash

# Flutter App Icon Verification Script
# Verifies that all generated icons are complete

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FLUTTER_PROJECT_ROOT="/Users/han/coding/hello-grpc/hello-grpc-flutter"

echo -e "${GREEN}🔍 Verifying Flutter app icons...${NC}"

cd "$FLUTTER_PROJECT_ROOT"

# Verify Android icons
echo -e "${YELLOW}=== Verifying Android Icons ===${NC}"
android_icons=(
    "android/app/src/main/res/mipmap-mdpi/ic_launcher.png"
    "android/app/src/main/res/mipmap-hdpi/ic_launcher.png"
    "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png"
    "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png"
    "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"
)

android_count=0
for icon in "${android_icons[@]}"; do
    if [ -f "$icon" ]; then
        echo -e "${GREEN}✅ $icon${NC}"
        android_count=$((android_count + 1))
    else
        echo -e "${RED}❌ $icon${NC}"
    fi
done
echo "Android icons: $android_count/5 ✅"

# Verify iOS icons
echo -e "${YELLOW}=== Verifying iOS Icons ===${NC}"
ios_icons=(
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png"
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png"
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png"
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png"
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png"
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png"
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png"
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png"
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png"
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png"
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png"
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png"
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png"
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png"
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"
)

ios_count=0
for icon in "${ios_icons[@]}"; do
    if [ -f "$icon" ]; then
        echo -e "${GREEN}✅ $(basename "$icon")${NC}"
        ios_count=$((ios_count + 1))
    else
        echo -e "${RED}❌ $(basename "$icon")${NC}"
    fi
done
echo "iOS icons: $ios_count/15 ✅"

# Verify macOS icons
echo -e "${YELLOW}=== Verifying macOS Icons ===${NC}"
macos_icons=(
    "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png"
    "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png"
    "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png"
    "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png"
    "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png"
    "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png"
    "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png"
)

macos_count=0
for icon in "${macos_icons[@]}"; do
    if [ -f "$icon" ]; then
        echo -e "${GREEN}✅ $(basename "$icon")${NC}"
        macos_count=$((macos_count + 1))
    else
        echo -e "${RED}❌ $(basename "$icon")${NC}"
    fi
done
echo "macOS icons: $macos_count/7 ✅"

# Verify Flutter Assets
echo -e "${YELLOW}=== Verifying Flutter Assets ===${NC}"
if [ -f "assets/images/app_icon.png" ]; then
    echo -e "${GREEN}✅ assets/images/app_icon.png${NC}"
    assets_count=1
else
    echo -e "${RED}❌ assets/images/app_icon.png${NC}"
    assets_count=0
fi
echo "Flutter Assets: $assets_count/1 ✅"

# Verify pubspec.yaml
echo -e "${YELLOW}=== Verifying pubspec.yaml Configuration ===${NC}"
if grep -q "assets:" pubspec.yaml && grep -q "assets/images/" pubspec.yaml; then
    echo -e "${GREEN}✅ pubspec.yaml contains assets configuration${NC}"
    pubspec_ok=1
else
    echo -e "${RED}❌ pubspec.yaml missing assets configuration${NC}"
    pubspec_ok=0
fi

# Summary
total_icons=$((android_count + ios_count + macos_count + assets_count))
total_expected=28

echo -e "\n${GREEN}📊 Verification Summary:${NC}"
echo "Android: $android_count/5"
echo "iOS: $ios_count/15"
echo "macOS: $macos_count/7"
echo "Assets: $assets_count/1"
echo "Config: $pubspec_ok/1"
echo "------------------------"
echo "Total: $total_icons/$total_expected icons"

if [ $total_icons -eq $total_expected ] && [ $pubspec_ok -eq 1 ]; then
    echo -e "${GREEN}🎉 All icons and configurations are correct!${NC}"
    exit 0
else
    echo -e "${RED}⚠️  Some icons or configurations are missing, please re-run generate_app_icons.sh${NC}"
    exit 1
fi
