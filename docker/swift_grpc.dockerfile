# https://hub.docker.com/_/swift
FROM swift:6.1 AS build-base

RUN sed -i 's@http://archive.ubuntu.com@https://mirrors.tuna.tsinghua.edu.cn@g' /etc/apt/sources.list \
    && sed -i 's@http://security.ubuntu.com@https://mirrors.tuna.tsinghua.edu.cn@g' /etc/apt/sources.list \
    && apt-get update && apt-get install -y \
    protobuf-compiler \
    git \
    && rm -rf /var/lib/apt/lists/*

ARG PROJECT_ROOT=.
WORKDIR /app/hello-grpc
COPY hello-grpc-swift /app/hello-grpc/hello-grpc-swift
COPY proto /app/hello-grpc/proto
COPY proto2x.sh /app/hello-grpc/

# Build Swift server and client
WORKDIR /app/hello-grpc/hello-grpc-swift

# Make sure the build script is executable
RUN chmod +x build.sh
RUN ../proto2x.sh swift
RUN swift build -c release -Xswiftc -cross-module-optimization

# Final server image
FROM swift:6.1 AS server
WORKDIR /app
COPY --from=build-base /app/hello-grpc/hello-grpc-swift/.build/release/HelloServer /app/
# Create certificate directories
RUN mkdir -p /var/hello_grpc/server_certs /var/hello_grpc/client_certs
# Copy certificate files if they exist, or create placeholder files
COPY docker/tls/server_certs/ /var/hello_grpc/server_certs/
COPY docker/tls/client_certs/ /var/hello_grpc/client_certs/
ENTRYPOINT ["/app/HelloServer"]

# Final client image
FROM swift:6.1 AS client
WORKDIR /app
COPY --from=build-base /app/hello-grpc/hello-grpc-swift/.build/release/HelloClient /app/
# Create certificate directory
RUN mkdir -p /var/hello_grpc/client_certs
# Copy certificate files if they exist, or create placeholder files
COPY docker/tls/client_certs/ /var/hello_grpc/client_certs/
ENTRYPOINT ["/app/HelloClient"]