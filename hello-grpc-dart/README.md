
# build

```sh
dart pub get
```

## run the server

```sh
dart server.dart
```

## run the client

```sh
dart client.dart
```

```sh
dart compile exe server.dart -o bin/hello_server
./bin/hello_server

dart compile exe client.dart -o bin/hello_client
./bin/hello_client
```

## Debugging Troubleshoot

```sh
Problem:

dart --enable-asserts --pause_isolates_on_start --enable-vm-service:50714 client.dart

vm-service: Error: Unhandled exception:
WebSocketException: Invalid WebSocket upgrade request

Solution:

export NO_PROXY=localhost,127.0.0.1


The Dart DevTools debugger and profiler is available at: http://127.0.0.1:52426/6IXUiMzaUlk=/devtools?uri=ws://127.0.0.1:52426/6IXUiMzaUlk=/ws
```
