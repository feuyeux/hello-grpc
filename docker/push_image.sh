#!/bin/bash
# Universal push script for hello-grpc project
# Usage: ./push_image.sh [language]
# If no language specified, push all images

set -e

LANGUAGES=("java" "cpp" "csharp" "dart" "go" "kotlin" "node" "php" "python" "rust" "swift" "ts")

push_images() {
    local lang=$1
    echo "Pushing $lang docker images..."
    # https://hub.docker.com/r/feuyeux/grpc_server_java
    docker push feuyeux/grpc_server_$lang:1.0.0
    docker push feuyeux/grpc_client_$lang:1.0.0
    echo "Done pushing $lang images"
}

if [ -z "$1" ]; then
    echo "Pushing all language docker images..."
    for lang in "${LANGUAGES[@]}"; do
        push_images $lang
    done
else
    if [[ " ${LANGUAGES[@]} " =~ " $1 " ]]; then
        push_images $1
    else
        echo "Language '$1' not supported. Available options: ${LANGUAGES[*]}"
        exit 1
    fi
fi
