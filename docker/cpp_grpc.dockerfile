FROM debian:bookworm-slim AS build-base

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
    curl --fail --location --retry 5 --retry-all-errors --retry-delay 3 --connect-timeout 20 -o /usr/local/bin/bazelisk https://github.com/bazelbuild/bazelisk/releases/download/v1.20.0/bazelisk-linux-amd64; \
    elif [ "$arch" = "aarch64" ] || [ "$arch" = "arm64" ]; then \
    curl --fail --location --retry 5 --retry-all-errors --retry-delay 3 --connect-timeout 20 -o /usr/local/bin/bazelisk https://github.com/bazelbuild/bazelisk/releases/download/v1.20.0/bazelisk-linux-arm64; \
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
RUN --mount=type=cache,target=/root/.cache/bazel-repository \
    --mount=type=cache,target=/root/.cache/bazel-disk-cache \
    CPU_CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4) && \
    # Cap parallel jobs to avoid OOM on memory-constrained Docker hosts
    # (gRPC C++ actions are memory-heavy; 14 cores / 8 GB RAM exhausts memory)
    BAZEL_JOBS=$((CPU_CORES > 4 ? 4 : CPU_CORES)) && \
    echo "CPU cores=$CPU_CORES, Bazel jobs=$BAZEL_JOBS" && \
    # Clean Bazel
    bazel clean --expunge && \
    # Build hello_server and hello_client with optimized flags
    bazel build \
    --jobs=$BAZEL_JOBS \
    --repository_cache=/root/.cache/bazel-repository \
    --disk_cache=/root/.cache/bazel-disk-cache \
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
RUN useradd --system --create-home --shell /usr/sbin/nologin app
WORKDIR /app
# Copy the built server binary from the Bazel output directory
COPY --from=build-base --chown=app:app /app/hello-grpc-cpp/bazel-bin/hello_server /app/
# Create certificate directories
RUN mkdir -p /var/hello_grpc/server_certs /var/hello_grpc/client_certs
# Copy certificates
COPY --chown=app:app docker/tls/server_certs/* /var/hello_grpc/server_certs/
COPY --chown=app:app docker/tls/client_certs/* /var/hello_grpc/client_certs/
USER app
ENTRYPOINT ["/app/hello_server"]

FROM debian:bookworm-slim AS client
RUN useradd --system --create-home --shell /usr/sbin/nologin app
WORKDIR /app
# Copy the built client binary from the Bazel output directory
COPY --from=build-base --chown=app:app /app/hello-grpc-cpp/bazel-bin/hello_client /app/
# Create certificate directory
RUN mkdir -p /var/hello_grpc/client_certs
# Copy certificates
COPY --chown=app:app docker/tls/client_certs/* /var/hello_grpc/client_certs/
USER app
ENTRYPOINT ["/app/hello_client"]
