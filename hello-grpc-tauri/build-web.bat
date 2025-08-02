@echo off
REM Build script for hello-grpc-tauri web version (Windows)
echo Building hello-grpc-tauri web version...

echo Starting web development server...
echo You can access the web version at: http://localhost:8080
echo Press Ctrl+C to stop the server

REM Use Python's built-in HTTP server if available
where python >nul 2>nul
if %errorlevel% == 0 (
    cd src && python -m http.server 8080
) else (
    where python3 >nul 2>nul
    if %errorlevel% == 0 (
        cd src && python3 -m http.server 8080
    ) else (
        echo Python not found. Please install Python or use another HTTP server.
        echo You can manually serve the 'src' directory on port 8080
        pause
    )
)
