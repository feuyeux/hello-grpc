#!/bin/bash
cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit
set -e

# Function to display usage information
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -l, --language LANG   Run container for specific language (cpp, rust, java, go, csharp, python, nodejs, dart, kotlin, swift, php, ts)"
    echo "  -c, --component TYPE  Component to run (server, client). Required"
    echo "  -s, --secure          Use TLS/secure mode. Default is insecure"
    echo "  -x, --cross           Run in cross-language mode (only for client component)"
    echo "  -i, --ip              Use local IP address instead of hostname for client"
    echo "                       (Swift 客户端在 macOS 下必须加此参数，否则无法连接服务端)"
    echo "  -v, --verbose         Enable verbose output"
    echo "  -h, --help            Display this help message"
    echo
    echo "Examples:"
    echo "  $0 --language java --component server               # Run Java server in insecure mode"
    echo "  $0 --language go --component client --secure        # Run Go client in secure mode"
    echo "  $0 --language python --component client --cross     # Run Python client in cross-language mode"
    echo "  $0 --language rust --component client --ip          # Run Rust client using local IP address"
    echo "  $0 --language swift --component client --ip         # 【Swift 特殊】macOS 下必须加 --ip 参数"
    exit 1
}

# Initialize variables
LANGUAGE=""
COMPONENT=""
SECURE=false
CROSS=false
USE_IP=false
VERBOSE=false

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
    -s | --secure)
        SECURE=true
        shift
        ;;
    -x | --cross)
        CROSS=true
        shift
        ;;
    -i | --ip)
        USE_IP=true
        shift
        ;;
    -v | --verbose)
        VERBOSE=true
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

# Function to validate component
validate_component() {
    local valid_components=(server client base)
    for comp in "${valid_components[@]}"; do
        if [[ "$comp" == "$1" ]]; then
            return 0
        fi
    done
    echo "Error: Invalid component '$1'"
    echo "Valid components: ${valid_components[*]}"
    exit 1
}

# Function to get image name based on language and component
get_image_name() {
    local lang="$1"
    local comp="$2"

    # nodejs is special - the image name uses "node" instead of "nodejs"
    if [[ "$lang" == "nodejs" ]]; then
        echo "feuyeux/grpc_${comp}_node:1.0.0"
    else
        echo "feuyeux/grpc_${comp}_${lang}:1.0.0"
    fi
}

# Function to get container name based on language and component
get_container_name() {
    local lang="$1"
    local comp="$2"

    # nodejs is special - the container name uses "node" instead of "nodejs"
    if [[ "$lang" == "nodejs" ]]; then
        echo "grpc_${comp}_node"
    else
        echo "grpc_${comp}_${lang}"
    fi
}

run_base() {
    local lang="$1"
    local secure="$2"

    export NAME=$(get_container_name "$lang" "base")
    export IMG=$(get_image_name "$lang" "base")

    echo "Running $lang base ..."
    docker run -it --rm --name "$NAME" -p 9996:9996 "$IMG" bash

}

# Function to run server container
run_server() {
    local lang="$1"
    local secure="$2"

    # Set environment variables for the server
    export SERVER_NAME=$(get_container_name "$lang" "server")
    export SERVER_IMG=$(get_image_name "$lang" "server")

    echo "Running $lang server (secure=${secure})..."

    if [[ "$secure" == true ]]; then
        # Remove existing container if present to prevent name conflicts
        if docker ps -a --format '{{.Names}}' | grep -Eq "^${SERVER_NAME}$"; then
            echo "Removing existing container ${SERVER_NAME}..."
            docker rm -f "$SERVER_NAME"
        fi
        
        # Debug: Check certificates in the container first
        echo "Checking certificates in the container..."
        docker run --rm --entrypoint sh "$SERVER_IMG" -c "ls -la /var/hello_grpc/client_certs/ && echo '---' && cat /var/hello_grpc/client_certs/private.pkcs8.key 2>/dev/null || echo 'Private key file not found or not readable'"
        
        # Run secure server
        echo "SERVER_NAME=$SERVER_NAME SERVER_IMG=$SERVER_IMG"
        docker run --rm --name "$SERVER_NAME" -p 9996:9996 -e GRPC_HELLO_SECURE=Y "$SERVER_IMG"
    else
        # Remove existing container if present to prevent name conflicts
        if docker ps -a --format '{{.Names}}' | grep -Eq "^${SERVER_NAME}$"; then
            echo "Removing existing container ${SERVER_NAME}..."
            docker rm -f "$SERVER_NAME"
        fi
        # Run insecure server
        echo "SERVER_NAME=$SERVER_NAME SERVER_IMG=$SERVER_IMG"
        docker run --rm --name "$SERVER_NAME" -p 9996:9996 "$SERVER_IMG"
    fi
}

# Function to run client container
run_client() {
    local lang="$1"
    local secure="$2"
    local cross="$3"
    local use_ip="$4"

    # Set environment variables for the client
    export CLIENT_NAME=$(get_container_name "$lang" "client")
    export CLIENT_IMG=$(get_image_name "$lang" "client")

    # Set the server address
    local server_addr="host.docker.internal"
    # Swift 客户端在 macOS 下无法识别 host.docker.internal，需用本机 IP，否则连接会报 failedToParseIPString 错误。
    # 建议 Swift 客户端在 macOS 下使用 -i 参数（即 --ip），自动获取本机 en0 的 IP 地址。
    if [[ "$use_ip" == true ]]; then
        # Use local IP address if requested
        if command -v ipconfig &>/dev/null; then
            # macOS
            # Swift 客户端特殊性：必须用本机 IP 替代 host.docker.internal
            server_addr=$(ipconfig getifaddr en0)
        elif command -v ip &>/dev/null; then
            # Linux
            server_addr=$(ip route get 1 | awk '{print $7; exit}')
        fi
    elif [[ "$cross" == true ]]; then
        # For cross-language testing use localhost
        server_addr="localhost"
    fi

    echo "Running $lang client (secure=${secure}, cross=${cross}, server=$server_addr)..."

    if [[ "$cross" == true ]]; then
        # Run cross-language client
        echo "CLIENT_NAME=$CLIENT_NAME CLIENT_IMG=$CLIENT_IMG"
        docker run --rm --name "$CLIENT_NAME" --network="host" -e GRPC_SERVER="$server_addr" "$CLIENT_IMG"
    elif [[ "$secure" == true ]]; then
        # Run secure client
        echo "CLIENT_NAME=$CLIENT_NAME CLIENT_IMG=$CLIENT_IMG"
        docker run --rm --name "$CLIENT_NAME" -e GRPC_SERVER="$server_addr" -e GRPC_HELLO_SECURE=Y "$CLIENT_IMG"
    else
        # Run insecure client
        echo "CLIENT_NAME=$CLIENT_NAME CLIENT_IMG=$CLIENT_IMG"
        docker run --rm --name "$CLIENT_NAME" -e GRPC_SERVER="$server_addr" "$CLIENT_IMG"
    fi
}

echo "Check for required parameters"
if [[ -z "$LANGUAGE" ]]; then
    echo "Error: Language parameter is required"
    usage
fi

if [[ -z "$COMPONENT" ]]; then
    echo "Error: Component parameter is required"
    usage
fi

echo "Validate parameters"

validate_language "$LANGUAGE"
validate_component "$COMPONENT"

# Execute based on component type
if [[ "$COMPONENT" == "server" ]]; then
    if [[ "$CROSS" == true ]]; then
        echo "Warning: Cross-language mode is not applicable for server components. Ignoring --cross option."
    fi
    if [[ "$USE_IP" == true ]]; then
        echo "Warning: IP option is not applicable for server components. Ignoring --ip option."
    fi
    run_server "$LANGUAGE" "$SECURE"
elif [[ "$COMPONENT" == "base" ]]; then
    echo "hello"
    run_base "$LANGUAGE"
elif [[ "$COMPONENT" == "client" ]]; then
    run_client "$LANGUAGE" "$SECURE" "$CROSS" "$USE_IP"
else
    echo "Error: Unknown component type: $COMPONENT"
    usage
fi

echo "Container ran successfully"
