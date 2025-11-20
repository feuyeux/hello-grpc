# 图标生成清单

## 原始图标
- **Tauri**: `../diagram/hello_grpc_blue.png` (蓝色主题)
- **Flutter**: `../diagram/hello_grpc_red.png` (红色主题)

## Tauri 图标 (蓝色主题)
- `hello-grpc-tauri/src-tauri/icons/32x32.png` - 32x32 PNG
- `hello-grpc-tauri/src-tauri/icons/128x128.png` - 128x128 PNG
- `hello-grpc-tauri/src-tauri/icons/128x128@2x.png` - 256x256 PNG (高分辨率)
- `hello-grpc-tauri/src-tauri/icons/256x256.png` - 256x256 PNG
- `hello-grpc-tauri/src-tauri/icons/512x512.png` - 512x512 PNG
- `hello-grpc-tauri/src-tauri/icons/icon.ico` - Windows ICO
- `hello-grpc-tauri/src-tauri/icons/icon.icns` - macOS ICNS

## Flutter 图标 (红色主题)

### Android
- `hello-grpc-flutter/android/app/src/main/res/mipmap-*/ic_launcher.png` - 各密度图标

### iOS
- `hello-grpc-flutter/ios/Runner/Assets.xcassets/AppIcon.appiconset/` - iOS 应用图标集

### Web
- `hello-grpc-flutter/web/icons/Icon-*.png` - PWA 图标
- `hello-grpc-flutter/web/favicon.png` - 网站图标

### 桌面平台
- `hello-grpc-flutter/linux/assets/icon.png` - Linux 图标
- `hello-grpc-flutter/windows/runner/resources/app_icon.ico` - Windows 图标
- `hello-grpc-flutter/macos/Runner/Assets.xcassets/AppIcon.appiconset/` - macOS 图标

## 框架图标区分

- **Tauri 应用**: 使用蓝色主题图标，便于在桌面环境中识别
- **Flutter 应用**: 使用红色主题图标，便于在移动和Web环境中识别

## 使用说明

1. 如需自定义图标，请替换 `../diagram/hello_grpc_blue.png` 和 `../diagram/hello_grpc_red.png`
2. 重新运行此脚本生成所有平台图标
3. 对于生产环境，建议使用专业设计的图标

## 注意事项

- iOS 图标不能包含透明度
- Android 自适应图标需要额外配置
- Web 图标建议提供多种尺寸以适应不同设备
- 不同框架使用不同颜色主题便于用户区分
