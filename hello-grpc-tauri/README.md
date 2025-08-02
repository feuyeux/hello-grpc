# Hello gRPC Tauri

A Tauri application that demonstrates gRPC communication with both native desktop support and web compatibility.

## Features

✅ **Dual Mode Support**

- **Native Mode**: Direct gRPC communication using Tauri's Rust backend
- **Web Mode**: HTTP gateway communication for web browsers

✅ **Complete gRPC Implementation**

- Unary RPC (Request/Response)
- Server Streaming (One request, multiple responses)
- Client Streaming (Multiple requests, one response)
- Bidirectional Streaming (Multiple requests, multiple responses)

✅ **Flutter-Aligned Functionality**

- UI design matches Flutter's Material Design approach
- Same gRPC test patterns and response formatting
- Platform detection and mode switching
- Consistent error handling and logging

## Quick Start

### Native Desktop Application

```bash
# Install dependencies
npm install

# Run in development mode
npm run tauri dev

# Build for production
npm run tauri build
```

### Web Application

```bash
# Start web development server
./build-web.bat    # Windows
./build-web.sh     # Linux/macOS

# Or manually serve the src directory
cd src
python -m http.server 8080
```

Then open <http://localhost:8080> in your browser.

## Usage

1. **Configure Server**: Enter the gRPC server host and port
2. **Select Mode**:
   - Choose "Native gRPC" for desktop applications
   - Choose "Web Gateway" for browser compatibility
3. **Test Connection**: Click "ASK gRPC Server From Tauri" to run all gRPC tests

## Architecture

### Native Mode

```
Tauri App → Rust Backend → gRPC Server (port 9996)
```

### Web Mode  

```
Web Browser → HTTP Gateway (port 9997) → gRPC Server (port 9996)
```

## Platform Support

- **Desktop**: Windows, macOS, Linux (via Tauri)
- **Web**: All modern browsers (via HTTP gateway)
- **Mobile**: Android, iOS (via Tauri mobile)

## Recommended IDE Setup

- [VS Code](https://code.visualstudio.com/) + [Tauri](https://marketplace.visualstudio.com/items?itemName=tauri-apps.tauri-vscode) + [rust-analyzer](https://marketplace.visualstudio.com/items?itemName=rust-lang.rust-analyzer)
