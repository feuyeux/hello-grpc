FROM dart:latest AS build-base
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

RUN dart pub get
RUN ln -s ../proto protos
RUN dart compile exe -o grpc_server ./server.dart
RUN dart compile exe -o grpc_client ./client.dart

FROM debian:bookworm-slim AS server
RUN useradd --system --create-home --shell /usr/sbin/nologin app
WORKDIR /app
COPY --from=build-base --chown=app:app /app/hello-grpc/hello-grpc-dart/grpc_server /app
RUN mkdir -p /var/hello_grpc/server_certs /var/hello_grpc/client_certs
COPY --chown=app:app docker/tls/server_certs/* /var/hello_grpc/server_certs/
COPY --chown=app:app docker/tls/client_certs/* /var/hello_grpc/client_certs/
USER app
ENTRYPOINT ["/app/grpc_server"]

FROM debian:bookworm-slim AS client
RUN useradd --system --create-home --shell /usr/sbin/nologin app
WORKDIR /app
COPY --from=build-base --chown=app:app /app/hello-grpc/hello-grpc-dart/grpc_client /app
RUN mkdir -p /var/hello_grpc/client_certs
COPY --chown=app:app docker/tls/client_certs/* /var/hello_grpc/client_certs/
USER app
ENTRYPOINT ["/app/grpc_client"]
