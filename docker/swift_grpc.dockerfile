# https://hub.docker.com/_/swift
FROM swift:6.3 AS build-base

RUN sed -i 's@http://archive.ubuntu.com@https://mirrors.tuna.tsinghua.edu.cn@g' /etc/apt/sources.list \
    && sed -i 's@http://security.ubuntu.com@https://mirrors.tuna.tsinghua.edu.cn@g' /etc/apt/sources.list \
    && apt-get update && apt-get install -y \
    protobuf-compiler \
    git \
    && rm -rf /var/lib/apt/lists/*

# Route all SwiftPM git fetches through a GitHub mirror. SwiftPM has no
# GOPROXY-style knob, so we use git's insteadOf rewrite — every
# `https://github.com/...` URL the resolver tries (including git
# submodules inside cloned repos) becomes a fetch from the mirror
# instead. The previous build was looping on
# `gnutls_handshake() failed: The TLS connection was non-properly
# terminated` while cloning apple/swift-async-algorithms and a few
# others directly from github.com.
#
# gh-proxy.com is used (not ghfast.top) because the swift-protobuf
# submodule `protocolbuffers/protobuf` is a large clone and gh-proxy
# streams large git bundles more reliably. Tunables:
#   - http.postBuffer 524MB: avoid "RPC failed; curl 56" on large fetches
#   - http.lowSpeedLimit/Time: keep connection alive on slow CDN edges
#   - protocol.version=2: force git v2 protocol, fewer round-trips
#   - fetch.parallel=1: serialize large clones so a single TLS drop only
#     kills one repo, not the whole SwiftPM transaction
RUN git config --global url."https://gh-proxy.com/https://github.com/".insteadOf "https://github.com/" \
    && git config --global http.postBuffer 524288000 \
    && git config --global http.lowSpeedLimit 1000 \
    && git config --global http.lowSpeedTime 60 \
    && git config --global protocol.version 2 \
    && git config --global fetch.parallel 1 \
    && git config --global advice.detachedHead false

ARG PROJECT_ROOT=.
WORKDIR /app/hello-grpc
COPY hello-grpc-swift /app/hello-grpc/hello-grpc-swift
COPY proto /app/hello-grpc/proto
COPY scripts/proto2x.sh /app/hello-grpc/

# Build Swift server and client
WORKDIR /app/hello-grpc/hello-grpc-swift

RUN ../proto2x.sh swift
RUN swift build -c release -Xswiftc -cross-module-optimization

# Final server image
FROM swift:6.3-slim AS server
WORKDIR /app
COPY --from=build-base /app/hello-grpc/hello-grpc-swift/.build/release/HelloServer /app/
# Create certificate directories
RUN mkdir -p /var/hello_grpc/server_certs /var/hello_grpc/client_certs
# Copy certificate files if they exist, or create placeholder files
COPY docker/tls/server_certs/ /var/hello_grpc/server_certs/
COPY docker/tls/client_certs/ /var/hello_grpc/client_certs/
ENTRYPOINT ["/app/HelloServer"]

# Final client image
FROM swift:6.3-slim AS client
WORKDIR /app
COPY --from=build-base /app/hello-grpc/hello-grpc-swift/.build/release/HelloClient /app/
# Create certificate directory
RUN mkdir -p /var/hello_grpc/client_certs
# Copy certificate files if they exist, or create placeholder files
COPY docker/tls/client_certs/ /var/hello_grpc/client_certs/
ENTRYPOINT ["/app/HelloClient"]