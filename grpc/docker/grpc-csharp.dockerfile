FROM mcr.microsoft.com/dotnet/sdk:3.1 AS build
WORKDIR /source
COPY hello-grpc-csharp .
# download dependencies
RUN dotnet restore
# build production version
RUN dotnet publish -c release -o /app --no-restore

# final stage/image
FROM mcr.microsoft.com/dotnet/runtime:3.1
WORKDIR /app
COPY --from=build /app .