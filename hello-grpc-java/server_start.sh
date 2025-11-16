#!/usr/bin/env bash
# gRPC Java Server 启动脚本
# 支持多平台、多配置选项和健壮的错误处理

set -euo pipefail  # 严格模式：遇到错误立即退出，未定义变量报错，管道错误传播

# 脚本信息
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_PATH="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd -P)"

# 颜色输出
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# 默认配置
DEFAULT_ADDR="127.0.0.1:9996"
DEFAULT_LOG_LEVEL="info"
DEFAULT_PROFILE="dev"

# 全局变量
JAVA_HOME_DETECTED=""
MAVEN_HOME_DETECTED=""
USE_TLS=false
SERVER_ADDR="$DEFAULT_ADDR"
LOG_LEVEL="$DEFAULT_LOG_LEVEL"
PROFILE="$DEFAULT_PROFILE"
CLEAN_BUILD=false
SKIP_BUILD=false
BACKGROUND=false
DEBUG_MODE=false
VERBOSE=false
ADDITIONAL_JVM_ARGS=""
ADDITIONAL_EXEC_ARGS=""

# 日志函数
log_debug() {
    [[ "$VERBOSE" == "true" ]] && echo -e "${PURPLE}[DEBUG]${NC} $*" >&2
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_fatal() {
    echo -e "${RED}[FATAL]${NC} $*" >&2
    exit 1
}

# 显示脚本信息
show_banner() {
    cat << EOF
${CYAN}
╔══════════════════════════════════════════════════════════════╗
║                    gRPC Java Server                         ║
║                    Version: $SCRIPT_VERSION                        ║
╚══════════════════════════════════════════════════════════════╝
${NC}
EOF
}

# 显示帮助信息
show_help() {
    cat << EOF
${CYAN}gRPC Java Server 启动脚本${NC}

用法: $SCRIPT_NAME [选项]

${YELLOW}服务器选项:${NC}
  --addr=HOST:PORT          服务器地址 (默认: $DEFAULT_ADDR)
  --tls                     启用 TLS 加密通信
  --log=LEVEL              日志级别 (trace|debug|info|warn|error, 默认: $DEFAULT_LOG_LEVEL)
  --profile=PROFILE        运行配置 (dev|prod|test, 默认: $DEFAULT_PROFILE)

${YELLOW}构建选项:${NC}
  --clean                  清理构建
  --skip-build             跳过构建步骤
  --rebuild                强制重新构建

${YELLOW}运行选项:${NC}
  --background, -b         后台运行
  --debug                  启用调试模式 (端口 5005)
  --jvm-args=ARGS          额外的 JVM 参数
  --server-args=ARGS       额外的服务器参数

${YELLOW}其他选项:${NC}
  --verbose, -v            详细输出
  --version                显示版本信息
  --help, -h               显示此帮助信息

${YELLOW}环境变量:${NC}
  JAVA_HOME               Java 安装路径
  MAVEN_HOME              Maven 安装路径
  GRPC_HELLO_SECURE       设置为 'Y' 启用 TLS (等同于 --tls)
  GRPC_SERVER_ADDR        默认服务器地址
  GRPC_LOG_LEVEL          默认日志级别

${YELLOW}示例:${NC}
  $SCRIPT_NAME                                    # 使用默认配置启动
  $SCRIPT_NAME --addr=0.0.0.0:8080 --tls        # 指定地址和启用TLS
  $SCRIPT_NAME --clean --profile=prod           # 清理构建并使用生产配置
  $SCRIPT_NAME --debug --verbose                # 调试模式和详细输出
  $SCRIPT_NAME --background --log=debug         # 后台运行并启用调试日志
EOF
}

# 显示版本信息
show_version() {
    echo "$SCRIPT_NAME version $SCRIPT_VERSION"
}

# 检测操作系统
detect_os() {
    case "$(uname -s)" in
        Darwin*)
            echo "macos"
            ;;
        Linux*)
            echo "linux"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            echo "windows"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# 自动检测 Java 安装路径
detect_java_home() {
    local os_type
    os_type=$(detect_os)
    
    log_debug "检测操作系统: $os_type"
    
    # 如果已设置 JAVA_HOME 环境变量，优先使用
    if [[ -n "${JAVA_HOME:-}" ]] && [[ -d "$JAVA_HOME" ]]; then
        JAVA_HOME_DETECTED="$JAVA_HOME"
        log_debug "使用环境变量 JAVA_HOME: $JAVA_HOME_DETECTED"
        return 0
    fi
    
    case "$os_type" in
        "macos")
            # macOS 检测顺序
            local macos_paths=(
                "/Library/Java/JavaVirtualMachines/openjdk-21.jdk/Contents/Home"
                "/Library/Java/JavaVirtualMachines/openjdk-17.jdk/Contents/Home"
                "/Library/Java/JavaVirtualMachines/openjdk-11.jdk/Contents/Home"
            )
            
            # 尝试使用 java_home 工具
            if command -v /usr/libexec/java_home >/dev/null 2>&1; then
                local java_home_tool
                java_home_tool=$(/usr/libexec/java_home 2>/dev/null || true)
                if [[ -n "$java_home_tool" ]] && [[ -d "$java_home_tool" ]]; then
                    JAVA_HOME_DETECTED="$java_home_tool"
                    log_debug "通过 java_home 工具检测到: $JAVA_HOME_DETECTED"
                    return 0
                fi
            fi
            
            # 检查常见路径
            for path in "${macos_paths[@]}"; do
                if [[ -d "$path" ]]; then
                    JAVA_HOME_DETECTED="$path"
                    log_debug "检测到 macOS Java 路径: $JAVA_HOME_DETECTED"
                    return 0
                fi
            done
            ;;
            
        "linux")
            # Linux 检测顺序 - 优先使用 Java 21
            local linux_paths=(
                "/usr/lib/jvm/java-21-openjdk-amd64"
                "/usr/lib/jvm/java-21-openjdk"
                "/usr/lib/jvm/java-17-openjdk-amd64"
                "/usr/lib/jvm/java-17-openjdk"
                "/usr/lib/jvm/default-java"
                "/usr/lib/jvm/java-11-openjdk-amd64"
                "/usr/lib/jvm/java-11-openjdk"
                "/opt/java/openjdk"
                "/usr/java/latest"
            )
            
            for path in "${linux_paths[@]}"; do
                if [[ -d "$path" ]]; then
                    JAVA_HOME_DETECTED="$path"
                    log_debug "检测到 Linux Java 路径: $JAVA_HOME_DETECTED"
                    return 0
                fi
            done
            ;;
            
        "windows")
            # Windows 检测顺序
            local windows_paths=(
                "D:/zoo/jdk-24.0.1"
                "C:/Program Files/Java/jdk-21"
                "C:/Program Files/Java/jdk-17"
                "C:/Program Files/Java/jdk-11"
                "C:/Program Files/OpenJDK/jdk-21"
                "C:/Program Files/OpenJDK/jdk-17"
            )
            
            for path in "${windows_paths[@]}"; do
                if [[ -d "$path" ]]; then
                    JAVA_HOME_DETECTED="$path"
                    log_debug "检测到 Windows Java 路径: $JAVA_HOME_DETECTED"
                    return 0
                fi
            done
            ;;
    esac
    
    # 最后尝试通过 java 命令检测
    if command -v java >/dev/null 2>&1; then
        local java_path
        java_path=$(readlink -f "$(command -v java)" 2>/dev/null || command -v java)
        if [[ -n "$java_path" ]]; then
            # 从 java 可执行文件路径推导 JAVA_HOME
            JAVA_HOME_DETECTED="${java_path%/bin/java}"
            if [[ -d "$JAVA_HOME_DETECTED" ]]; then
                log_debug "通过 java 命令检测到: $JAVA_HOME_DETECTED"
                return 0
            fi
        fi
    fi
    
    return 1
}

# 自动检测 Maven 安装路径
detect_maven_home() {
    local os_type
    os_type=$(detect_os)
    
    # 如果已设置 MAVEN_HOME 环境变量，优先使用
    if [[ -n "${MAVEN_HOME:-}" ]] && [[ -d "$MAVEN_HOME" ]]; then
        MAVEN_HOME_DETECTED="$MAVEN_HOME"
        log_debug "使用环境变量 MAVEN_HOME: $MAVEN_HOME_DETECTED"
        return 0
    fi
    
    case "$os_type" in
        "linux")
            local linux_maven_paths=(
                "/usr/share/maven"
                "/opt/maven"
                "/usr/local/maven"
            )
            
            for path in "${linux_maven_paths[@]}"; do
                if [[ -d "$path" ]]; then
                    MAVEN_HOME_DETECTED="$path"
                    log_debug "检测到 Linux Maven 路径: $MAVEN_HOME_DETECTED"
                    return 0
                fi
            done
            ;;
            
        "macos")
            local macos_maven_paths=(
                "/usr/local/Cellar/maven"
                "/opt/homebrew/Cellar/maven"
                "/usr/local/maven"
            )
            
            for path in "${macos_maven_paths[@]}"; do
                if [[ -d "$path" ]]; then
                    # Homebrew 安装的 Maven 可能有版本号目录
                    if [[ -d "$path" ]] && [[ ! -f "$path/bin/mvn" ]]; then
                        local version_dir
                        version_dir=$(find "$path" -maxdepth 1 -type d -name "*.*.*" | head -1)
                        if [[ -n "$version_dir" ]] && [[ -f "$version_dir/bin/mvn" ]]; then
                            path="$version_dir"
                        fi
                    fi
                    
                    if [[ -f "$path/bin/mvn" ]]; then
                        MAVEN_HOME_DETECTED="$path"
                        log_debug "检测到 macOS Maven 路径: $MAVEN_HOME_DETECTED"
                        return 0
                    fi
                fi
            done
            ;;
    esac
    
    # 通过 mvn 命令检测
    if command -v mvn >/dev/null 2>&1; then
        local mvn_path
        mvn_path=$(readlink -f "$(command -v mvn)" 2>/dev/null || command -v mvn)
        if [[ -n "$mvn_path" ]]; then
            MAVEN_HOME_DETECTED="${mvn_path%/bin/mvn}"
            if [[ -d "$MAVEN_HOME_DETECTED" ]]; then
                log_debug "通过 mvn 命令检测到: $MAVEN_HOME_DETECTED"
                return 0
            fi
        fi
    fi
    
    return 1
}

# 验证 Java 环境
validate_java() {
    log_info "验证 Java 环境..."
    
    if ! detect_java_home; then
        log_fatal "无法检测到 Java 安装路径。请安装 Java 或设置 JAVA_HOME 环境变量。"
    fi
    
    export JAVA_HOME="$JAVA_HOME_DETECTED"
    
    # 验证 Java 可执行文件
    local java_exec="$JAVA_HOME/bin/java"
    if [[ ! -x "$java_exec" ]]; then
        log_fatal "Java 可执行文件不存在或无执行权限: $java_exec"
    fi
    
    # 检查 Java 版本
    local java_version
    java_version=$("$java_exec" -version 2>&1 | head -1 | cut -d'"' -f2)
    log_success "Java 环境验证成功: $java_version"
    log_info "JAVA_HOME: $JAVA_HOME"
}

# 验证 Maven 环境
validate_maven() {
    log_info "验证 Maven 环境..."
    
    if detect_maven_home; then
        export MAVEN_HOME="$MAVEN_HOME_DETECTED"
        log_info "MAVEN_HOME: $MAVEN_HOME"
    fi
    
    # 验证 Maven 可执行文件
    if ! command -v mvn >/dev/null 2>&1; then
        log_fatal "Maven 未安装或不在 PATH 中。请安装 Maven。"
    fi
    
    # 检查 Maven 版本
    local maven_version
    maven_version=$(mvn -version 2>/dev/null | head -1 | cut -d' ' -f3)
    log_success "Maven 环境验证成功: $maven_version"
}

# 验证项目结构
validate_project() {
    log_info "验证项目结构..."
    
    cd "$SCRIPT_PATH" || log_fatal "无法进入脚本目录: $SCRIPT_PATH"
    
    # 检查必要文件
    local required_files=("pom.xml" "build.sh")
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_fatal "缺少必要文件: $file"
        fi
    done
    
    log_success "项目结构验证成功"
}

# 构建项目
build_project() {
    if [[ "$SKIP_BUILD" == "true" ]]; then
        log_info "跳过构建步骤"
        return 0
    fi
    
    log_info "构建项目..."
    
    local build_args=()
    
    if [[ "$CLEAN_BUILD" == "true" ]]; then
        build_args+=("--clean")
        log_info "执行清理构建"
    fi
    
    # build.sh 不支持 --verbose 参数，所以不传递
    
    # 执行构建
    if ! bash build.sh "${build_args[@]}"; then
        log_fatal "项目构建失败"
    fi
    
    log_success "项目构建成功"
}

# 构建 Maven 命令
build_maven_command() {
    local cmd="mvn exec:java"
    local jvm_args=()
    local exec_args=()
    
    # 主类
    cmd+=" -Dexec.mainClass=\"org.feuyeux.grpc.server.ProtoServer\""
    
    # JVM 参数
    if [[ "$DEBUG_MODE" == "true" ]]; then
        jvm_args+=("-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005")
        log_info "调试模式已启用，调试端口: 5005"
    fi
    
    # 添加额外的 JVM 参数
    if [[ -n "$ADDITIONAL_JVM_ARGS" ]]; then
        jvm_args+=("$ADDITIONAL_JVM_ARGS")
    fi
    
    # 服务器参数
    if [[ "$SERVER_ADDR" != "$DEFAULT_ADDR" ]]; then
        exec_args+=("--addr=$SERVER_ADDR")
    fi
    
    if [[ "$LOG_LEVEL" != "$DEFAULT_LOG_LEVEL" ]]; then
        exec_args+=("--log=$LOG_LEVEL")
    fi
    
    if [[ "$PROFILE" != "$DEFAULT_PROFILE" ]]; then
        exec_args+=("--profile=$PROFILE")
    fi
    
    # 添加额外的执行参数
    if [[ -n "$ADDITIONAL_EXEC_ARGS" ]]; then
        exec_args+=("$ADDITIONAL_EXEC_ARGS")
    fi
    
    # 组装 JVM 参数
    if [[ ${#jvm_args[@]} -gt 0 ]]; then
        local jvm_args_str
        jvm_args_str=$(printf " %s" "${jvm_args[@]}")
        cmd+=" -Dexec.args=\"$jvm_args_str\""
    fi
    
    # 组装执行参数
    if [[ ${#exec_args[@]} -gt 0 ]]; then
        local exec_args_str
        exec_args_str=$(printf " %s" "${exec_args[@]}")
        if [[ -n "${jvm_args[*]}" ]]; then
            cmd="${cmd%\"} $exec_args_str\""
        else
            cmd+=" -Dexec.args=\"$exec_args_str\""
        fi
    fi
    
    echo "$cmd"
}

# 启动服务器
start_server() {
    log_info "启动 gRPC 服务器..."
    
    # 设置环境变量
    if [[ "$USE_TLS" == "true" ]]; then
        export GRPC_HELLO_SECURE=Y
        log_info "TLS 加密已启用"
    fi
    
    # 构建命令
    local cmd
    cmd=$(build_maven_command)
    
    log_info "服务器地址: $SERVER_ADDR"
    log_info "日志级别: $LOG_LEVEL"
    log_info "运行配置: $PROFILE"
    log_info "TLS 加密: $([ "$USE_TLS" == "true" ] && echo "启用" || echo "禁用")"
    
    if [[ "$VERBOSE" == "true" ]]; then
        log_debug "执行命令: $cmd"
    fi
    
    log_success "gRPC 服务器启动中..."
    
    # 执行命令
    if [[ "$BACKGROUND" == "true" ]]; then
        log_info "后台模式启动服务器"
        eval "$cmd" &
        local pid=$!
        echo "$pid" > "$SCRIPT_PATH/server.pid"
        log_success "服务器已在后台启动，PID: $pid"
        log_info "使用 'kill $pid' 或 'pkill -f ProtoServer' 停止服务器"
    else
        eval "$cmd"
    fi
}

# 解析命令行参数
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --addr=*)
                SERVER_ADDR="${1#*=}"
                shift
                ;;
            --tls)
                USE_TLS=true
                shift
                ;;
            --log=*)
                LOG_LEVEL="${1#*=}"
                shift
                ;;
            --profile=*)
                PROFILE="${1#*=}"
                shift
                ;;
            --clean)
                CLEAN_BUILD=true
                shift
                ;;
            --skip-build)
                SKIP_BUILD=true
                shift
                ;;
            --rebuild)
                CLEAN_BUILD=true
                shift
                ;;
            --background|-b)
                BACKGROUND=true
                shift
                ;;
            --debug)
                DEBUG_MODE=true
                shift
                ;;
            --jvm-args=*)
                ADDITIONAL_JVM_ARGS="${1#*=}"
                shift
                ;;
            --server-args=*)
                ADDITIONAL_EXEC_ARGS="${1#*=}"
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --version)
                show_version
                exit 0
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                echo "使用 --help 查看帮助信息"
                exit 1
                ;;
        esac
    done
}

# 处理环境变量
process_environment() {
    # 从环境变量读取配置
    if [[ -n "${GRPC_HELLO_SECURE:-}" ]] && [[ "${GRPC_HELLO_SECURE}" == "Y" ]]; then
        USE_TLS=true
    fi
    
    if [[ -n "${GRPC_SERVER_ADDR:-}" ]]; then
        SERVER_ADDR="$GRPC_SERVER_ADDR"
    fi
    
    if [[ -n "${GRPC_LOG_LEVEL:-}" ]]; then
        LOG_LEVEL="$GRPC_LOG_LEVEL"
    fi
}

# 信号处理
setup_signal_handlers() {
    trap 'log_info "收到中断信号，正在停止服务器..."; exit 0' INT TERM
}

# 主函数
main() {
    # 设置信号处理
    setup_signal_handlers
    
    # 显示横幅
    show_banner
    
    # 解析命令行参数
    parse_arguments "$@"
    
    # 处理环境变量
    process_environment
    
    # 验证环境
    validate_java
    validate_maven
    validate_project
    
    # 构建项目
    build_project
    
    # 启动服务器
    start_server
}

# 运行主函数
main "$@"