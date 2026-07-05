#!/usr/bin/env bash
# Test script to verify build.sh, server_start.sh, and client_start.sh fixes
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}" || exit

echo "=========================================="
echo "Testing hello-grpc-java scripts"
echo "=========================================="
echo

# Test 1: Build script should complete successfully even when skipping build
echo "[TEST 1] Testing build.sh when project is up-to-date..."
bash scripts/build.sh
if [ $? -eq 0 ]; then
    echo "✅ build.sh completed successfully"
else
    echo "❌ build.sh failed"
    exit 1
fi
echo

# Test 2: Build script with verbose flag
echo "[TEST 2] Testing build.sh with --verbose..."
bash scripts/build.sh --verbose
if [ $? -eq 0 ]; then
    echo "✅ build.sh --verbose completed successfully"
else
    echo "❌ build.sh --verbose failed"
    exit 1
fi
echo

# Test 3: Server start script (background mode)
echo "[TEST 3] Testing server_start.sh in background mode..."
bash scripts/server_start.sh --skip-build --background > /tmp/java_server_test.log 2>&1
sleep 3

if ps aux | grep -q "[P]rotoServer"; then
    echo "✅ server_start.sh started successfully"
    # Stop the server
    pkill -f "ProtoServer" 2>/dev/null
    sleep 1
else
    echo "❌ server_start.sh failed to start"
    cat /tmp/java_server_test.log
    exit 1
fi
echo

# Test 4: Full integration test (server + client)
echo "[TEST 4] Testing full integration (server + client)..."
bash scripts/server_start.sh --skip-build > /tmp/java_server_integration.log 2>&1 &
SERVER_PID=$!
sleep 5

# Check if server is running
if ! ps -p $SERVER_PID > /dev/null; then
    echo "❌ Server failed to start"
    cat /tmp/java_server_integration.log
    exit 1
fi

echo "Server started (PID: $SERVER_PID), testing client..."

# Run client
if bash scripts/client_start.sh --count=1 > /tmp/java_client_test.log 2>&1; then
    echo "✅ Client completed successfully"
else
    echo "❌ Client failed"
    cat /tmp/java_client_test.log
    kill $SERVER_PID 2>/dev/null
    exit 1
fi

# Stop server
kill $SERVER_PID 2>/dev/null
sleep 1
echo

echo "=========================================="
echo "All tests passed! ✅"
echo "=========================================="
echo
echo "Summary:"
echo "  ✅ build.sh handles up-to-date projects correctly"
echo "  ✅ server_start.sh can start in background mode"  
echo "  ✅ Full integration test (server + client) works"
