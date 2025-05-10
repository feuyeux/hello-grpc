FROM debian:bookworm-slim AS build-base

# Configure apt mirrors (if needed)
RUN if [ -f "/etc/apt/sources.list.d/debian.sources" ]; then \
    cp /etc/apt/sources.list.d/debian.sources /etc/apt/sources.list.d/debian.sources.bak && \
    sed -i 's|http://deb.debian.org/debian|http://mirrors.aliyun.com/debian|g' /etc/apt/sources.list.d/debian.sources && \
    sed -i 's|http://deb.debian.org/debian-security|http://mirrors.aliyun.com/debian-security|g' /etc/apt/sources.list.d/debian.sources; \
    fi && \
    # For backwards compatibility, also check for traditional sources.list
    if [ -f "/etc/apt/sources.list" ]; then \
    cp /etc/apt/sources.list /etc/apt/sources.list.bak && \
    sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    sed -i 's/security.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list; \
    fi

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    pkg-config \
    zip \
    unzip \
    g++ \
    libssl-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Bazelisk (use a direct download approach)
RUN arch=$(uname -m) && \
    if [ "$arch" = "x86_64" ]; then \
    curl -L -o /usr/local/bin/bazelisk https://github.com/bazelbuild/bazelisk/releases/download/v1.20.0/bazelisk-linux-amd64; \
    elif [ "$arch" = "aarch64" ] || [ "$arch" = "arm64" ]; then \
    curl -L -o /usr/local/bin/bazelisk https://github.com/bazelbuild/bazelisk/releases/download/v1.20.0/bazelisk-linux-arm64; \
    else \
    echo "Unsupported architecture: $arch"; \
    exit 1; \
    fi && \
    chmod +x /usr/local/bin/bazelisk && \
    ln -sf /usr/local/bin/bazelisk /usr/local/bin/bazel

# Copy the entire project for building
ARG PROJECT_ROOT=.
WORKDIR /app
COPY hello-grpc-cpp /app/hello-grpc-cpp
COPY proto /app/proto

# Build C++ server and client using Bazel
WORKDIR /app/hello-grpc-cpp
# Determine CPU core count (cross-platform)
RUN CPU_CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4) && \
    echo "CPU cores=$CPU_CORES" && \
    # Clean Bazel
    bazel clean --expunge && \
    # Build hello_server and hello_client with optimized flags
    bazel build \
    --jobs=$CPU_CORES \
    --cxxopt="-std=c++17" \
    --host_cxxopt="-std=c++17" \
    --conlyopt="-std=c11" \
    --build_tag_filters="-no_cpp" \
    --features=-supports_dynamic_linker \
    --output_filter='^((?!grpc_.*_plugin).)*$' \
    --define=grpc_build_grpc_csharp_plugin=false \
    --define=grpc_build_grpc_node_plugin=false \
    --define=grpc_build_grpc_objective_c_plugin=false \
    --define=grpc_build_grpc_php_plugin=false \
    --define=grpc_build_grpc_python_plugin=false \
    --define=grpc_build_grpc_ruby_plugin=false \
    //:hello_server //:hello_client

FROM debian:bookworm-slim AS server
WORKDIR /app
# Copy the built server binary from the Bazel output directory
COPY --from=build-base /app/hello-grpc-cpp/bazel-bin/hello_server /app/
# Create certificate directories
RUN mkdir -p /var/hello_grpc/server_certs /var/hello_grpc/client_certs
# Copy certificates
COPY docker/tls/server_certs/* /var/hello_grpc/server_certs/
COPY docker/tls/client_certs/* /var/hello_grpc/client_certs/
ENTRYPOINT ["/app/hello_server"]

FROM debian:bookworm-slim AS client
WORKDIR /app
# Copy the built client binary from the Bazel output directory
COPY --from=build-base /app/hello-grpc-cpp/bazel-bin/hello_client /app/
# Create certificate directory
RUN mkdir -p /var/hello_grpc/client_certs
# Copy certificates
COPY docker/tls/client_certs/* /var/hello_grpc/client_certs/
ENTRYPOINT ["/app/hello_client"]