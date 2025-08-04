# App Icon Generation Scripts

This repository contains automated scripts for generating application icons for both Flutter and Tauri projects.

## Overview

- **Flutter Project**: Uses `red.png` as the source icon
- **Tauri Project**: Uses `blue.png` as the source icon

## Script Files

### Flutter Project (`hello-grpc-flutter/`)
- `generate_app_icons.sh` - Generates icons for all Flutter platforms
- `verify_app_icons.sh` - Verifies that all icons were generated correctly

### Tauri Project (`hello-grpc-tauri/`)
- `generate_app_icons.sh` - Generates icons for all Tauri platforms  
- `verify_app_icons.sh` - Verifies that all icons were generated correctly

## Usage

### Flutter Icon Generation

```bash
cd /Users/han/coding/hello-grpc/hello-grpc-flutter
chmod +x generate_app_icons.sh verify_app_icons.sh
./generate_app_icons.sh
./verify_app_icons.sh
```

### Tauri Icon Generation

```bash
cd /Users/han/coding/hello-grpc/hello-grpc-tauri
chmod +x generate_app_icons.sh verify_app_icons.sh
./generate_app_icons.sh
./verify_app_icons.sh
```

## Generated Icons

### Flutter Project
- **Android**: 5 different densities (mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi)
- **iOS**: 15 different sizes for iPhone/iPad
- **macOS**: 7 different sizes
- **Assets**: Main app icon for Flutter app

### Tauri Project
- **Basic Icons**: 6 core formats (PNG, ICO, ICNS)
- **Windows Store**: 10 different sizes for Windows Store compliance
- **Cross-platform**: Compatible with Windows, macOS, and Linux

## Source Images

- Flutter: `/Users/han/coding/hello-grpc/diagram/red.png` (1024x1024)
- Tauri: `/Users/han/coding/hello-grpc/diagram/blue.png` (1024x1024)

## Requirements

- macOS with `sips` command (for image resizing)
- `iconutil` (for ICNS generation on macOS)
- Write permissions to project directories

## Notes

- All scripts are in English for better maintainability
- Scripts include error handling and verification
- Backup functionality preserves existing icons
- Color-coded output for easy reading
- Cross-platform compatibility considerations

## Troubleshooting

If verification fails:
1. Re-run the generation script
2. Check source image exists and is readable
3. Verify write permissions to target directories
4. Ensure required tools (`sips`, `iconutil`) are available
