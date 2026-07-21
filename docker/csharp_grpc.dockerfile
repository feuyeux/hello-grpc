# https://hub.docker.com/r/microsoft/dotnet-sdk
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build-base

# Use the system protoc (linux-x64 binary) instead of the one bundled in
# grpc.tools. Previously this used apt's protobuf-compiler, but the
# mcr.microsoft.com/dotnet/sdk:9.0 image's deb.debian.org sources fail
# with HTTP 502 Bad Gateway on debian-security intermittently, and
# protobuf-compiler is not available in bookworm/main — the package was
# dropped from the default repos. We download the upstream protoc binary
# directly. PROTOBUF_PROTOC is read by Google.Protobuf.Tools.targets
# (line ~74) and takes precedence over the package-bundled binary.
COPY protoc-35.1-linux-x86_64.zip /tmp/protoc-35.1-linux-x86_64.zip
RUN apt-get update \
    && apt-get install -y --no-install-recommends unzip ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && unzip /tmp/protoc-35.1-linux-x86_64.zip -d /usr/local/protoc35 \
    && ln -sf /usr/local/protoc35/bin/protoc /usr/local/bin/protoc
ENV PROTOBUF_PROTOC=/usr/local/bin/protoc

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
RUN addgroup -S app 2>/dev/null || true; adduser -S -G app app 2>/dev/null || true
WORKDIR /app
COPY --from=build-base --chown=app:app /app/publish/server /app
RUN mkdir -p /var/hello_grpc/server_certs /var/hello_grpc/client_certs
COPY --chown=app:app docker/tls/server_certs/* /var/hello_grpc/server_certs/
COPY --chown=app:app docker/tls/client_certs/* /var/hello_grpc/client_certs/
USER app
ENTRYPOINT ["dotnet", "HelloServer.dll"]

FROM mcr.microsoft.com/dotnet/aspnet:9.0-alpine AS client
RUN addgroup -S app 2>/dev/null || true; adduser -S -G app app 2>/dev/null || true
WORKDIR /app
COPY --from=build-base --chown=app:app /app/publish/client /app
RUN mkdir -p /var/hello_grpc/client_certs
COPY --chown=app:app docker/tls/client_certs/* /var/hello_grpc/client_certs/
USER app
ENTRYPOINT ["dotnet", "HelloClient.dll"]