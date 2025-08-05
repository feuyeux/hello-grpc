#!/bin/bash
# Hello gRPC Apps 统一构建脚本
# Unified build script for Hello gRPC Flutter and Tauri applications
# 
# 此脚本合并了以下功能：
# - Flutter全平台构建 (Android, iOS, Web, Windows, macOS, Linux)
# - Tauri全平台构建 (Windows, macOS, Linux, Web)
# - iOS证书自动修复和配置
# - 构建产物管理和报告生成
# - 开发环境验证和依赖检查
# 
# 构建产物输出目录: hello-grpc-app/build

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
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

log_section() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

log_debug() {
    if [ "$DEBUG" = true ]; then
        echo -e "${PURPLE}[DEBUG]${NC} $1"
    fi
}

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 项目目录
FLUTTER_DIR="$SCRIPT_DIR/hello-grpc-flutter"
TAURI_DIR="$SCRIPT_DIR/hello-grpc-tauri"
GATEWAY_DIR="$SCRIPT_DIR/hello-grpc-gateway"

# 构建输出目录
BUILD_DIR="$SCRIPT_DIR/build_output"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# 默认参数
CLEAN=false
APP_TYPE="all"
PLATFORMS=""
DEBUG=false
IOS_FIX=false
SKIP_DEPS_CHECK=false
PARALLEL_BUILD=false

# 构建统计
BUILD_START_TIME=""
BUILD_END_TIME=""
SUCCESS_COUNT=0
TOTAL_COUNT=0
FAILED_BUILDS=()

# 使用说明
show_usage() {
    echo "Hello gRPC Apps 统一构建脚本"
    echo "=============================="
    echo ""
    echo "用法: $0 [选项] [应用类型] [平台...]"
    echo ""
    echo "选项:"
    echo "  --clean            清理之前的构建产物"
    echo "  --debug            启用调试输出"
    echo "  --ios-fix          自动修复iOS证书问题"
    echo "  --skip-deps        跳过依赖检查"
    echo "  --parallel         并行构建(实验性)"
    echo "  --help             显示此帮助信息"
    echo ""
    echo "应用类型:"
    echo "  flutter            仅构建Flutter应用"
    echo "  tauri              仅构建Tauri应用"
    echo "  gateway            仅构建Gateway应用"
    echo "  all                构建所有应用 (默认)"
    echo ""
    echo "平台 (Flutter):"
    echo "  android            Android APK/AAB"
    echo "  ios                iOS应用 (仅macOS)"
    echo "  web                Web应用"
    echo "  windows            Windows应用 (仅Windows)"
    echo "  macos              macOS应用 (仅macOS)"
    echo "  linux              Linux应用 (仅Linux)"
    echo ""
    echo "平台 (Tauri):"
    echo "  windows            Windows MSI/EXE"
    echo "  macos              macOS DMG/APP"
    echo "  linux              Linux AppImage/DEB"
    echo "  web                Web应用"
    echo ""
    echo "示例:"
    echo "  $0                                # 构建所有应用的所有支持平台"
    echo "  $0 flutter                        # 仅构建Flutter应用"
    echo "  $0 tauri macos linux              # 仅构建Tauri的macOS和Linux版本"
    echo "  $0 --clean --ios-fix all          # 清理后修复iOS问题并构建所有应用"
    echo "  $0 --debug flutter android web    # 调试模式构建Flutter的Android和Web版本"
    echo "  $0 --parallel all                 # 并行构建所有应用"
    echo ""
    echo "构建产物将保存在: $BUILD_DIR/"
}

# 检查操作系统
detect_os() {
    case "$OSTYPE" in
        darwin*) OS="macos" ;;
        linux*) OS="linux" ;;
        msys*|cygwin*|win32*) OS="windows" ;;
        *) OS="unknown" ;;
    esac
    log_debug "检测到操作系统: $OS"
}

# 检查必要工具
check_requirements() {
    if [ "$SKIP_DEPS_CHECK" = true ]; then
        log_warning "跳过依赖检查"
        return 0
    fi

    log_info "检查必要工具..."
    
    local missing_tools=()
    
    # 检查基本工具
    if ! command -v git &> /dev/null; then
        missing_tools+=("git")
    fi
    
    # 如果需要构建Flutter
    if [[ "$APP_TYPE" == "all" || "$APP_TYPE" == "flutter" ]]; then
        if ! command -v flutter &> /dev/null; then
            missing_tools+=("flutter")
        fi
        if ! command -v dart &> /dev/null; then
            missing_tools+=("dart")
        fi
    fi
    
    # 如果需要构建Tauri
    if [[ "$APP_TYPE" == "all" || "$APP_TYPE" == "tauri" ]]; then
        if ! command -v node &> /dev/null; then
            missing_tools+=("node")
        fi
        if ! command -v cargo &> /dev/null; then
            missing_tools+=("rust/cargo")
        fi
    fi

    # 如果需要构建Gateway
    if [[ "$APP_TYPE" == "all" || "$APP_TYPE" == "gateway" ]]; then
        if ! command -v go &> /dev/null; then
            missing_tools+=("go")
        fi
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "缺少必要工具: ${missing_tools[*]}"
        log_info "请安装缺少的工具后重试。"
        log_info "Flutter: https://flutter.dev/docs/get-started/install"
        log_info "Rust: https://rustup.rs/"
        log_info "Node.js: https://nodejs.org/"
        log_info "Go: https://golang.org/doc/install"
        exit 1
    fi
    
    log_success "所有必要工具都已安装"
    
    # 显示版本信息
    log_debug "工具版本信息:"
    if command -v flutter &> /dev/null; then
        log_debug "Flutter: $(flutter --version | head -1)"
    fi
    if command -v node &> /dev/null; then
        log_debug "Node.js: $(node --version)"
    fi
    if command -v cargo &> /dev/null; then
        log_debug "Rust: $(rustc --version)"
    fi
    if command -v go &> /dev/null; then
        log_debug "Go: $(go version)"
    fi
}

# iOS证书自动修复
fix_ios_certificates() {
    if [[ "$OS" != "macos" ]]; then
        log_warning "iOS证书修复仅支持macOS平台"
        return 0
    fi

    log_section "iOS证书自动修复"
    
    # 检查开发证书
    log_info "检查iOS开发证书..."
    local certificates=$(security find-identity -v -p codesigning 2>/dev/null | grep -E "Apple Development" | head -1)
    
    if [ -z "$certificates" ]; then
        log_error "未找到Apple Development证书"
        log_info "请在Xcode中添加开发者账户并创建证书"
        return 1
    fi
    
    log_success "找到开发证书: $certificates"
    
    # 提取团队ID
    local team_id=$(echo "$certificates" | grep -o '([A-Z0-9]\{10\})' | tr -d '()')
    if [ -n "$team_id" ]; then
        log_info "检测到团队ID: $team_id"
        
        # 修复Flutter项目Bundle ID和团队ID
        if [ -d "$FLUTTER_DIR" ]; then
            log_info "修复Flutter项目iOS配置..."
            local pbxproj_file="$FLUTTER_DIR/ios/Runner.xcodeproj/project.pbxproj"
            if [ -f "$pbxproj_file" ]; then
                # 备份原文件
                cp "$pbxproj_file" "$pbxproj_file.backup"
                
                # 更新团队ID
                sed -i '' "s/DEVELOPMENT_TEAM = .*/DEVELOPMENT_TEAM = $team_id;/" "$pbxproj_file"
                
                # 更新Bundle ID
                local bundle_id="com.feuyeux.hello-grpc-flutter"
                sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = .*/PRODUCT_BUNDLE_IDENTIFIER = $bundle_id;/" "$pbxproj_file"
                
                log_success "Flutter iOS配置已更新"
            fi
        fi
        
        # 修复Tauri项目配置
        if [ -d "$TAURI_DIR" ]; then
            log_info "修复Tauri项目iOS配置..."
            local tauri_conf="$TAURI_DIR/src-tauri/tauri.conf.json"
            if [ -f "$tauri_conf" ]; then
                # 备份原文件
                cp "$tauri_conf" "$tauri_conf.backup"
                
                # 更新Bundle ID (需要jq工具，如果没有就用sed)
                if command -v jq &> /dev/null; then
                    local temp_file=$(mktemp)
                    jq ".tauri.bundle.identifier = \"com.feuyeux.hello-grpc-tauri\"" "$tauri_conf" > "$temp_file"
                    mv "$temp_file" "$tauri_conf"
                else
                    sed -i '' 's/"identifier": "[^"]*"/"identifier": "com.feuyeux.hello-grpc-tauri"/' "$tauri_conf"
                fi
                
                log_success "Tauri iOS配置已更新"
            fi
        fi
    fi
    
    log_success "iOS证书修复完成"
}

# 设置proto链接
setup_proto_links() {
    log_info "设置proto文件链接..."
    
    local proto_source="$SCRIPT_DIR/../proto"
    
    # Flutter proto链接
    if [ -d "$FLUTTER_DIR" ]; then
        local flutter_proto_dir="$FLUTTER_DIR/protos"
        mkdir -p "$flutter_proto_dir"
        rm -rf "$flutter_proto_dir"/*
        if [ -d "$proto_source" ]; then
            ln -sf "$proto_source"/*.proto "$flutter_proto_dir/" 2>/dev/null || true
            log_debug "Flutter proto链接已建立"
        fi
    fi
    
    # Tauri proto链接
    if [ -d "$TAURI_DIR" ]; then
        local tauri_proto_dir="$TAURI_DIR/protos"
        mkdir -p "$tauri_proto_dir"
        rm -rf "$tauri_proto_dir"/*
        if [ -d "$proto_source" ]; then
            ln -sf "$proto_source"/*.proto "$tauri_proto_dir/" 2>/dev/null || true
            log_debug "Tauri proto链接已建立"
        fi
    fi
}

# 构建Flutter应用
build_flutter() {
    local platforms="$1"
    
    if [ ! -d "$FLUTTER_DIR" ]; then
        log_warning "Flutter项目目录不存在: $FLUTTER_DIR"
        return 1
    fi
    
    log_section "构建Flutter应用"
    
    cd "$FLUTTER_DIR"
    
    # 获取依赖
    log_info "获取Flutter依赖..."
    flutter pub get --suppress-analytics > /dev/null 2>&1
    
    # 设置proto链接
    setup_proto_links
    
    # 创建Flutter构建输出目录
    local flutter_build_dir="$BUILD_DIR/flutter"
    mkdir -p "$flutter_build_dir"
    
    local build_success=true
    local current_platforms=""
    
    # 确定要构建的平台
    if [ -n "$platforms" ]; then
        current_platforms="$platforms"
    else
        # 根据当前操作系统选择默认平台
        case "$OS" in
            macos) current_platforms="android ios web macos" ;;
            linux) current_platforms="android web linux" ;;
            windows) current_platforms="android web windows" ;;
            *) current_platforms="web" ;;
        esac
    fi
    
    log_info "Flutter构建平台: $current_platforms"
    
    # 构建各个平台
    for platform in $current_platforms; do
        log_info "构建Flutter $platform 平台..."
        
        case "$platform" in
            android)
                if build_flutter_android "$flutter_build_dir"; then
                    log_success "Flutter Android 构建成功"
                else
                    log_error "Flutter Android 构建失败"
                    FAILED_BUILDS+=("Flutter Android")
                    build_success=false
                fi
                ;;
            ios)
                if [[ "$OS" == "macos" ]]; then
                    if build_flutter_ios "$flutter_build_dir"; then
                        log_success "Flutter iOS 构建成功"
                    else
                        log_error "Flutter iOS 构建失败"
                        FAILED_BUILDS+=("Flutter iOS")
                        build_success=false
                    fi
                else
                    log_warning "iOS构建仅支持macOS平台"
                fi
                ;;
            web)
                if build_flutter_web "$flutter_build_dir"; then
                    log_success "Flutter Web 构建成功"
                else
                    log_error "Flutter Web 构建失败"
                    FAILED_BUILDS+=("Flutter Web")
                    build_success=false
                fi
                ;;
            macos)
                if [[ "$OS" == "macos" ]]; then
                    if build_flutter_macos "$flutter_build_dir"; then
                        log_success "Flutter macOS 构建成功"
                    else
                        log_error "Flutter macOS 构建失败"
                        FAILED_BUILDS+=("Flutter macOS")
                        build_success=false
                    fi
                else
                    log_warning "macOS构建仅支持macOS平台"
                fi
                ;;
            windows)
                if [[ "$OS" == "windows" ]]; then
                    if build_flutter_windows "$flutter_build_dir"; then
                        log_success "Flutter Windows 构建成功"
                    else
                        log_error "Flutter Windows 构建失败"
                        FAILED_BUILDS+=("Flutter Windows")
                        build_success=false
                    fi
                else
                    log_warning "Windows构建仅支持Windows平台"
                fi
                ;;
            linux)
                if [[ "$OS" == "linux" ]]; then
                    if build_flutter_linux "$flutter_build_dir"; then
                        log_success "Flutter Linux 构建成功"
                    else
                        log_error "Flutter Linux 构建失败"
                        FAILED_BUILDS+=("Flutter Linux")
                        build_success=false
                    fi
                else
                    log_warning "Linux构建仅支持Linux平台"
                fi
                ;;
            *)
                log_warning "不支持的Flutter平台: $platform"
                ;;
        esac
    done
    
    cd "$SCRIPT_DIR"
    
    if [ "$build_success" = true ]; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    fi
    return $([ "$build_success" = true ] && echo 0 || echo 1)
}

# 构建Flutter Android
build_flutter_android() {
    local output_dir="$1"
    
    log_info "开始构建Flutter Android..."
    
    # 检查Android签名密钥
    local keystore_file="android/app/keystore/hello-grpc-release.keystore"
    if [ ! -f "$keystore_file" ]; then
        log_info "创建Android签名密钥..."
        mkdir -p android/app/keystore
        keytool -genkey -v -keystore "$keystore_file" \
            -alias hello-grpc-key -keyalg RSA -keysize 2048 -validity 10000 \
            -storepass hello-grpc-2024 -keypass hello-grpc-2024 \
            -dname "CN=Hello gRPC Flutter, OU=Development, O=Feuyeux, L=Shanghai, ST=Shanghai, C=CN" \
            2>/dev/null || true
    fi
    
    # 构建APK
    if flutter build apk --release --quiet; then
        local apk_file="build/app/outputs/flutter-apk/app-release.apk"
        if [ -f "$apk_file" ]; then
            local dest_file="$output_dir/hello-grpc-flutter-android-${TIMESTAMP}.apk"
            cp "$apk_file" "$dest_file"
            log_info "APK保存至: $dest_file"
        fi
        
        # 构建AAB (Play Store格式)
        if flutter build appbundle --release --quiet; then
            local aab_file="build/app/outputs/bundle/release/app-release.aab"
            if [ -f "$aab_file" ]; then
                local dest_file="$output_dir/hello-grpc-flutter-android-${TIMESTAMP}.aab"
                cp "$aab_file" "$dest_file"
                log_info "AAB保存至: $dest_file"
            fi
        fi
        
        return 0
    else
        return 1
    fi
}

# 构建Flutter iOS
build_flutter_ios() {
    local output_dir="$1"
    
    log_info "开始构建Flutter iOS..."
    
    # 构建iOS
    if flutter build ios --release --no-codesign --quiet; then
        # 打包IPA (需要额外工具)
        local app_file="build/ios/iphoneos/Runner.app"
        if [ -d "$app_file" ]; then
            local dest_dir="$output_dir/hello-grpc-flutter-ios-${TIMESTAMP}"
            mkdir -p "$dest_dir"
            cp -r "$app_file" "$dest_dir/"
            log_info "iOS APP保存至: $dest_dir/"
            
            # 如果有xcodebuild工具，尝试生成IPA
            if command -v xcodebuild &> /dev/null; then
                log_info "尝试生成IPA文件..."
                cd ios
                xcodebuild -workspace Runner.xcworkspace -scheme Runner -destination generic/platform=iOS archive -archivePath "$dest_dir/Runner.xcarchive" 2>/dev/null || true
                cd ..
            fi
        fi
        return 0
    else
        return 1
    fi
}

# 构建Flutter Web
build_flutter_web() {
    local output_dir="$1"
    
    log_info "开始构建Flutter Web..."
    
    if flutter build web --release --quiet; then
        local web_dir="build/web"
        if [ -d "$web_dir" ]; then
            local dest_dir="$output_dir/hello-grpc-flutter-web-${TIMESTAMP}"
            cp -r "$web_dir" "$dest_dir"
            
            # 创建压缩包
            cd "$output_dir"
            tar -czf "hello-grpc-flutter-web-${TIMESTAMP}.tar.gz" "hello-grpc-flutter-web-${TIMESTAMP}"
            cd - > /dev/null
            
            log_info "Web应用保存至: $dest_dir/"
        fi
        return 0
    else
        return 1
    fi
}

# 构建Flutter macOS
build_flutter_macos() {
    local output_dir="$1"
    
    log_info "开始构建Flutter macOS..."
    
    if flutter build macos --release --quiet; then
        local app_file="build/macos/Build/Products/Release/hello_grpc_flutter.app"
        if [ -d "$app_file" ]; then
            local dest_file="$output_dir/hello-grpc-flutter-macos-${TIMESTAMP}.app"
            cp -r "$app_file" "$dest_file"
            log_info "macOS APP保存至: $dest_file"
            
            # 创建DMG文件
            log_info "创建DMG安装包..."
            local dmg_file="$output_dir/hello-grpc-flutter-macos-${TIMESTAMP}.dmg"
            local temp_dir=$(mktemp -d)
            
            # 复制APP到临时目录
            cp -r "$dest_file" "$temp_dir/"
            
            # 创建DMG
            if command -v hdiutil &> /dev/null; then
                hdiutil create -volname "Hello gRPC Flutter" \
                    -srcfolder "$temp_dir" \
                    -ov -format UDZO \
                    "$dmg_file" 2>/dev/null || {
                    log_warning "DMG创建失败，仅保留APP文件"
                }
                
                if [ -f "$dmg_file" ]; then
                    log_info "macOS DMG保存至: $dmg_file"
                fi
            else
                log_warning "hdiutil命令不可用，跳过DMG创建"
            fi
            
            # 清理临时目录
            rm -rf "$temp_dir"
        fi
        return 0
    else
        return 1
    fi
}

# 构建Flutter Windows
build_flutter_windows() {
    local output_dir="$1"
    
    log_info "开始构建Flutter Windows..."
    
    if flutter build windows --release --quiet; then
        local exe_dir="build/windows/runner/Release"
        if [ -d "$exe_dir" ]; then
            local dest_dir="$output_dir/hello-grpc-flutter-windows-${TIMESTAMP}"
            cp -r "$exe_dir" "$dest_dir"
            log_info "Windows应用保存至: $dest_dir/"
        fi
        return 0
    else
        return 1
    fi
}

# 构建Flutter Linux
build_flutter_linux() {
    local output_dir="$1"
    
    log_info "开始构建Flutter Linux..."
    
    if flutter build linux --release --quiet; then
        local app_dir="build/linux/x64/release/bundle"
        if [ -d "$app_dir" ]; then
            local dest_dir="$output_dir/hello-grpc-flutter-linux-${TIMESTAMP}"
            cp -r "$app_dir" "$dest_dir"
            log_info "Linux应用保存至: $dest_dir/"
        fi
        return 0
    else
        return 1
    fi
}

# 构建Tauri应用
build_tauri() {
    local platforms="$1"
    
    if [ ! -d "$TAURI_DIR" ]; then
        log_warning "Tauri项目目录不存在: $TAURI_DIR"
        return 1
    fi
    
    log_section "构建Tauri应用"
    
    cd "$TAURI_DIR"
    
    # 安装依赖
    log_info "安装Tauri依赖..."
    npm install --silent
    
    # 设置proto链接
    setup_proto_links
    
    # 检查Tauri CLI
    if ! command -v tauri &> /dev/null; then
        log_info "安装Tauri CLI..."
        npm install -g @tauri-apps/cli
    fi
    
    # 创建Tauri构建输出目录
    local tauri_build_dir="$BUILD_DIR/tauri"
    mkdir -p "$tauri_build_dir"
    
    local build_success=true
    local current_platforms=""
    
    # 确定要构建的平台
    if [ -n "$platforms" ]; then
        current_platforms="$platforms"
    else
        # 根据当前操作系统选择默认平台
        case "$OS" in
            macos) current_platforms="macos web" ;;
            linux) current_platforms="linux web" ;;
            windows) current_platforms="windows web" ;;
            *) current_platforms="web" ;;
        esac
    fi
    
    log_info "Tauri构建平台: $current_platforms"
    
    # 构建各个平台
    for platform in $current_platforms; do
        log_info "构建Tauri $platform 平台..."
        
        case "$platform" in
            windows)
                if [[ "$OS" == "windows" ]]; then
                    if build_tauri_windows "$tauri_build_dir"; then
                        log_success "Tauri Windows 构建成功"
                    else
                        log_error "Tauri Windows 构建失败"
                        FAILED_BUILDS+=("Tauri Windows")
                        build_success=false
                    fi
                else
                    log_warning "Windows构建仅支持Windows平台"
                fi
                ;;
            macos)
                if [[ "$OS" == "macos" ]]; then
                    if build_tauri_macos "$tauri_build_dir"; then
                        log_success "Tauri macOS 构建成功"
                    else
                        log_error "Tauri macOS 构建失败"
                        FAILED_BUILDS+=("Tauri macOS")
                        build_success=false
                    fi
                else
                    log_warning "macOS构建仅支持macOS平台"
                fi
                ;;
            linux)
                if [[ "$OS" == "linux" ]]; then
                    if build_tauri_linux "$tauri_build_dir"; then
                        log_success "Tauri Linux 构建成功"
                    else
                        log_error "Tauri Linux 构建失败"
                        FAILED_BUILDS+=("Tauri Linux")
                        build_success=false
                    fi
                else
                    log_warning "Linux构建仅支持Linux平台"
                fi
                ;;
            web)
                if build_tauri_web "$tauri_build_dir"; then
                    log_success "Tauri Web 构建成功"
                else
                    log_error "Tauri Web 构建失败"
                    FAILED_BUILDS+=("Tauri Web")
                    build_success=false
                fi
                ;;
            *)
                log_warning "不支持的Tauri平台: $platform"
                ;;
        esac
    done
    
    cd "$SCRIPT_DIR"
    
    if [ "$build_success" = true ]; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    fi
    return $([ "$build_success" = true ] && echo 0 || echo 1)
}

# 构建Tauri Windows
build_tauri_windows() {
    local output_dir="$1"
    
    log_info "开始构建Tauri Windows..."
    
    if tauri build --target x86_64-pc-windows-msvc --ci; then
        # 查找构建产物
        local bundle_dir="src-tauri/target/x86_64-pc-windows-msvc/release/bundle"
        if [ -d "$bundle_dir/msi" ]; then
            find "$bundle_dir/msi" -name "*.msi" | while read -r msi_file; do
                local dest_file="$output_dir/hello-grpc-tauri-windows-${TIMESTAMP}.msi"
                cp "$msi_file" "$dest_file"
                log_info "Windows MSI保存至: $dest_file"
            done
        fi
        return 0
    else
        return 1
    fi
}

# 构建Tauri macOS
build_tauri_macos() {
    local output_dir="$1"
    
    log_info "开始构建Tauri macOS..."
    
    if tauri build --ci; then
        # 查找构建产物
        local bundle_dir="src-tauri/target/release/bundle"
        if [ -d "$bundle_dir/dmg" ]; then
            find "$bundle_dir/dmg" -name "*.dmg" | while read -r dmg_file; do
                local dest_file="$output_dir/hello-grpc-tauri-macos-${TIMESTAMP}.dmg"
                cp "$dmg_file" "$dest_file"
                log_info "macOS DMG保存至: $dest_file"
            done
        fi
        if [ -d "$bundle_dir/macos" ]; then
            find "$bundle_dir/macos" -name "*.app" | while read -r app_file; do
                local dest_file="$output_dir/hello-grpc-tauri-macos-${TIMESTAMP}.app"
                cp -r "$app_file" "$dest_file"
                log_info "macOS APP保存至: $dest_file"
            done
        fi
        return 0
    else
        return 1
    fi
}

# 构建Tauri Linux
build_tauri_linux() {
    local output_dir="$1"
    
    log_info "开始构建Tauri Linux..."
    
    if tauri build --ci; then
        # 查找构建产物
        local bundle_dir="src-tauri/target/release/bundle"
        if [ -d "$bundle_dir/deb" ]; then
            find "$bundle_dir/deb" -name "*.deb" | while read -r deb_file; do
                local dest_file="$output_dir/hello-grpc-tauri-linux-${TIMESTAMP}.deb"
                cp "$deb_file" "$dest_file"
                log_info "Linux DEB保存至: $dest_file"
            done
        fi
        if [ -d "$bundle_dir/appimage" ]; then
            find "$bundle_dir/appimage" -name "*.AppImage" | while read -r appimage_file; do
                local dest_file="$output_dir/hello-grpc-tauri-linux-${TIMESTAMP}.AppImage"
                cp "$appimage_file" "$dest_file"
                log_info "Linux AppImage保存至: $dest_file"
            done
        fi
        return 0
    else
        return 1
    fi
}

# 构建Tauri Web
build_tauri_web() {
    local output_dir="$1"
    
    log_info "开始构建Tauri Web..."
    
    # 构建前端资源
    if npm run build --silent; then
        local dist_dir="dist"
        if [ -d "$dist_dir" ]; then
            local dest_dir="$output_dir/hello-grpc-tauri-web-${TIMESTAMP}"
            cp -r "$dist_dir" "$dest_dir"
            
            # 创建压缩包
            cd "$output_dir"
            tar -czf "hello-grpc-tauri-web-${TIMESTAMP}.tar.gz" "hello-grpc-tauri-web-${TIMESTAMP}"
            cd - > /dev/null
            
            log_info "Web应用保存至: $dest_dir/"
        fi
        return 0
    else
        return 1
    fi
}

# 构建Gateway应用
build_gateway() {
    if [ ! -d "$GATEWAY_DIR" ]; then
        log_warning "Gateway项目目录不存在: $GATEWAY_DIR"
        return 1
    fi
    
    log_section "构建Gateway应用"
    
    cd "$GATEWAY_DIR"
    
    # 创建Gateway构建输出目录
    local gateway_build_dir="$BUILD_DIR/gateway"
    mkdir -p "$gateway_build_dir"
    
    log_info "开始构建Gateway应用..."
    
    if go build -o "hello-grpc-gateway" .; then
        local dest_file="$gateway_build_dir/hello-grpc-gateway-${OS}-${TIMESTAMP}"
        if [[ "$OS" == "windows" ]]; then
            dest_file="${dest_file}.exe"
        fi
        
        mv "hello-grpc-gateway" "$dest_file" 2>/dev/null || cp "hello-grpc-gateway" "$dest_file"
        log_info "Gateway应用保存至: $dest_file"
        
        cd "$SCRIPT_DIR"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        return 0
    else
        cd "$SCRIPT_DIR"
        FAILED_BUILDS+=("Gateway")
        return 1
    fi
}

# 生成构建报告
generate_build_report() {
    local report_file="$BUILD_DIR/build_report.md"
    
    log_info "生成构建报告..."
    
    cat > "$report_file" << EOF
# Hello gRPC Apps 构建报告

**构建时间**: $BUILD_START_TIME - $BUILD_END_TIME
**构建类型**: $APP_TYPE
**构建平台**: ${PLATFORMS:-"自动选择"}
**操作系统**: $OS

## 构建摘要

- **成功构建**: $SUCCESS_COUNT/$TOTAL_COUNT
- **构建产物目录**: \`$BUILD_DIR/\`
- **时间戳**: $TIMESTAMP

## 构建产物汇总

| 应用类型 | 平台 | 文件类型 | 大小 | 构建包路径 |
|---------|------|----------|------|------------|
EOF

    # 遍历构建产物
    if [ -d "$BUILD_DIR" ]; then
        find "$BUILD_DIR" -type f -not -name "build_report.md" -not -name "build_info.txt" | while read -r file; do
            local relative_path="${file#$BUILD_DIR/}"
            local file_size=$(du -h "$file" | cut -f1)
            local app_type=$(echo "$relative_path" | cut -d'/' -f1)
            local filename=$(basename "$file")
            local platform="unknown"
            local filetype=$(echo "$filename" | grep -o '\.[^.]*$' | tr -d '.')
            
            # 推断平台
            case "$filename" in
                *android*) platform="Android" ;;
                *ios*) platform="iOS" ;;
                *web*) platform="Web" ;;
                *windows*) platform="Windows" ;;
                *macos*) platform="macOS" ;;
                *linux*) platform="Linux" ;;
            esac
            
            echo "| $app_type | $platform | $filetype | $file_size | \`$relative_path\` |" >> "$report_file"
        done
    fi

    # 添加失败的构建
    if [ ${#FAILED_BUILDS[@]} -gt 0 ]; then
        cat >> "$report_file" << EOF

## 构建失败

以下构建失败：
EOF
        for failed_build in "${FAILED_BUILDS[@]}"; do
            echo "- ❌ $failed_build" >> "$report_file"
        done
    fi

    cat >> "$report_file" << EOF

## 安装说明

### Android 安装
1. 开启"未知来源应用"安装权限
2. 直接安装APK文件：\`adb install xxx.apk\`

### iOS 安装  
1. 使用Xcode或第三方工具安装IPA/APP
2. 设备上信任开发者：设置 > 通用 > VPN与设备管理

### macOS 安装
1. 双击DMG文件挂载
2. 拖拽APP到应用程序文件夹
3. 如遇安全提示：系统偏好设置 > 安全性与隐私 > 允许

### Windows 安装
1. 双击MSI文件安装
2. 或解压ZIP文件直接运行EXE

### Linux 安装
1. DEB包：\`sudo dpkg -i xxx.deb\`
2. AppImage：\`chmod +x xxx.AppImage && ./xxx.AppImage\`

### Web 部署
1. 解压web压缩包到web服务器目录
2. 使用任意HTTP服务器提供静态文件服务

## 系统信息

\`\`\`
$(uname -a)
\`\`\`

## 工具版本

EOF

    # 添加工具版本信息
    if command -v flutter &> /dev/null; then
        echo "- **Flutter**: $(flutter --version | head -1)" >> "$report_file"
    fi
    if command -v node &> /dev/null; then
        echo "- **Node.js**: $(node --version)" >> "$report_file"
    fi
    if command -v cargo &> /dev/null; then
        echo "- **Rust**: $(rustc --version)" >> "$report_file"
    fi
    if command -v go &> /dev/null; then
        echo "- **Go**: $(go version)" >> "$report_file"
    fi

    echo "" >> "$report_file"
    echo "---" >> "$report_file"
    echo "*报告生成时间: $(date)*" >> "$report_file"
    
    log_success "构建报告已生成: $report_file"
}

# 清理构建产物
clean_build_artifacts() {
    log_info "清理之前的构建产物..."
    
    # 清理主构建目录
    rm -rf "$BUILD_DIR"
    
    # 清理Flutter构建产物
    if [ -d "$FLUTTER_DIR" ]; then
        cd "$FLUTTER_DIR"
        flutter clean 2>/dev/null || true
        rm -rf build/
        cd "$SCRIPT_DIR"
    fi
    
    # 清理Tauri构建产物
    if [ -d "$TAURI_DIR" ]; then
        cd "$TAURI_DIR"
        rm -rf src-tauri/target/ build_output/ dist/
        cd "$SCRIPT_DIR"
    fi
    
    log_success "清理完成"
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --clean)
            CLEAN=true
            shift
            ;;
        --debug)
            DEBUG=true
            shift
            ;;
        --ios-fix)
            IOS_FIX=true
            shift
            ;;
        --skip-deps)
            SKIP_DEPS_CHECK=true
            shift
            ;;
        --parallel)
            PARALLEL_BUILD=true
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        flutter|tauri|gateway|all)
            APP_TYPE="$1"
            shift
            ;;
        android|ios|web|windows|macos|linux)
            PLATFORMS="$PLATFORMS $1"
            shift
            ;;
        *)
            log_error "未知参数: $1"
            show_usage
            exit 1
            ;;
    esac
done

# 清理空格
PLATFORMS=$(echo "$PLATFORMS" | xargs)

# 主程序开始
log_section "Hello gRPC Apps 统一构建工具"
log_info "应用类型: $APP_TYPE"
if [ -n "$PLATFORMS" ]; then
    log_info "指定平台: $PLATFORMS"
else
    log_info "构建平台: 根据当前操作系统自动选择"
fi

if [ "$DEBUG" = true ]; then
    log_info "调试模式已启用"
fi

# 检测操作系统
detect_os

# 记录构建开始时间
BUILD_START_TIME=$(date)
log_info "构建开始时间: $BUILD_START_TIME"

# 清理之前的构建产物
if [ "$CLEAN" = true ]; then
    clean_build_artifacts
fi

# 检查必要工具
check_requirements

# iOS证书修复
if [ "$IOS_FIX" = true ]; then
    fix_ios_certificates
fi

# 创建构建目录
mkdir -p "$BUILD_DIR"

# 构建应用
case "$APP_TYPE" in
    flutter)
        TOTAL_COUNT=1
        build_flutter "$PLATFORMS"
        ;;
    tauri)
        TOTAL_COUNT=1
        build_tauri "$PLATFORMS"
        ;;
    gateway)
        TOTAL_COUNT=1
        build_gateway
        ;;
    all)
        TOTAL_COUNT=0
        if [ -d "$FLUTTER_DIR" ]; then
            TOTAL_COUNT=$((TOTAL_COUNT + 1))
            build_flutter "$PLATFORMS"
        fi
        if [ -d "$TAURI_DIR" ]; then
            TOTAL_COUNT=$((TOTAL_COUNT + 1))
            build_tauri "$PLATFORMS"
        fi
        if [ -d "$GATEWAY_DIR" ]; then
            TOTAL_COUNT=$((TOTAL_COUNT + 1))
            build_gateway
        fi
        ;;
esac

# 记录构建结束时间
BUILD_END_TIME=$(date)

# 生成构建报告
generate_build_report

# 构建摘要
log_section "构建摘要"
log_info "构建开始时间: $BUILD_START_TIME"
log_info "构建结束时间: $BUILD_END_TIME"
log_info "成功构建: $SUCCESS_COUNT/$TOTAL_COUNT"

if [ ${#FAILED_BUILDS[@]} -gt 0 ]; then
    log_warning "失败的构建:"
    for failed_build in "${FAILED_BUILDS[@]}"; do
        log_error "  - $failed_build"
    done
fi

if [ -d "$BUILD_DIR" ] && [ "$(ls -A $BUILD_DIR)" ]; then
    log_info "所有构建产物保存在: $BUILD_DIR/"
    
    # 显示构建产物
    find "$BUILD_DIR" -type f | while read -r file; do
        relative_path="${file#$BUILD_DIR/}"
        file_size=$(du -h "$file" | cut -f1)
        echo "  $relative_path ($file_size)"
    done
    
    # 创建构建信息文件
    cat > "$BUILD_DIR/build_info.txt" << EOF
Hello gRPC Apps 构建信息
========================

构建时间: $BUILD_START_TIME - $BUILD_END_TIME
应用类型: $APP_TYPE
构建平台: ${PLATFORMS:-"自动选择"}
成功构建: $SUCCESS_COUNT/$TOTAL_COUNT
操作系统: $OS

构建产物:
$(find "$BUILD_DIR" -type f | grep -v -E "(build_info.txt|build_report.md)" | while read -r file; do
    relative_path="${file#$BUILD_DIR/}"
    file_size=$(du -h "$file" | cut -f1)
    echo "  $relative_path ($file_size)"
done)

失败的构建:
$(for failed_build in "${FAILED_BUILDS[@]}"; do echo "  - $failed_build"; done)

系统信息:
$(uname -a)

工具版本:
EOF
    
    # 添加工具版本信息
    if command -v flutter &> /dev/null; then
        echo "Flutter: $(flutter --version | head -1)" >> "$BUILD_DIR/build_info.txt"
    fi
    if command -v node &> /dev/null; then
        echo "Node.js: $(node --version)" >> "$BUILD_DIR/build_info.txt"
    fi
    if command -v cargo &> /dev/null; then
        echo "Rust: $(rustc --version)" >> "$BUILD_DIR/build_info.txt"
    fi
    if command -v go &> /dev/null; then
        echo "Go: $(go version)" >> "$BUILD_DIR/build_info.txt"
    fi
fi

# 最终状态
if [ $SUCCESS_COUNT -eq $TOTAL_COUNT ] && [ $TOTAL_COUNT -gt 0 ]; then
    log_success "所有应用构建完成！"
    log_info "查看详细报告: $BUILD_DIR/build_report.md"
    exit 0
elif [ $SUCCESS_COUNT -gt 0 ]; then
    log_warning "部分应用构建成功 ($SUCCESS_COUNT/$TOTAL_COUNT)，请查看上述错误信息。"
    log_info "查看详细报告: $BUILD_DIR/build_report.md"
    exit 1
else
    log_error "所有应用构建失败，请查看上述错误信息。"
    exit 1
fi
