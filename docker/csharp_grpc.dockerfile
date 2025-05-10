# https://hub.docker.com/r/microsoft/dotnet-sdk
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build-base

# Copy the entire project for building
ARG PROJECT_ROOT=.
WORKDIR /app/hello-grpc
COPY hello-grpc-csharp /app/hello-grpc/hello-grpc-csharp
COPY proto /app/hello-grpc/proto

# Build C# server and client
WORKDIR /app/hello-grpc/hello-grpc-csharp
RUN dotnet restore HelloGrpc.sln
RUN dotnet build -c Release HelloServer
RUN dotnet build -c Release HelloClient
RUN dotnet publish -c Release HelloServer -o /app/publish/server
RUN dotnet publish -c Release HelloClient -o /app/publish/client

FROM mcr.microsoft.com/dotnet/aspnet:9.0-alpine AS server
WORKDIR /app
COPY --from=build-base /app/publish/server /app
COPY docker/tls/server_certs/* /var/hello_grpc/server_certs/
COPY docker/tls/client_certs/* /var/hello_grpc/client_certs/
ENTRYPOINT ["dotnet", "HelloServer.dll"]

FROM mcr.microsoft.com/dotnet/aspnet:9.0-alpine AS client
WORKDIR /app
COPY --from=build-base /app/publish/client /app
COPY docker/tls/client_certs/* /var/hello_grpc/client_certs/
ENTRYPOINT ["dotnet", "HelloClient.dll"]