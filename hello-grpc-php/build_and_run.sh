#!/bin/bash
# 构建和运行 PHP gRPC Docker 容器
# 此脚本封装了使用 build_image.sh 来构建 PHP gRPC 镜像，并运行容器的过程

cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/.." || exit

# 显示帮助信息
show_help() {
    echo "使用方法: $0 [选项]"
    echo "选项:"
    echo "  -h, --help        显示帮助信息"
    echo "  -b, --build       构建 PHP gRPC 镜像"
    echo "  -r, --run         运行 PHP gRPC 容器"
    echo "  -s, --server      只操作服务器（默认：同时操作服务器和客户端）"
    echo "  -c, --client      只操作客户端（默认：同时操作服务器和客户端）"
    echo "  -t, --tls         启用 TLS 加密通信"
    echo "  -n, --network     创建自定义 Docker 网络（默认：hello-grpc-net）"
    exit 0
}

# 初始化变量
BUILD_MODE=false
RUN_MODE=false
COMPONENT="both"
USE_TLS=false
CREATE_NETWORK=false
NETWORK_NAME="hello-grpc-net"

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case "$1" in
    -h|--help)
        show_help
        ;;
    -b|--build)
        BUILD_MODE=true
        shift
        ;;
    -r|--run)
        RUN_MODE=true
        shift
        ;;
    -s|--server)
        COMPONENT="server"
        shift
        ;;
    -c|--client)
        COMPONENT="client"
        shift
        ;;
    -t|--tls)
        USE_TLS=true
        shift
        ;;
    -n|--network)
        CREATE_NETWORK=true
        shift
        if [[ $# -gt 0 && ! "$1" =~ ^- ]]; then
            NETWORK_NAME="$1"
            shift
        fi
        ;;
    *)
        echo "未知选项: $1"
        show_help
        ;;
    esac
done

# 如果没有指定模式，默认同时构建和运行
if [[ "$BUILD_MODE" == "false" && "$RUN_MODE" == "false" ]]; then
    BUILD_MODE=true
    RUN_MODE=true
fi

# 构建 PHP gRPC 镜像
if [[ "$BUILD_MODE" == "true" ]]; then
    echo "==== 构建 PHP gRPC 镜像 ===="
    
    # 构建 PHP gRPC 基础镜像
    echo "构建 PHP gRPC 基础镜像..."
    cd docker || exit
    ./build_image.sh --php-base
    
    # 构建 PHP gRPC 服务/客户端镜像
    if [[ "$COMPONENT" == "both" || "$COMPONENT" == "server" ]]; then
        echo "构建 PHP gRPC 服务器镜像..."
        ./build_image.sh --language php --component server
    fi
    
    if [[ "$COMPONENT" == "both" || "$COMPONENT" == "client" ]]; then
        echo "构建 PHP gRPC 客户端镜像..."
        ./build_image.sh --language php --component client
    fi
    
    cd ..
fi

# 运行 PHP gRPC 容器
if [[ "$RUN_MODE" == "true" ]]; then
    echo "==== 运行 PHP gRPC 容器 ===="
    
    # 创建自定义网络（如果需要）
    if [[ "$CREATE_NETWORK" == "true" ]]; then
        echo "创建 Docker 网络: $NETWORK_NAME"
        if ! docker network inspect "$NETWORK_NAME" &>/dev/null; then
            docker network create "$NETWORK_NAME"
        else
            echo "网络 $NETWORK_NAME 已存在"
        fi
        NETWORK_OPTION="--network $NETWORK_NAME"
    else
        NETWORK_OPTION=""
    fi
    
    # 设置 TLS 环境变量
    if [[ "$USE_TLS" == "true" ]]; then
        TLS_ENV="-e GRPC_HELLO_SECURE=Y"
    else
        TLS_ENV="-e GRPC_HELLO_SECURE=N"
    fi
    
    # 运行服务器
    if [[ "$COMPONENT" == "both" || "$COMPONENT" == "server" ]]; then
        echo "运行 PHP gRPC 服务器..."
        docker run -d --name php-grpc-server \
            $NETWORK_OPTION \
            -p 9996:9996 \
            -e GRPC_SERVER_PORT=9996 \
            $TLS_ENV \
            feuyeux/grpc_server_php:1.0.0
            
        echo "PHP gRPC 服务器已启动，端口: 9996"
    fi
    
    # 等待服务器启动
    if [[ "$COMPONENT" == "both" ]]; then
        echo "等待服务器启动..."
        sleep 2
    fi
    
    # 运行客户端
    if [[ "$COMPONENT" == "both" || "$COMPONENT" == "client" ]]; then
        echo "运行 PHP gRPC 客户端..."
        if [[ "$COMPONENT" == "both" ]]; then
            SERVER_HOST="php-grpc-server"
        else
            SERVER_HOST="localhost"
        fi
        
        docker run -it --rm \
            $NETWORK_OPTION \
            -e GRPC_SERVER="$SERVER_HOST" \
            -e GRPC_SERVER_PORT=9996 \
            $TLS_ENV \
            feuyeux/grpc_client_php:1.0.0
    fi
fi

echo "完成!"
