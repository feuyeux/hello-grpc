# hello-grpc-swift

## dev

```sh
$ swift -version                                                                                                                               2 ↵
Swift version 5.8.1 (swift-5.8.1-RELEASE)
Target: x86_64-apple-macosx13.0

$ swift package tools-version
5.8.1
```

switch xcode version

```sh
$ gcc --version                                                                                                                                                       1 ↵
Apple clang version 15.0.0 (clang-1500.0.40.1)
Target: x86_64-apple-darwin22.6.0
Thread model: posix
InstalledDir: /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin

$ sudo xcode-select -s /Applications/Xcode.14.2.app/Contents/Developer

$ xcode-select -p
/Applications/Xcode.14.2.app/Contents/Developer

$ gcc --version
Apple clang version 14.0.0 (clang-1400.0.29.202)
Target: x86_64-apple-darwin22.6.0
Thread model: posix
InstalledDir: /Applications/Xcode.14.2.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin
```

### format

```sh
https://github.com/nicklockwood/SwiftFormat
brew install swiftformat
swiftformat --indent 4 --swiftversion 5.7 --exclude "**/*.grpc.swift,**/*.pb.swift" .
```

## build

```sh
# 老 Mac 用上最新 macOS
# https://dortania.github.io/OpenCore-Legacy-Patcher/INSTALLER.html#creating-the-installer
# https://github.com/getlantern/lantern

brew install swift-protobuf grpc-swift
cd Sources/Common
sh proto2swift.sh
```

```sh
# clean if meeting issue: "PCH was compiled with module cache path ..., but the path is currently ..."
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf .build
Clean: ⇧shift+⌘cmd+K in xcode
```

```sh
swift build
```

## run

```sh
swift run HelloServer
```

```sh
swift run HelloClient
```

## prod

```sh
swift build -c release

swift build -c release -Xswiftc -cross-module-optimization

.build/release/HelloServer  
.build/release/HelloClient
```
