FROM dart:3.7.3 AS build-base
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
RUN apt-get update && apt-get install -y \
    protobuf-compiler \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copy the entire project for building
ARG PROJECT_ROOT=.
WORKDIR /app/hello-grpc
COPY hello-grpc-dart /app/hello-grpc/hello-grpc-dart
COPY proto /app/hello-grpc/proto

# Build Dart server and client
WORKDIR /app/hello-grpc/hello-grpc-dart

ENV PUB_HOSTED_URL=https://pub.flutter-io.cn
ENV FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn=value
RUN dart pub get
RUN ln -s ../proto protos
RUN dart compile exe -o grpc_server ./server.dart
RUN dart compile exe -o grpc_client ./client.dart

FROM debian:bookworm-slim AS server
WORKDIR /app
COPY --from=build-base /app/hello-grpc/hello-grpc-dart/grpc_server /app
COPY docker/tls/server_certs/* /var/hello_grpc/server_certs/
COPY docker/tls/client_certs/* /var/hello_grpc/client_certs/
ENTRYPOINT ["/app/grpc_server"]

FROM debian:bookworm-slim AS client
WORKDIR /app
COPY --from=build-base /app/hello-grpc/hello-grpc-dart/grpc_client /app
COPY docker/tls/client_certs/* /var/hello_grpc/client_certs/
ENTRYPOINT ["/app/grpc_client"]