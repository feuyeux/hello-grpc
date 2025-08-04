#!/bin/bash

# Tauri App Icon Verification Script
# Verifies that generated Tauri icons are complete

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TAURI_PROJECT_ROOT="/Users/han/coding/hello-grpc/hello-grpc-tauri"
ICONS_DIR="$TAURI_PROJECT_ROOT/src-tauri/icons"

echo -e "${BLUE}🔍 Verifying Tauri app icons...${NC}"

cd "$TAURI_PROJECT_ROOT"

# Verify basic icons
echo -e "${YELLOW}=== Verifying Basic Icons ===${NC}"
basic_icons=(
    "32x32.png"
    "128x128.png"
    "128x128@2x.png"
    "icon.png"
    "icon.ico"
    "icon.icns"
)

basic_count=0
for icon in "${basic_icons[@]}"; do
    icon_path="$ICONS_DIR/$icon"
    if [ -f "$icon_path" ]; then
        # Get file size
        size=$(ls -lh "$icon_path" | awk '{print $5}')
        echo -e "${GREEN}✅ $icon ($size)${NC}"
        basic_count=$((basic_count + 1))
    else
        echo -e "${RED}❌ $icon${NC}"
    fi
done
echo "Basic icons: $basic_count/6 ✅"

# Verify Windows Store icons
echo -e "${YELLOW}=== Verifying Windows Store Icons ===${NC}"
windows_icons=(
    "Square30x30Logo.png"
    "Square44x44Logo.png"
    "Square71x71Logo.png"
    "Square89x89Logo.png"
    "Square107x107Logo.png"
    "Square142x142Logo.png"
    "Square150x150Logo.png"
    "Square284x284Logo.png"
    "Square310x310Logo.png"
    "StoreLogo.png"
)

windows_count=0
for icon in "${windows_icons[@]}"; do
    icon_path="$ICONS_DIR/$icon"
    if [ -f "$icon_path" ]; then
        # Get file size
        size=$(ls -lh "$icon_path" | awk '{print $5}')
        echo -e "${GREEN}✅ $icon ($size)${NC}"
        windows_count=$((windows_count + 1))
    else
        echo -e "${RED}❌ $icon${NC}"
    fi
done
echo "Windows Store icons: $windows_count/10 ✅"

# Verify Tauri configuration file
echo -e "${YELLOW}=== Verifying Tauri Configuration ===${NC}"
tauri_config="$TAURI_PROJECT_ROOT/src-tauri/tauri.conf.json"

config_ok=0
if [ -f "$tauri_config" ]; then
    echo -e "${GREEN}✅ tauri.conf.json exists${NC}"
    
    # Check icon configuration
    if grep -q "icons" "$tauri_config"; then
        echo -e "${GREEN}✅ Icon configuration exists${NC}"
        config_ok=1
        
        # Display icon configuration content
        echo -e "${BLUE}📋 Current icon configuration:${NC}"
        grep -A 10 -B 2 "icons" "$tauri_config" | sed 's/^/    /'
    else
        echo -e "${YELLOW}⚠️  Icon configuration not found${NC}"
    fi
else
    echo -e "${RED}❌ tauri.conf.json not found${NC}"
fi

# Verify build dependencies
echo -e "${YELLOW}=== Verifying Project Structure ===${NC}"
project_files=(
    "src-tauri/Cargo.toml"
    "src-tauri/src/main.rs"
    "package.json"
)

project_count=0
for file in "${project_files[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✅ $file${NC}"
        project_count=$((project_count + 1))
    else
        echo -e "${RED}❌ $file${NC}"
    fi
done
echo "Project files: $project_count/3 ✅"

# Check source icon information
echo -e "${YELLOW}=== Source Icon Information ===${NC}"
source_icon="/Users/han/coding/hello-grpc/diagram/blue.png"
if [ -f "$source_icon" ]; then
    echo -e "${GREEN}✅ Source icon: $source_icon${NC}"
    
    # Get icon information
    if command -v file >/dev/null 2>&1; then
        icon_info=$(file "$source_icon")
        echo -e "${BLUE}   Info: $icon_info${NC}"
    fi
    
    if command -v sips >/dev/null 2>&1; then
        dimensions=$(sips -g pixelWidth -g pixelHeight "$source_icon" 2>/dev/null | tail -2 | awk '{print $2}' | tr '\n' 'x' | sed 's/x$//')
        echo -e "${BLUE}   Dimensions: ${dimensions}${NC}"
    fi
else
    echo -e "${RED}❌ Source icon not found: $source_icon${NC}"
fi

# Generate summary
total_icons=$((basic_count + windows_count))
total_expected=16

echo -e "\n${BLUE}📊 Verification Summary:${NC}"
echo "Basic icons: $basic_count/6"
echo "Windows icons: $windows_count/10"
echo "Config file: $config_ok/1"
echo "Project files: $project_count/3"
echo "------------------------"
echo "Total: $total_icons/$total_expected icons"

if [ $total_icons -eq $total_expected ] && [ $config_ok -eq 1 ] && [ $project_count -eq 3 ]; then
    echo -e "${GREEN}🎉 All icons and configurations are correct!${NC}"
    echo -e "${GREEN}💡 You can run the following commands to test build:${NC}"
    echo -e "   ${BLUE}cd $TAURI_PROJECT_ROOT${NC}"
    echo -e "   ${BLUE}npm run tauri build${NC}"
    exit 0
else
    echo -e "${RED}⚠️  Some icons or configurations are missing${NC}"
    if [ $total_icons -ne $total_expected ]; then
        echo -e "   • Re-run: ./generate_app_icons.sh"
    fi
    if [ $config_ok -ne 1 ]; then
        echo -e "   • Check icon configuration in tauri.conf.json"
    fi
    if [ $project_count -ne 3 ]; then
        echo -e "   • Check if project structure is complete"
    fi
    exit 1
fi
