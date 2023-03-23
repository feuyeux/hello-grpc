# hello-grpc-swift

## dev

format

```sh
https://github.com/nicklockwood/SwiftFormat
brew install swiftformat
swiftformat --indent 4 --swiftversion 5.7 --exclude "**/*.grpc.swift,**/*.pb.swift" .
```

build

```sh
cd Sources/Common
sh proto2swift.sh
```

```sh
swift build
```

run

```sh
swift run HelloServer
```

```sh
swift run HelloClient
```

## prod

```sh
$ swift build -c release
$ .build/release/HelloServer  
$ .build/release/HelloClient
```
