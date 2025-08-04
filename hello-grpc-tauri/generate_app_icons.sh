#!/bin/bash

# Tauri App Icon Generator Script
# Generates app icons for all platforms for Tauri application

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration variables
SOURCE_ICON="/Users/han/coding/hello-grpc/diagram/blue.png"
TAURI_PROJECT_ROOT="/Users/han/coding/hello-grpc/hello-grpc-tauri"
ICONS_DIR="$TAURI_PROJECT_ROOT/src-tauri/icons"

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

echo -e "${BLUE}🎨 Generating icons for Tauri application...${NC}"

# Verify source file exists
if [ ! -f "$SOURCE_ICON" ]; then
    echo -e "${RED}❌ Error: Source icon file not found: $SOURCE_ICON${NC}"
    exit 1
fi

# Verify project directory exists
if [ ! -d "$TAURI_PROJECT_ROOT" ]; then
    echo -e "${RED}❌ Error: Tauri project directory not found: $TAURI_PROJECT_ROOT${NC}"
    exit 1
fi

cd "$TAURI_PROJECT_ROOT"

# Verify icons directory exists
if [ ! -d "$ICONS_DIR" ]; then
    echo -e "${YELLOW}📁 Creating icons directory: $ICONS_DIR${NC}"
    mkdir -p "$ICONS_DIR"
fi

echo -e "${GREEN}📱 Starting Tauri icon generation...${NC}"

# Backup original icons (if they exist)
if [ -d "$ICONS_DIR" ] && [ "$(ls -A $ICONS_DIR)" ]; then
    backup_dir="${ICONS_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
    echo -e "${YELLOW}📦 Backing up original icons to: $backup_dir${NC}"
    cp -r "$ICONS_DIR" "$backup_dir"
fi

echo -e "${YELLOW}=== Generating Tauri Icons ===${NC}"

# Required Tauri icon sizes
tauri_icons_32x32="32"
tauri_icons_128x128="128"
tauri_icons_128x128_2x="256"
tauri_icons_icon="512"
tauri_icons_Square30x30Logo="30"
tauri_icons_Square44x44Logo="44"
tauri_icons_Square71x71Logo="71"
tauri_icons_Square89x89Logo="89"
tauri_icons_Square107x107Logo="107"
tauri_icons_Square142x142Logo="142"
tauri_icons_Square150x150Logo="150"
tauri_icons_Square284x284Logo="284"
tauri_icons_Square310x310Logo="310"
tauri_icons_StoreLogo="50"

# Icon filename array
tauri_icon_files=(
    "32x32.png:32"
    "128x128.png:128" 
    "128x128@2x.png:256"
    "icon.png:512"
    "Square30x30Logo.png:30"
    "Square44x44Logo.png:44"
    "Square71x71Logo.png:71"
    "Square89x89Logo.png:89"
    "Square107x107Logo.png:107"
    "Square142x142Logo.png:142"
    "Square150x150Logo.png:150"
    "Square284x284Logo.png:284"
    "Square310x310Logo.png:310"
    "StoreLogo.png:50"
)

# Generate PNG icons with rounded corners
for icon_entry in "${tauri_icon_files[@]}"; do
    IFS=':' read -r icon_name size <<< "$icon_entry"
    output_path="$ICONS_DIR/$icon_name"
    
    echo "  Generating $icon_name (${size}x${size}) with rounded corners"
    create_rounded_icon "$SOURCE_ICON" "$output_path" "$size"
    
    if [ $? -eq 0 ]; then
        echo -e "    ${GREEN}✅ $icon_name${NC}"
    else
        echo -e "    ${RED}❌ $icon_name${NC}"
    fi
done

# Generate ICO file (Windows)
echo -e "\n${YELLOW}=== Generating Windows ICO Icon ===${NC}"
echo "  Generating icon.ico with rounded corners"

# Create temporary files for ICO composition
temp_dir="/tmp/tauri_ico_temp"
mkdir -p "$temp_dir"

# Generate required sizes for ICO with rounded corners
ico_sizes=(16 32 48 64 128 256)
for size in "${ico_sizes[@]}"; do
    create_rounded_icon "$SOURCE_ICON" "$temp_dir/icon_${size}.png" "$size"
done

# Since macOS doesn't have a direct ICO creation tool, we use the largest rounded PNG as placeholder
create_rounded_icon "$SOURCE_ICON" "$ICONS_DIR/icon.ico" 256
echo -e "    ${YELLOW}⚠️  icon.ico (using rounded PNG format, recommend regenerating as true ICO on Windows)${NC}"

# Clean up temporary files
rm -rf "$temp_dir"

# Generate ICNS file (macOS)
echo -e "\n${YELLOW}=== Generating macOS ICNS Icon ===${NC}"
echo "  Generating icon.icns"

# Create iconset directory
iconset_dir="/tmp/tauri_icon.iconset"
rm -rf "$iconset_dir"
mkdir -p "$iconset_dir"

# Generate required icon sizes for macOS
icns_icon_files=(
    "icon_16x16.png:16"
    "icon_16x16@2x.png:32"
    "icon_32x32.png:32"
    "icon_32x32@2x.png:64"
    "icon_128x128.png:128"
    "icon_128x128@2x.png:256"
    "icon_256x256.png:256"
    "icon_256x256@2x.png:512"
    "icon_512x512.png:512"
    "icon_512x512@2x.png:1024"
)

for icon_entry in "${icns_icon_files[@]}"; do
    IFS=':' read -r icon_name size <<< "$icon_entry"
    create_rounded_icon "$SOURCE_ICON" "$iconset_dir/$icon_name" "$size"
done

# Generate ICNS file
if command -v iconutil >/dev/null 2>&1; then
    iconutil -c icns "$iconset_dir" -o "$ICONS_DIR/icon.icns"
    if [ $? -eq 0 ]; then
        echo -e "    ${GREEN}✅ icon.icns (with rounded corners)${NC}"
    else
        echo -e "    ${RED}❌ icon.icns (iconutil failed)${NC}"
    fi
else
    echo -e "    ${YELLOW}⚠️  iconutil not available, skipping ICNS generation${NC}"
fi

# Clean up temporary files
rm -rf "$iconset_dir"

# Verify icon configuration in tauri.conf.json
echo -e "\n${YELLOW}=== Verifying Tauri Configuration ===${NC}"
tauri_config="$TAURI_PROJECT_ROOT/src-tauri/tauri.conf.json"

if [ -f "$tauri_config" ]; then
    echo -e "${GREEN}✅ tauri.conf.json exists${NC}"
    
    # Check icon configuration
    if grep -q "icons" "$tauri_config"; then
        echo -e "${GREEN}✅ Icon configuration exists${NC}"
    else
        echo -e "${YELLOW}⚠️  Recommend checking icon configuration in tauri.conf.json${NC}"
    fi
else
    echo -e "${RED}❌ tauri.conf.json not found${NC}"
fi

echo -e "\n${GREEN}🎉 Tauri icon generation with rounded corners completed!${NC}"
echo -e "${BLUE}📝 Generated icons location: $ICONS_DIR${NC}"
echo -e "${YELLOW}💡 Tips:${NC}"
echo -e "   • All icons have been generated with rounded corners (12.5% radius)"
echo -e "   • Recommend regenerating true .ico file on Windows"
echo -e "   • Check icon path configuration in tauri.conf.json"
echo -e "   • Run 'tauri build' to test if build works correctly"

# Display generated file list
echo -e "\n${BLUE}📋 Generated icon files:${NC}"
ls -la "$ICONS_DIR"
