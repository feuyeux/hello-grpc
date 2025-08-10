#!/usr/bin/env bash
# 跨平台图标生成脚本 - 支持 Flutter 和 Tauri
# 支持平台: Windows, macOS, Linux, iOS, Android, Web

set -e

# 允许脚本中使用 alias
shopt -s expand_aliases

# Windows 下尝试自动加入 ImageMagick 安装目录到 PATH (Git Bash 中)
if command -v uname >/dev/null 2>&1; then
  UNAME_OUT="$(uname -s 2>/dev/null || echo '')"
  case "$UNAME_OUT" in
    MINGW*|MSYS*|CYGWIN*)
      for d in \
        "/c/Program Files/ImageMagick-7.1.2-Q16-HDRI" \
        "/c/Program Files/ImageMagick-7.1.2-Q16" \
        "/c/Program Files/ImageMagick" \
        "/c/Program Files (x86)/ImageMagick-7.1.2-Q16-HDRI"; do
        if [ -x "$d/magick.exe" ]; then
          case ":$PATH:" in
            *:"$d":*) ;; # already
            *) PATH="$d:$PATH"; export PATH;;
          esac
          break
        fi
      done
      ;;
  esac
fi

SCRIPT_PATH="$(
    cd "$(dirname "$0")" >/dev/null 2>&1 || exit
    pwd -P
)"
cd "$SCRIPT_PATH" || exit

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# === 新增: 统一转换命令 ===
CONVERT=""
select_convert() {
  if command -v magick >/dev/null 2>&1; then
    CONVERT="magick convert"
  elif command -v convert >/dev/null 2>&1; then
    CONVERT="convert"
  else
    log_error "未找到 ImageMagick (magick/convert)。请安装后再试。"
    exit 1
  fi
}

# 检查依赖
check_dependencies() {
    log_info "检查依赖工具..."
    select_convert
    
    # 检查 ICNS 生成工具
    if ! command -v iconutil &> /dev/null && ! command -v png2icns &> /dev/null && ! command -v icnsutil &> /dev/null; then
        log_info "没有专用 ICNS 工具，将使用 ImageMagick 兼容方案"
    fi
    
    # 检查 inkscape (用于 SVG 转换)
    if ! command -v inkscape &> /dev/null; then
        log_info "Inkscape 未安装 (可选)"
    fi
    
    log_success "依赖检查完成 (使用: $CONVERT)"
}

# 创建基础图标 (如果不存在)
create_base_icon() {
    local base_icon="$SCRIPT_PATH/assets/icon.png"
    
    if [ ! -f "$base_icon" ]; then
        log_info "创建基础图标..."
        mkdir -p "$SCRIPT_PATH/assets"
        
        # 创建一个简单的 1024x1024 图标
        $CONVERT -size 1024x1024 xc:transparent \
            -fill "#4A90E2" \
            -draw "roundrectangle 100,100 924,924 100,100" \
            -fill white \
            -pointsize 200 \
            -gravity center \
            -annotate +0+0 "gRPC" \
            "$base_icon"
        
        log_success "基础图标已创建: $base_icon"
    else
        log_info "使用现有基础图标: $base_icon"
    fi
    
    # 确保文件存在后再返回路径
    if [ -f "$base_icon" ]; then
        echo "$base_icon"
    else
        log_error "基础图标创建失败"
        exit 1
    fi
}

# 生成 ICNS 文件的跨平台函数
generate_icns_file() {
    local source_icon="$1"
    local output_icns="$2"
    
    if command -v iconutil &> /dev/null; then
        # macOS 系统使用 iconutil
        local iconset_dir="${output_icns%.icns}.iconset"
        mkdir -p "$iconset_dir"
        
        # 生成各种尺寸 (RGBA格式)
        for spec in 16:16 32:16@2x 32:32 64:32@2x 128:128 256:128@2x 256:256 512:256@2x 512:512 1024:512@2x; do
          size="${spec%%:*}" name="${spec##*:}" base="${name%@*}" suffix="${name#*@}"; [ "$suffix" = "$name" ] && suffix=""; \
          out="$iconset_dir/icon_${name/./x}.png"; \
          $CONVERT "$source_icon" -resize "${size}x${size}" -background transparent -flatten -define png:color-type=6 "$out";
        done
        iconutil -c icns "$iconset_dir" -o "$output_icns" || log_warning "iconutil 失败，可能需要手工检查"
        rm -rf "$iconset_dir"
        log_info "使用 iconutil 生成 ICNS"
    elif command -v png2icns &> /dev/null; then
        # 使用 png2icns 工具 (需要安装 libicns-utils)
        png2icns "$output_icns" "$source_icon"; log_info "使用 png2icns 生成 ICNS"
    elif command -v icnsutil &> /dev/null; then
        # 使用 icnsutil 工具
        icnsutil -c icns "$output_icns" "$source_icon"; log_info "使用 icnsutil 生成 ICNS"
    else
        # 使用 ImageMagick 直接转换 (兼容性方案)
        # 创建多尺寸图标并合并为 ICNS
        local temp_dir; temp_dir=$(mktemp -d)
        
        # 生成多个尺寸
        for s in 16 32 128 256 512; do $CONVERT "$source_icon" -resize "${s}x${s}" -background transparent -flatten "$temp_dir/icon_$s.png"; done
        if $CONVERT "$temp_dir"/icon_*.png "$output_icns" 2>/dev/null; then
          log_info "使用 ImageMagick 生成 ICNS(兼容)"
        else
          # 最后的备选方案：复制最大尺寸的PNG并重命名为ICNS
          $CONVERT "$source_icon" -resize 512x512 -background transparent -flatten "$output_icns"
          log_info "生成 ICNS 兼容 PNG"
        fi
        rm -rf "$temp_dir"
    fi
}

# 生成 Tauri 图标
generate_tauri_icons() {
    local base_icon="$1"
    local tauri_icons_dir="$SCRIPT_PATH/hello-grpc-tauri/src-tauri/icons"
    
    log_info "生成 Tauri 图标..."
    mkdir -p "$tauri_icons_dir"
    
    # Tauri 需要的图标尺寸
    local sizes=(32 128 256 512)
    
    for s in "${sizes[@]}"; do
        $CONVERT "$base_icon" -resize ${s}x${s} -background transparent -flatten -define png:color-type=6 "$tauri_icons_dir/${s}x${s}.png"
        log_info "生成 Tauri 图标: ${s}x${s}.png"
    done
    
    # 生成高分辨率图标
    $CONVERT "$base_icon" -resize 256x256 -background transparent -flatten -define png:color-type=6 "$tauri_icons_dir/128x128@2x.png"
    
    # 生成 Windows ICO 文件
    $CONVERT "$base_icon" \
        \( -clone 0 -resize 16x16 \) \
        \( -clone 0 -resize 32x32 \) \
        \( -clone 0 -resize 48x48 \) \
        \( -clone 0 -resize 64x64 \) \
        \( -clone 0 -resize 128x128 \) \
        \( -clone 0 -resize 256x256 \) \
        -delete 0 "$tauri_icons_dir/icon.ico"
    
    # 生成 macOS ICNS 文件
    generate_icns_file "$base_icon" "$tauri_icons_dir/icon.icns"
    
    log_success "Tauri 图标生成完成"
}

# 生成 Flutter 图标
generate_flutter_icons() {
    local base_icon="$1"
    local flutter_dir="$SCRIPT_PATH/hello-grpc-flutter"
    
    log_info "生成 Flutter 图标..."
    
    # Android 图标 (RGBA格式)
    local android_res_dir="$flutter_dir/android/app/src/main/res"
    mkdir -p "$android_res_dir"/{mipmap-hdpi,mipmap-mdpi,mipmap-xhdpi,mipmap-xxhdpi,mipmap-xxxhdpi}
    
    $CONVERT "$base_icon" -resize 72x72 -background transparent -flatten -define png:color-type=6 "$android_res_dir/mipmap-hdpi/ic_launcher.png"
    $CONVERT "$base_icon" -resize 48x48 -background transparent -flatten -define png:color-type=6 "$android_res_dir/mipmap-mdpi/ic_launcher.png"
    $CONVERT "$base_icon" -resize 96x96 -background transparent -flatten -define png:color-type=6 "$android_res_dir/mipmap-xhdpi/ic_launcher.png"
    $CONVERT "$base_icon" -resize 144x144 -background transparent -flatten -define png:color-type=6 "$android_res_dir/mipmap-xxhdpi/ic_launcher.png"
    $CONVERT "$base_icon" -resize 192x192 -background transparent -flatten -define png:color-type=6 "$android_res_dir/mipmap-xxxhdpi/ic_launcher.png"
    
    # iOS 图标
    local ios_assets_dir="$flutter_dir/ios/Runner/Assets.xcassets/AppIcon.appiconset"
    mkdir -p "$ios_assets_dir"
    
    # iOS 需要的各种尺寸
    local ios_sizes=(
        "20:20x20"
        "29:29x29" 
        "40:40x40"
        "58:58x58"
        "60:60x60"
        "80:80x80"
        "87:87x87"
        "120:120x120"
        "180:180x180"
        "1024:1024x1024"
    )
    
    for spec in "${ios_sizes[@]}"; do
      IFS=':' read -r sz fname <<<"$spec"; $CONVERT "$base_icon" -resize ${sz}x${sz} -background white -flatten -define png:color-type=2 "$ios_assets_dir/Icon-App-${fname}.png"; done
    
    # 创建 Contents.json
    cat > "$ios_assets_dir/Contents.json" << 'EOF'
{
  "images" : [
    {
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "20x20"
    },
    {
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "20x20"
    },
    {
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "29x29"
    },
    {
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "29x29"
    },
    {
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "40x40"
    },
    {
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "40x40"
    },
    {
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "60x60"
    },
    {
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "60x60"
    },
    {
      "idiom" : "ios-marketing",
      "scale" : "1x",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF
    
    # Web 图标
    local web_dir="$flutter_dir/web"
    mkdir -p "$web_dir/icons"
    
    # PWA 需要的图标尺寸
    local web_sizes=(16 32 96 128 192 512)
    
    for s in "${web_sizes[@]}"; do
        $CONVERT "$base_icon" -resize ${s}x${s} -background transparent -flatten -define png:color-type=6 "$web_dir/icons/Icon-${s}.png"
    done
    $CONVERT "$base_icon" -resize 32x32 -background transparent -flatten -define png:color-type=6 "$web_dir/favicon.png"
    
    # Linux 桌面图标
    local linux_assets_dir="$flutter_dir/linux/assets"
    mkdir -p "$linux_assets_dir"
    $CONVERT "$base_icon" -resize 128x128 -background transparent -flatten -define png:color-type=6 "$linux_assets_dir/icon.png"
    
    # Windows 桌面图标
    local windows_assets_dir="$flutter_dir/windows/runner/resources"
    mkdir -p "$windows_assets_dir"
    $CONVERT "$base_icon" \
        \( -clone 0 -resize 16x16 \) \
        \( -clone 0 -resize 32x32 \) \
        \( -clone 0 -resize 48x48 \) \
        \( -clone 0 -resize 256x256 \) \
        -delete 0 "$windows_assets_dir/app_icon.ico"
    
    # macOS 桌面图标
    local macos_assets_dir="$flutter_dir/macos/Runner/Assets.xcassets/AppIcon.appiconset"
    mkdir -p "$macos_assets_dir"
    
    # macOS 应用图标尺寸 (RGBA格式)
    local macos_sizes=(16 32 64 128 256 512 1024)
    
    for s in "${macos_sizes[@]}"; do
        $CONVERT "$base_icon" -resize ${s}x${s} -background transparent -flatten -define png:color-type=6 "$macos_assets_dir/app_icon_${s}.png"
    done
    
    log_success "Flutter 图标生成完成"
}

# 生成图标清单
generate_manifest() {
    local manifest_file="$SCRIPT_PATH/icon-manifest.md"
    
    cat > "$manifest_file" << 'EOF'
# 图标生成清单

## 生成时间
EOF
    echo "$(date '+%Y-%m-%d %H:%M:%S')" >> "$manifest_file"
    
    cat >> "$manifest_file" << 'EOF'

## 原始图标
- **Tauri**: `../diagram/blue.png` (蓝色主题)
- **Flutter**: `../diagram/red.png` (红色主题)

## Tauri 图标 (蓝色主题)
- `hello-grpc-tauri/src-tauri/icons/32x32.png` - 32x32 PNG
- `hello-grpc-tauri/src-tauri/icons/128x128.png` - 128x128 PNG
- `hello-grpc-tauri/src-tauri/icons/128x128@2x.png` - 256x256 PNG (高分辨率)
- `hello-grpc-tauri/src-tauri/icons/256x256.png` - 256x256 PNG
- `hello-grpc-tauri/src-tauri/icons/512x512.png` - 512x512 PNG
- `hello-grpc-tauri/src-tauri/icons/icon.ico` - Windows ICO
- `hello-grpc-tauri/src-tauri/icons/icon.icns` - macOS ICNS

## Flutter 图标 (红色主题)

### Android
- `hello-grpc-flutter/android/app/src/main/res/mipmap-*/ic_launcher.png` - 各密度图标

### iOS
- `hello-grpc-flutter/ios/Runner/Assets.xcassets/AppIcon.appiconset/` - iOS 应用图标集

### Web
- `hello-grpc-flutter/web/icons/Icon-*.png` - PWA 图标
- `hello-grpc-flutter/web/favicon.png` - 网站图标

### 桌面平台
- `hello-grpc-flutter/linux/assets/icon.png` - Linux 图标
- `hello-grpc-flutter/windows/runner/resources/app_icon.ico` - Windows 图标
- `hello-grpc-flutter/macos/Runner/Assets.xcassets/AppIcon.appiconset/` - macOS 图标

## 框架图标区分

- **Tauri 应用**: 使用蓝色主题图标，便于在桌面环境中识别
- **Flutter 应用**: 使用红色主题图标，便于在移动和Web环境中识别

## 使用说明

1. 如需自定义图标，请替换 `../diagram/blue.png` 和 `../diagram/red.png`
2. 重新运行此脚本生成所有平台图标
3. 对于生产环境，建议使用专业设计的图标

## 注意事项

- iOS 图标不能包含透明度
- Android 自适应图标需要额外配置
- Web 图标建议提供多种尺寸以适应不同设备
- 不同框架使用不同颜色主题便于用户区分
EOF
    
    log_success "图标清单已生成: $manifest_file"
}

# 主函数
main() {
    log_info "开始生成跨平台图标..."
    
    # 检查依赖
    check_dependencies
    
    # 检查原始图标文件
    local tauri_icon="$SCRIPT_PATH/../diagram/blue.png"
    local flutter_icon="$SCRIPT_PATH/../diagram/red.png"
    
    if [ ! -f "$tauri_icon" ]; then
        log_error "Tauri 图标文件不存在: $tauri_icon"
        exit 1
    fi
    
    if [ ! -f "$flutter_icon" ]; then
        log_error "Flutter 图标文件不存在: $flutter_icon"
        exit 1
    fi
    
    log_info "使用 Tauri 图标: $tauri_icon (蓝色)"
    log_info "使用 Flutter 图标: $flutter_icon (红色)"
    
    # 生成 Tauri 图标
    generate_tauri_icons "$tauri_icon"
    
    # 生成 Flutter 图标
    generate_flutter_icons "$flutter_icon"
    
    # 生成清单
    generate_manifest
    
    log_success "所有图标生成完成！"
    log_info "请查看 icon-manifest.md 了解详细信息"
}

# 帮助信息
show_help() {
    cat << 'EOF'
跨平台图标生成脚本

用法: ./generate-icons.sh [选项]

选项:
  -h, --help     显示此帮助信息
  -c, --clean    清理现有图标后重新生成

支持平台:
  - Tauri: Windows, macOS, Linux
  - Flutter: Android, iOS, Web, Windows, macOS, Linux

依赖:
  - ImageMagick (必需)
  - Inkscape (可选，用于 SVG 支持)

示例:
  ./generate-icons.sh           # 生成所有图标
  ./generate-icons.sh --clean   # 清理后重新生成
EOF
}

# 清理现有图标
clean_icons() {
    log_info "清理现有图标..."
    
    # 清理 Tauri 图标
    rm -rf "$SCRIPT_PATH/hello-grpc-tauri/src-tauri/icons"
    
    # 清理 Flutter 图标
    rm -rf "$SCRIPT_PATH/hello-grpc-flutter/android/app/src/main/res/mipmap-*"
    rm -rf "$SCRIPT_PATH/hello-grpc-flutter/ios/Runner/Assets.xcassets/AppIcon.appiconset"
    rm -rf "$SCRIPT_PATH/hello-grpc-flutter/web/icons"
    rm -f "$SCRIPT_PATH/hello-grpc-flutter/web/favicon.png"
    rm -rf "$SCRIPT_PATH/hello-grpc-flutter/linux/assets"
    rm -rf "$SCRIPT_PATH/hello-grpc-flutter/windows/runner/resources"
    rm -rf "$SCRIPT_PATH/hello-grpc-flutter/macos/Runner/Assets.xcassets/AppIcon.appiconset"
    
    log_success "图标清理完成"
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -c|--clean)
            clean_icons
            shift
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

# 运行主函数
main