FROM mcr.microsoft.com/dotnet/sdk:7.0 AS build
# https://hub.docker.com/_/microsoft-dotnet-sdk
WORKDIR /source
COPY hello-grpc-csharp .
# download dependencies
RUN dotnet restore
# build production version
RUN dotnet publish HelloServer -c release -o server_out --no-restore
RUN dotnet publish HelloClient -c release -o client_out --no-restore

FROM mcr.microsoft.com/dotnet/runtime:7.0 AS server
# https://hub.docker.com/_/microsoft-dotnet-runtime
WORKDIR /app
COPY --from=build /source/server_out .
COPY tls/server_certs /var/hello_grpc/server_certs
COPY tls/client_certs /var/hello_grpc/client_certs
CMD ["dotnet","HelloServer.dll"]

FROM mcr.microsoft.com/dotnet/runtime:7.0 AS client
WORKDIR /app
COPY --from=build /source/client_out .
COPY tls/client_certs /var/hello_grpc/client_certs
CMD ["dotnet","HelloClient.dll"]