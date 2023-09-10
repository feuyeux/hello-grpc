# hello_grpc_flutter

gRPC Client by Flutter

## SETUP

### ENV

```sh
$ code $HOME/.zshrc

export FLUTTER_STORAGE_BASE_URL=https://mirror.sjtu.edu.cn
export PUB_HOSTED_URL=https://mirror.sjtu.edu.cn/dart-pub
export FLUTTER_HOME=$HOME/flutter
export PATH="$PATH:${FLUTTER_HOME}/bin"

export NO_PROXY=localhost,127.0.0.1
export http_proxy=127.0.0.1:54776
```

### CocoaPods

```sh
$ brew install cocoapods

$ pod --version
1.12.1
```

### Android

- <https://flutterservice.com/sdkmanager-command-not-found-flutter/>

```sh
flutter doctor --android-licenses
```

### Check

```sh
$ flutter doctor

Doctor summary (to see all details, run flutter doctor -v):
[✓] Flutter (Channel stable, 3.13.2, on macOS 13.6 22G109 darwin-x64, locale zh-Hans)
[✓] Android toolchain - develop for Android devices (Android SDK version 34.0.0)
[✓] Xcode - develop for iOS and macOS (Xcode 14.3.1)
[✓] Chrome - develop for the web
[✓] Android Studio (version 2022.3)
[✓] IntelliJ IDEA Ultimate Edition (version 2023.2.1)
[✓] VS Code (version 1.81.1)
[✓] Connected device (2 available)
[✓] Network resources

• No issues found!


PS > flutter doctor
Flutter assets will be downloaded from https://storage.flutter-io.cn. Make sure you trust this source!
Doctor summary (to see all details, run flutter doctor -v):
[√] Flutter (Channel stable, 3.10.6, on Microsoft Windows [Version 10.0.22621.2215], locale zh-CN)
[√] Windows Version (Installed version of Windows is version 10 or higher)
[√] Android toolchain - develop for Android devices (Android SDK version 34.0.0)
[√] Chrome - develop for the web
[√] Visual Studio - develop for Windows (Visual Studio Community 2022 17.7.3)
[√] Android Studio (version 2022.3)
[√] IntelliJ IDEA Community Edition (version 2023.2)
[√] VS Code (version 1.82.0)
[√] Connected device (3 available)
[√] Network resources

• No issues found!
```

### Run

```sh
#  [ios (default), android (default), windows (default), linux (default), macos (default), web (default)]
flutter create .
flutter run
#
flutter create . --platforms windows
flutter run -d windows
#
flutter run -d macos
```

## GUID

DOCUMENT: [Building your first Flutter App - with a Codelab](https://codelabs.developers.google.com/codelabs/flutter-codelab-first)

VIDEO：

- [youtube](https://www.youtube.com/watch?v=8sAyPDLorek)
- [bilibili](https://www.bilibili.com/video/BV1Uh4y1R7RC)
