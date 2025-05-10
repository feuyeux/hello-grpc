#!/bin/bash
cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit
set -e # Removed -x for cleaner output, we'll add more targeted debugging

# Function to display usage information
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -l, --language LANG   Build specific language image (cpp, rust, java, go, csharp, python, nodejs, dart, kotlin, swift, php, ts)"
    echo "  -c, --component TYPE  Build specific component (server, client, both). Default: both"
    echo "  -a, --all             Build all language images"
    echo "  -p, --php-base        Build PHP base image only (prerequisite for PHP builds)"
    echo "  -v, --verbose         Enable verbose output"
    echo "  -h, --help            Display this help message"
    echo "  -j, --parallel        Enable parallel building (default: off)"
    echo
    echo "Examples:"
    echo "  $0 --all                        # Build all language images"
    echo "  $0 --language java              # Build Java images"
    echo "  $0 --language java --component server  # Build only Java server image"
    echo "  $0 --language php               # Build PHP images (requires PHP base to be built first)"
    echo "  $0 --php-base                   # Build only the PHP base image"
    echo "  $0 --all --parallel             # Build all language images in parallel"
    exit 1
}

# Initialize variables
BUILD_ALL=false
BUILD_PHP_BASE=false
LANGUAGE=""
COMPONENT="both"
VERBOSE=false
PARALLEL=false
# 用于并行构建的进程ID数组
PIDS=()

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
    -l | --language)
        LANGUAGE="$2"
        shift 2
        ;;
    -c | --component)
        COMPONENT="$2"
        shift 2
        ;;
    -a | --all)
        BUILD_ALL=true
        shift
        ;;
    -p | --php-base)
        BUILD_PHP_BASE=true
        shift
        ;;
    -v | --verbose)
        VERBOSE=true
        shift
        ;;
    -j | --parallel)
        PARALLEL=true
        shift
        ;;
    -h | --help)
        usage
        ;;
    *)
        echo "Unknown option: $1"
        usage
        ;;
    esac
done

# Set verbose mode if requested
if [[ "$VERBOSE" == true ]]; then
    set -x
fi

# 记录开始时间
start_time=$(date +%s)

# Check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        echo "Error: Docker does not appear to be running. Please start Docker and try again."
        exit 1
    else
        echo "Docker is running, proceeding with build..."
    fi
}

# Function to validate language
validate_language() {
    local valid_langs=(cpp rust java go csharp python nodejs dart kotlin swift php ts)
    for lang in "${valid_langs[@]}"; do
        if [[ "$lang" == "$1" ]]; then
            return 0
        fi
    done
    echo "Error: Invalid language '$1'"
    echo "Valid languages: ${valid_langs[*]}"
    exit 1
}

# Path to the project root directory (parent of docker)
PROJECT_ROOT="$(realpath ..)"

# 等待并行任务完成并显示结果
wait_for_parallel_jobs() {
    if [ ${#PIDS[@]} -eq 0 ]; then
        return
    fi
    
    echo "等待所有构建任务完成..."
    for pid in "${PIDS[@]}"; do
        if ! wait "$pid"; then
            echo "错误: 进程 $pid 构建失败!"
            # 可以选择在这里退出或继续
            # exit 1
        fi
    done
    # 清空PID数组
    PIDS=()
}

# Implementation of the PHP base build
build_php_base() {
    echo "==== Building PHP base image ===="
    check_docker

    # Build the PHP base image
    docker build -f php_grpc_base.dockerfile -t feuyeux/grpc_php_base:1.0.0 .

    # Verify the image was built correctly
    docker run -it --rm feuyeux/grpc_php_base:1.0.0 composer --version

    echo "PHP base image build completed successfully"
}

# Implementation of the CPP build - all compilation happens in the Dockerfile
build_cpp() {
    local component="$1"
    echo "==== Building C++ ($component) ===="

    check_docker

    # Build server component if requested
    if [[ "$component" == "server" || "$component" == "both" ]]; then
        echo "~~~ Building gRPC server C++ ~~~"
        docker build --no-cache -f cpp_grpc.dockerfile \
            --build-arg PROJECT_ROOT="${PROJECT_ROOT}" \
            --target server -t feuyeux/grpc_server_cpp:1.0.0 "${PROJECT_ROOT}"
    fi

    # Build client component if requested
    if [[ "$component" == "client" || "$component" == "both" ]]; then
        echo "~~~ Building gRPC client C++ ~~~"
        docker build --no-cache -f cpp_grpc.dockerfile \
            --build-arg PROJECT_ROOT="${PROJECT_ROOT}" \
            --target client -t feuyeux/grpc_client_cpp:1.0.0 "${PROJECT_ROOT}"
    fi

    echo "C++ build completed successfully"
}

# Implementation of the Rust build - all compilation happens in the Dockerfile
build_rust() {
    local component="$1"
    echo "==== Building Rust ($component) ===="

    check_docker

    if [[ "$component" == "base" ]]; then
        echo "~~~ Building gRPC server Rust ~~~"
        docker build --no-cache -f rust_grpc.dockerfile \
            --build-arg PROJECT_ROOT="${PROJECT_ROOT}" \
            --target build-base -t feuyeux/grpc_base_rust:1.0.0 "${PROJECT_ROOT}"
    fi

    # Build server component if requested
    if [[ "$component" == "server" || "$component" == "both" ]]; then
        echo "~~~ Building gRPC server Rust ~~~"
        docker build --no-cache -f rust_grpc.dockerfile \
            --build-arg PROJECT_ROOT="${PROJECT_ROOT}" \
            --target server -t feuyeux/grpc_server_rust:1.0.0 "${PROJECT_ROOT}"
    fi

    # Build client component if requested
    if [[ "$component" == "client" || "$component" == "both" ]]; then
        echo "~~~ Building gRPC client Rust ~~~"
        docker build --no-cache -f rust_grpc.dockerfile \
            --build-arg PROJECT_ROOT="${PROJECT_ROOT}" \
            --target client -t feuyeux/grpc_client_rust:1.0.0 "${PROJECT_ROOT}"
    fi

    echo "Rust build completed successfully"
}

# Implementation of the Java build - all compilation happens in the Dockerfile
build_java() {
    local component="$1"
    echo "==== Building Java ($component) ===="

    check_docker

    if [[ "$component" == "base" ]]; then
        docker build --no-cache -f java_grpc.dockerfile \
            --build-arg PROJECT_ROOT="${PROJECT_ROOT}" \
            --target build-base -t feuyeux/grpc_base_java:1.0.0 "${PROJECT_ROOT}"
        docker run -it --rm feuyeux/grpc_base_java:1.0.0 bash
    fi

    # Build server component if requested
    if [[ "$component" == "server" || "$component" == "both" ]]; then
        echo "~~~ Building gRPC server Java ~~~"
        docker build --no-cache -f java_grpc.dockerfile \
            --build-arg PROJECT_ROOT="${PROJECT_ROOT}" \
            --target server -t feuyeux/grpc_server_java:1.0.0 "${PROJECT_ROOT}"
    fi

    # Build client component if requested
    if [[ "$component" == "client" || "$component" == "both" ]]; then
        echo "~~~ Building gRPC client Java ~~~"
        docker build --no-cache -f java_grpc.dockerfile \
            --build-arg PROJECT_ROOT="${PROJECT_ROOT}" \
            --target client -t feuyeux/grpc_client_java:1.0.0 "${PROJECT_ROOT}"
    fi

    echo "Java build completed successfully"
}

# Implementation of the Go build - all compilation happens in the Dockerfile
build_go() {
    local component="$1"
    echo "==== Building Go ($component) ===="

    check_docker

    if [[ "$component" == "base" ]]; then
        docker build --no-cache -f go_grpc.dockerfile \
            --build-arg PROJECT_ROOT="${PROJECT_ROOT}" \
            --target build-base -t feuyeux/grpc_base_go:1.0.0 "${PROJECT_ROOT}"
        docker run -it --rm feuyeux/grpc_base_go:1.0.0 bash
    fi

    # Build server component if requested
    if [[ "$component" == "server" || "$component" == "both" ]]; then
        echo "~~~ Building gRPC server Go ~~~"
        docker build --no-cache -f go_grpc.dockerfile \
            --build-arg PROJECT_ROOT="${PROJECT_ROOT}" \
            --target server -t feuyeux/grpc_server_go:1.0.0 "${PROJECT_ROOT}"
    fi

    # Build client component if requested
    if [[ "$component" == "client" || "$component" == "both" ]]; then
        echo "~~~ Building gRPC client Go ~~~"
        docker build --no-cache -f go_grpc.dockerfile \
            --build-arg PROJECT_ROOT="${PROJECT_ROOT}" \
            --target client -t feuyeux/grpc_client_go:1.0.0 "${PROJECT_ROOT}"
    fi

    echo "Go build completed successfully"
}

# Implementation of the C# build - all compilation happens in the Dockerfile
build_csharp() {
    local component="$1"
    echo "==== Building C# ($component) ===="

    check_docker

    # Build server component if requested
    if [[ "$component" == "server" || "$component" == "both" ]]; then
        echo "~~~ Building gRPC server C# ~~~"
        docker build --no-cache -f csharp_grpc.dockerfile \
            --build-arg PROJECT_ROOT="${PROJECT_ROOT}" \
            --target server -t feuyeux/grpc_server_csharp:1.0.0 "${PROJECT_ROOT}"
    fi

    # Build client component if requested
    if [[ "$component" == "client" || "$component" == "both" ]]; then
        echo "~~~ Building gRPC client C# ~~~"
        docker build --no-cache -f csharp_grpc.dockerfile \
            --build-arg PROJECT_ROOT="${PROJECT_ROOT}" \
            --target client -t feuyeux/grpc_client_csharp:1.0.0 "${PROJECT_ROOT}"
    fi

    echo "C# build completed successfully"
}

# Implementation of the Python build - all compilation happens in the Dockerfile
build_python() {
    local component="$1"
    echo "==== Building Python ($component) ===="

    check_docker

    # Build server component if requested
    if [[ "$component" == "server" || "$component" == "both" ]]; then
        echo "~~~ Building gRPC server Python ~~~"
        docker build --no-cache -f python_grpc.dockerfile \
            --build-arg PROJECT_ROOT="${PROJECT_ROOT}" \
            --target server -t feuyeux/grpc_server_python:1.0.0 "${PROJECT_ROOT}"
    fi

    # Build client component if requested
    if [[ "$component" == "client" || "$component" == "both" ]]; then
        echo "~~~ Building gRPC client Python ~~~"
        docker build --no-cache -f python_grpc.dockerfile \
            --build-arg PROJECT_ROOT="${PROJECT_ROOT}" \
            --target client -t feuyeux/grpc_client_python:1.0.0 "${PROJECT_ROOT}"
    fi

    echo "Python build completed successfully"
}

# Implementation of the Node.js build - all compilation happens in the Dockerfile
build_nodejs() {
    local component="$1"
    echo "==== Building Node.js ($component) ===="

    check_docker

    # Build server component if requested
    if [[ "$component" == "server" || "$component" == "both" ]]; then
        echo "~~~ Building gRPC server Node.js ~~~"
        docker build --no-cache -f node_grpc.dockerfile \
            --build-arg PROJECT_ROOT="${PROJECT_ROOT}" \
            --target server -t feuyeux/grpc_server_node:1.0.0 "${PROJECT_ROOT}"
    fi

    # Build client component if requested
    if [[ "$component" == "client" || "$component" == "both" ]]; then
        echo "~~~ Building gRPC client Node.js ~~~"
        docker build --no-cache -f node_grpc.dockerfile \
            --build-arg PROJECT_ROOT="${PROJECT_ROOT}" \
            --target client -t feuyeux/grpc_client_node:1.0.0 "${PROJECT_ROOT}"
    fi

    echo "Node.js build completed successfully"
}

# Implementation of the Dart build - all compilation happens in the Dockerfile
build_dart() {
    local component="$1"
    echo "==== Building Dart ($component) ===="

    check_docker

    # Build server component if requested
    if [[ "$component" == "server" || "$component" == "both" ]]; then
        echo "~~~ Building gRPC server Dart ~~~"
        docker build --no-cache -f dart_grpc.dockerfile \
            --build-arg PROJECT_ROOT="${PROJECT_ROOT}" \
            --target server -t feuyeux/grpc_server_dart:1.0.0 "${PROJECT_ROOT}"
    fi

    # Build client component if requested
    if [[ "$component" == "client" || "$component" == "both" ]]; then
        echo "~~~ Building gRPC client Dart ~~~"
        docker build --no-cache -f dart_grpc.dockerfile \
            --build-arg PROJECT_ROOT="${PROJECT_ROOT}" \
            --target client -t feuyeux/grpc_client_dart:1.0.0 "${PROJECT_ROOT}"
    fi

    echo "Dart build completed successfully"
}

# Implementation of the Kotlin build - all compilation happens in the Dockerfile
build_kotlin() {
    local component="$1"
    echo "==== Building Kotlin ($component) ===="

    check_docker

    # Build server component if requested
    if [[ "$component" == "server" || "$component" == "both" ]]; then
        echo "~~~ Building gRPC server Kotlin ~~~"
        docker build --no-cache -f kotlin_grpc.dockerfile \
            --build-arg PROJECT_ROOT="${PROJECT_ROOT}" \
            --target server -t feuyeux/grpc_server_kotlin:1.0.0 "${PROJECT_ROOT}"
    fi

    # Build client component if requested
    if [[ "$component" == "client" || "$component" == "both" ]]; then
        echo "~~~ Building gRPC client Kotlin ~~~"
        docker build --no-cache -f kotlin_grpc.dockerfile \
            --build-arg PROJECT_ROOT="${PROJECT_ROOT}" \
            --target client -t feuyeux/grpc_client_kotlin:1.0.0 "${PROJECT_ROOT}"
    fi

    echo "Kotlin build completed successfully"
}

# Implementation of the Swift build - all compilation happens in the Dockerfile
build_swift() {
    local component="$1"
    echo "==== Building Swift ($component) ===="

    check_docker

    # Build server component if requested
    if [[ "$component" == "server" || "$component" == "both" ]]; then
        echo "~~~ Building gRPC server Swift ~~~"
        docker build --no-cache -f swift_grpc.dockerfile \
            --build-arg PROJECT_ROOT="${PROJECT_ROOT}" \
            --target server -t feuyeux/grpc_server_swift:1.0.0 "${PROJECT_ROOT}"
    fi

    # Build client component if requested
    if [[ "$component" == "client" || "$component" == "both" ]]; then
        echo "~~~ Building gRPC client Swift ~~~"
        docker build --no-cache -f swift_grpc.dockerfile \
            --build-arg PROJECT_ROOT="${PROJECT_ROOT}" \
            --target client -t feuyeux/grpc_client_swift:1.0.0 "${PROJECT_ROOT}"
    fi

    echo "Swift build completed successfully"
}

# Implementation of the PHP build - all compilation happens in the Dockerfile
build_php() {
    local component="$1"
    echo "==== Building PHP ($component) ===="

    # Check if the PHP base image exists
    if ! docker images | grep -q "feuyeux/grpc_php_base"; then
        echo "Warning: PHP base image not found. Building it now..."
        build_php_base
    fi

    check_docker

    # Build server component if requested
    if [[ "$component" == "server" || "$component" == "both" ]]; then
        echo "~~~ Building gRPC server PHP ~~~"
        docker build --no-cache -f php_grpc.dockerfile \
            --build-arg PROJECT_ROOT="${PROJECT_ROOT}" \
            --target server -t feuyeux/grpc_server_php:1.0.0 "${PROJECT_ROOT}"
    fi

    # Build client component if requested
    if [[ "$component" == "client" || "$component" == "both" ]]; then
        echo "~~~ Building gRPC client PHP ~~~"
        docker build --no-cache -f php_grpc.dockerfile \
            --build-arg PROJECT_ROOT="${PROJECT_ROOT}" \
            --target client -t feuyeux/grpc_client_php:1.0.0 "${PROJECT_ROOT}"
    fi

    echo "PHP build completed successfully"
}

# Implementation of the TypeScript build - all compilation happens in the Dockerfile
build_ts() {
    local component="$1"
    echo "==== Building TypeScript ($component) ===="

    check_docker

    # Build server component if requested
    if [[ "$component" == "server" || "$component" == "both" ]]; then
        echo "~~~ Building gRPC server TypeScript ~~~"
        docker build --no-cache -f ts_grpc.dockerfile \
            --build-arg PROJECT_ROOT="${PROJECT_ROOT}" \
            --target server -t feuyeux/grpc_server_ts:1.0.0 "${PROJECT_ROOT}"
    fi

    # Build client component if requested
    if [[ "$component" == "client" || "$component" == "both" ]]; then
        echo "~~~ Building gRPC client TypeScript ~~~"
        docker build --no-cache -f ts_grpc.dockerfile \
            --build-arg PROJECT_ROOT="${PROJECT_ROOT}" \
            --target client -t feuyeux/grpc_client_ts:1.0.0 "${PROJECT_ROOT}"
    fi

    echo "TypeScript build completed successfully"
}

# Build PHP base image if requested
if [[ "$BUILD_PHP_BASE" == true ]]; then
    echo "Building PHP base image..."
    build_php_base
    # Exit after building PHP base if that's all that was requested
    if [[ -z "$LANGUAGE" && "$BUILD_ALL" == false ]]; then
        echo "PHP base image build completed. Exiting..."
        exit 0
    fi
fi

# Function to run a specific language build
run_language_build() {
    local lang="$1"
    local component="$2"
    local parallel="$3"

    echo "=== Building $lang ($component) ==="

    # Check if Docker is running before proceeding
    check_docker

    # Set a timeout for the Docker build command (30 minutes)
    export DOCKER_CLIENT_TIMEOUT=1800
    export COMPOSE_HTTP_TIMEOUT=1800

    # 用于捕获执行状态的函数
    build_with_status() {
        local lang=$1
        local component=$2
        
        # 创建日志目录
        mkdir -p build_logs
        
        # Build based on the language
        case "$lang" in
        cpp)
            build_cpp "$component" > build_logs/cpp.log 2>&1
            ;;
        rust)
            build_rust "$component" > build_logs/rust.log 2>&1
            ;;
        java)
            build_java "$component" > build_logs/java.log 2>&1
            ;;
        go)
            build_go "$component" > build_logs/go.log 2>&1
            ;;
        csharp)
            build_csharp "$component" > build_logs/csharp.log 2>&1
            ;;
        python)
            build_python "$component" > build_logs/python.log 2>&1
            ;;
        nodejs)
            build_nodejs "$component" > build_logs/nodejs.log 2>&1
            ;;
        dart)
            build_dart "$component" > build_logs/dart.log 2>&1
            ;;
        kotlin)
            build_kotlin "$component" > build_logs/kotlin.log 2>&1
            ;;
        swift)
            build_swift "$component" > build_logs/swift.log 2>&1
            ;;
        php)
            build_php "$component" > build_logs/php.log 2>&1
            ;;
        ts)
            build_ts "$component" > build_logs/ts.log 2>&1
            ;;
        *)
            echo "Error: Unsupported language: $lang"
            return 1
            ;;
        esac
        
        # 检查构建状态
        local status=$?
        if [ $status -eq 0 ]; then
            echo "=== Completed building $lang ($component) ==="
        else
            echo "=== Failed building $lang ($component), see build_logs/$lang.log for details ==="
        fi
        return $status
    }

    # 执行构建任务
    if [[ "$parallel" == "true" ]]; then
        # 并行模式: 启动后台任务
        build_with_status "$lang" "$component" &
        PIDS+=($!)
    else
        # 顺序模式: 直接执行
        case "$lang" in
        cpp)
            build_cpp "$component"
            ;;
        rust)
            build_rust "$component"
            ;;
        java)
            build_java "$component"
            ;;
        go)
            build_go "$component"
            ;;
        csharp)
            build_csharp "$component"
            ;;
        python)
            build_python "$component"
            ;;
        nodejs)
            build_nodejs "$component"
            ;;
        dart)
            build_dart "$component"
            ;;
        kotlin)
            build_kotlin "$component"
            ;;
        swift)
            build_swift "$component"
            ;;
        php)
            build_php "$component"
            ;;
        ts)
            build_ts "$component"
            ;;
        *)
            echo "Error: Unsupported language: $lang"
            exit 1
            ;;
        esac
        echo "=== Completed building $lang ($component) ==="
    fi
    echo
}

# Build all languages
build_all_languages() {
    local component="$1"
    local parallel="$2"
    local langs=(cpp rust java go csharp python nodejs dart kotlin swift php ts)

    if [[ "$parallel" == "true" ]]; then
        echo "开始并行构建所有语言镜像..."
        for lang in "${langs[@]}"; do
            run_language_build "$lang" "$component" "true"
        done
        # 等待所有并行任务完成
        wait_for_parallel_jobs
    else
        echo "开始顺序构建所有语言镜像..."
        for lang in "${langs[@]}"; do
            run_language_build "$lang" "$component" "false"
        done
    fi
}

# Main execution logic
if [[ "$BUILD_ALL" == true ]]; then
    echo "Building all language images..."
    build_all_languages "$COMPONENT" "$PARALLEL"
elif [[ -n "$LANGUAGE" ]]; then
    validate_language "$LANGUAGE"
    run_language_build "$LANGUAGE" "$COMPONENT" "$PARALLEL"
else
    # If no specific option was chosen, show usage
    if [[ "$BUILD_PHP_BASE" == false ]]; then
        usage
    fi
fi

# 计算总耗时
end_time=$(date +%s)
duration=$((end_time - start_time))
echo "Build process completed successfully."
echo "总耗时: ${duration}秒"
