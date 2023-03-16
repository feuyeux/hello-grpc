# grpc c# demo

## PREREQUISITES

### .NET SDK

- Download <https://dotnet.microsoft.com/en-us/download/visual-studio-sdks>
- What is <https://learn.microsoft.com/en-us/dotnet/core/sdk>

## BUILD

```bash
rm -rf */bin */obj
dotnet build
```

grpc generated files:

- Common/obj/Debug/net7.0/Landing.cs

## RUN

```bash
dotnet HelloServer/bin/Debug/net7.0/HelloServer.dll
```

```bash
dotnet HelloClient/bin/Debug/net7.0/HelloClient.dll
```

> ## docker
>
> - <https://github.com/dotnet/dotnet-docker/blob/main/samples/dotnetapp/README.md>
> - <https://hub.docker.com/_/microsoft-dotnet-sdk>
