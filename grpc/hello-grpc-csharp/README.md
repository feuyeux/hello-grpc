## grpc c# demo

### PREREQUISITES

- [.NET Core](https://dotnet.github.io/) on  Linux, Windows and Mac OS X

grpc generated files:
- Common/obj/Debug/netstandard1.5/Landing.cs

```bash
dotnet build

cd HelloServer
dotnet HelloServer/bin/Debug/netcoreapp3.1/HelloServer.dll

cd HelloClient
dotnet HelloClient/bin/Debug/netcoreapp3.1/HelloClient.dll
```


> dotnet:
> - .NET 5: 5.0.9 at [$HOME/.dotnet/shared/Microsoft.NETCore.App]
> - .NET 3.1: Microsoft.NETCore.App 3.1.19 [/usr/local/share/dotnet/shared/Microsoft.NETCore.App]
> - https://www.jetbrains.com/help/rider/Settings_Environment.html
>
> docker: 
> - <https://github.com/dotnet/dotnet-docker/blob/main/samples/dotnetapp/README.md>
> - <https://hub.docker.com/_/microsoft-dotnet-sdk>