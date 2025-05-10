#!/bin/bash
cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit

cd ..

export GRPC_SERVER_PORT=9997
export GRPC_SERVER=127.0.0.1

# 打印环境变量以验证
echo "===== 客户端环境变量配置 ====="
echo "GRPC_SERVER_PORT: $GRPC_SERVER_PORT"
echo "GRPC_SERVER: $GRPC_SERVER"
echo "==========================="

swift run HelloClient
