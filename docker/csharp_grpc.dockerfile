# https://hub.docker.com/r/microsoft/dotnet-sdk
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build-base

# Use the system protoc (arm64-native) instead of the one bundled in
# grpc.tools 2.80.0. The grpc.tools linux_arm64/protoc binary segfaults
# (exit 139) on arm64 hosts, and forcing linux-x64 fails because the
# dotnet SDK image lacks /lib64/ld-linux-x86-64.so.2 for Rosetta. The
# protoc binary from apt's protobuf-compiler is arm64-native and works.
# PROTOBUF_PROTOC is read by Google.Protobuf.Tools.targets (line ~74) and
# takes precedence over the package-bundled binary.
RUN apt-get update \
    && apt-get install -y --no-install-recommends protobuf-compiler \
    && rm -rf /var/lib/apt/lists/*
ENV PROTOBUF_PROTOC=/usr/bin/protoc

# Copy the entire project for building
ARG PROJECT_ROOT=.
WORKDIR /app/hello-grpc
COPY hello-grpc-csharp /app/hello-grpc/hello-grpc-csharp
COPY proto /app/hello-grpc/proto

# Build C# server and client. The host is arm64 Linux (Apple Silicon Docker
# Desktop); `linux_arm64` protoc in grpc.tools 2.80.0 segfaults, so we route
# PROTOBUF_PROTOC to the arm64-native protoc installed by apt above.
WORKDIR /app/hello-grpc/hello-grpc-csharp
RUN dotnet restore HelloGrpc.sln
RUN dotnet build -c Release HelloServer
RUN dotnet build -c Release HelloClient
RUN dotnet publish -c Release HelloServer -o /app/publish/server
RUN dotnet publish -c Release HelloClient -o /app/publish/client

FROM mcr.microsoft.com/dotnet/aspnet:9.0-alpine AS server
RUN addgroup -S app && adduser -S -G app app
WORKDIR /app
COPY --from=build-base --chown=app:app /app/publish/server /app
RUN mkdir -p /var/hello_grpc/server_certs /var/hello_grpc/client_certs
COPY --chown=app:app docker/tls/server_certs/* /var/hello_grpc/server_certs/
COPY --chown=app:app docker/tls/client_certs/* /var/hello_grpc/client_certs/
USER app
ENTRYPOINT ["dotnet", "HelloServer.dll"]

FROM mcr.microsoft.com/dotnet/aspnet:9.0-alpine AS client
RUN addgroup -S app && adduser -S -G app app
WORKDIR /app
COPY --from=build-base --chown=app:app /app/publish/client /app
RUN mkdir -p /var/hello_grpc/client_certs
COPY --chown=app:app docker/tls/client_certs/* /var/hello_grpc/client_certs/
USER app
ENTRYPOINT ["dotnet", "HelloClient.dll"]