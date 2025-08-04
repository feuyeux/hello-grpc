#!/bin/bash

echo "Starting hello-grpc-tauri web server..."
echo "Access at: http://localhost:8080"
echo "Press Ctrl+C to stop"

cd src && python3 -m http.server 8080 2>/dev/null || python -m http.server 8080
