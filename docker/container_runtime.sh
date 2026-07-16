#!/usr/bin/env bash

# Shared runtime selection for the Dockerfile-based examples.
# Set GRPC_CONTAINER_RUNTIME to docker or container to override auto detection.

grpc_container_runtime_init() {
    local requested="${GRPC_CONTAINER_RUNTIME:-auto}"
    local host_os host_arch
    host_os="$(uname -s)"
    host_arch="$(uname -m)"

    case "$requested" in
    auto)
        if [[ "$host_os" == "Darwin" && "$host_arch" == "arm64" ]] && command -v container >/dev/null 2>&1; then
            GRPC_CONTAINER_RUNTIME="container"
        elif type -P docker >/dev/null 2>&1; then
            GRPC_CONTAINER_RUNTIME="docker"
        else
            echo "Error: neither Docker nor Apple container is available." >&2
            return 1
        fi
        ;;
    docker)
        GRPC_CONTAINER_RUNTIME="docker"
        ;;
    container)
        if [[ "$host_os" != "Darwin" || "$host_arch" != "arm64" ]]; then
            echo "Error: Apple container requires an Apple-silicon Mac." >&2
            return 1
        fi
        GRPC_CONTAINER_RUNTIME="container"
        ;;
    *)
        echo "Error: GRPC_CONTAINER_RUNTIME must be auto, docker, or container." >&2
        return 1
        ;;
    esac

    if [[ "$GRPC_CONTAINER_RUNTIME" == "docker" ]] && ! type -P docker >/dev/null 2>&1; then
        echo "Error: selected runtime '$GRPC_CONTAINER_RUNTIME' is not installed." >&2
        return 1
    fi
    if [[ "$GRPC_CONTAINER_RUNTIME" == "container" ]] && ! type -P container >/dev/null 2>&1; then
        echo "Error: selected runtime '$GRPC_CONTAINER_RUNTIME' is not installed." >&2
        return 1
    fi

    if [[ "$GRPC_CONTAINER_RUNTIME" == "container" ]]; then
        if ! container system status >/dev/null 2>&1; then
            echo "Starting Apple container services..."
            container system start
        fi
    elif ! docker info >/dev/null 2>&1; then
        echo "Error: Docker does not appear to be running. Please start Docker and try again." >&2
        return 1
    fi

    export GRPC_CONTAINER_RUNTIME
    echo "Using container runtime: $GRPC_CONTAINER_RUNTIME"
}

grpc_container_run() {
    "$GRPC_CONTAINER_RUNTIME" run "$@"
}

grpc_container_build() {
    "$GRPC_CONTAINER_RUNTIME" build "$@"
}

grpc_container_remove() {
    if [[ "$GRPC_CONTAINER_RUNTIME" == "container" ]]; then
        container delete --force "$@"
    else
        docker rm -f "$@"
    fi
}

grpc_container_require_host_domain() {
    local domain="host.container.internal"

    [[ "$GRPC_CONTAINER_RUNTIME" == "container" ]] || return 0

    if ! container system dns list --quiet 2>/dev/null | grep -Fxq "$domain"; then
        cat >&2 <<EOF
Error: Apple container clients need a host DNS domain to reach the published server port.
Run this once, then retry:
  sudo container system dns create $domain --localhost 203.0.113.113
EOF
        return 1
    fi
}
