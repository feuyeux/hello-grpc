#!/bin/bash

# Build script for hello-grpc-tauri web version
echo "Building hello-grpc-tauri web version..."

# Create a simple HTTP server for testing web version
echo "Starting web development server..."
echo "You can access the web version at: http://localhost:8080"
echo "Press Ctrl+C to stop the server"

# Use Python's built-in HTTP server if available
if command -v python3 &> /dev/null; then
    cd src && python3 -m http.server 8080
elif command -v python &> /dev/null; then
    cd src && python -m http.server 8080
else
    echo "Python not found. Please install Python or use another HTTP server."
    echo "You can manually serve the 'src' directory on port 8080"
fi
