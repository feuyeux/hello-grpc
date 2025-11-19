# hello-grpc-ts 启动脚本使用指南

## 概述

本项目提供了与 hello-grpc-nodejs 相同的启动脚本，用于快速启动 gRPC 服务器和客户端，支持 TLS 和非 TLS 模式。

## 脚本列表

- **server_start.sh** - 服务器启动脚本
- **client_start.sh** - 客户端启动脚本
- **test_tls_with_scripts.sh** - TLS 功能自动化测试脚本

## 快速开始

### 1. 非 TLS 模式（不加密）

**启动服务器：**
```bash
./server_start.sh --port=9996
```

**启动客户端：**
```bash
./client_start.sh --addr=localhost:9996
```

### 2. TLS 模式（加密通信）

**启动服务器：**
```bash
./server_start.sh --tls --port=50052
```

**启动客户端：**
```bash
./client_start.sh --tls --addr=localhost:50052
```

## 脚本参数

### server_start.sh

| 参数 | 说明 | 默认值 | 示例 |
|------|------|--------|------|
| --tls | 启用 TLS 加密 | 禁用 | --tls |
| --addr=HOST:PORT | 服务器地址和端口 | 0.0.0.0:9996 | --addr=0.0.0.0:50052 |
| --port=PORT | 服务器端口 | 9996 | --port=50052 |
| --log=LEVEL | 日志级别 | info | --log=debug |
| --help | 显示帮助信息 | - | --help |

### client_start.sh

| 参数 | 说明 | 默认值 | 示例 |
|------|------|--------|------|
| --tls | 启用 TLS 加密 | 禁用 | --tls |
| --addr=HOST:PORT | 服务器地址和端口 | localhost:9996 | --addr=localhost:50052 |
| --port=PORT | 服务器端口 | 9996 | --port=50052 |
| --log=LEVEL | 日志级别 | info | --log=debug |
| --count=NUMBER | 迭代次数（未实现） | 3 | --count=5 |
| --help | 显示帮助信息 | - | --help |

## 使用示例

### 示例 1: 基本的非 TLS 通信

```bash
# 终端 1: 启动服务器
cd hello-grpc-ts
./server_start.sh

# 终端 2: 启动客户端
cd hello-grpc-ts
./client_start.sh
```

### 示例 2: TLS 加密通信

```bash
# 终端 1: 启动 TLS 服务器
cd hello-grpc-ts
./server_start.sh --tls --port=50052

# 终端 2: 启动 TLS 客户端
cd hello-grpc-ts
./client_start.sh --tls --addr=localhost:50052
```

### 示例 3: 自定义端口

```bash
# 终端 1: 在端口 8080 启动服务器
cd hello-grpc-ts
./server_start.sh --port=8080

# 终端 2: 连接到端口 8080
cd hello-grpc-ts
./client_start.sh --addr=localhost:8080
```

### 示例 4: 调试模式

```bash
# 启动服务器并启用调试日志
./server_start.sh --log=debug

# 启动客户端并启用调试日志
./client_start.sh --log=debug
```

## 证书配置

### 证书路径优先级

脚本会按以下顺序查找证书：

1. **项目本地证书**（推荐）
   - 服务器: `../docker/tls/server_certs/`
   - 客户端: `../docker/tls/client_certs/`

2. **系统证书路径**（备用）
   - macOS/Linux: `/var/hello_grpc/server_certs/` 或 `/var/hello_grpc/client_certs/`
   - Windows: `d:\garden\var\hello_grpc\server_certs\` 或 `d:\garden\var\hello_grpc\client_certs\`

### 必需的证书文件

**服务器证书：**
- `cert.pem` - 服务器证书
- `private.key` - 私钥
- `full_chain.pem` - 完整证书链
- `myssl_root.cer` - 根证书

**客户端证书：**
- `myssl_root.cer` - 根证书（最低要求）
- `cert.pem` - 客户端证书（可选，用于双向 TLS）
- `private.key` - 私钥（可选，用于双向 TLS）
- `full_chain.pem` - 完整证书链（可选）

## 自动化测试

运行完整的 TLS 功能测试：

```bash
cd hello-grpc-ts
./test_tls_with_scripts.sh
```

测试内容包括：
1. ✅ 非 TLS 模式测试
2. ✅ TLS 模式测试
3. ✅ 证书加载验证
4. ✅ 四种 gRPC 通信模式
   - Unary RPC
   - Server Streaming RPC
   - Client Streaming RPC
   - Bidirectional Streaming RPC

## 脚本特性

### 自动依赖检查
脚本会自动检查并安装必需的依赖：
```bash
Checking and installing dependencies if needed...
Dependencies already installed
```

### 自动构建
脚本会自动检查并构建 TypeScript 项目：
```bash
Checking TypeScript build...
Build already exists
```

### 证书验证
启用 TLS 时，脚本会验证证书文件是否存在：
```bash
TLS mode enabled
Using project certificates: /path/to/docker/tls/server_certs
Using certificates from: /path/to/docker/tls/server_certs
```

### 配置显示
脚本会显示当前配置：
```bash
Server configuration:
  Address: 0.0.0.0:50052
  TLS: Enabled
  Log Level: info
```

## 环境变量

脚本会自动设置以下环境变量：

| 变量名 | 说明 | 示例值 |
|--------|------|--------|
| GRPC_HELLO_SECURE | 启用 TLS | Y |
| CERT_BASE_PATH | 证书路径 | /path/to/certs |
| GRPC_SERVER_PORT | 服务器端口 | 50052 |
| GRPC_SERVER | 服务器地址 | localhost |
| LOG_LEVEL | 日志级别 | debug |

## 故障排除

### 问题 1: 证书文件未找到

**错误信息：**
```
Error: Certificate directory does not exist: /var/hello_grpc/server_certs
```

**解决方案：**
- 确保证书文件存在于 `docker/tls/server_certs/` 或 `docker/tls/client_certs/`
- 或者将证书复制到系统路径 `/var/hello_grpc/`

### 问题 2: 端口已被占用

**错误信息：**
```
Error: bind EADDRINUSE :::9996
```

**解决方案：**
```bash
# 查找占用端口的进程
lsof -i :9996

# 终止进程
kill <PID>

# 或使用不同的端口
./server_start.sh --port=9997
```

### 问题 3: TLS 连接失败

**错误信息：**
```
14 UNAVAILABLE: No connection established
```

**解决方案：**
1. 确认服务器已启动并监听正确的端口
2. 检查证书文件是否完整
3. 验证客户端和服务器使用相同的证书链
4. 查看详细日志：`--log=debug`

### 问题 4: 构建失败

**错误信息：**
```
Error: Cannot find module './common/landing_grpc_pb'
```

**解决方案：**
```bash
# 重新构建项目
npm run build

# 复制 proto 生成的文件
cp common/landing_*.js dist/common/
cp common/landing_*.d.ts dist/common/
```

## 日志文件

测试脚本会生成以下日志文件：

- `/tmp/ts_server_notls.log` - 非 TLS 服务器日志
- `/tmp/ts_client_notls.log` - 非 TLS 客户端日志
- `/tmp/ts_server_tls.log` - TLS 服务器日志
- `/tmp/ts_client_tls.log` - TLS 客户端日志

查看日志：
```bash
# 查看服务器日志
tail -f /tmp/ts_server_tls.log

# 查看客户端日志
tail -f /tmp/ts_client_tls.log

# 搜索错误
grep -i error /tmp/ts_server_tls.log
```

## 性能指标

基于测试结果的性能指标：

| 指标 | 非 TLS | TLS |
|------|--------|-----|
| 首次连接 | ~14ms | ~19ms |
| Unary RPC | 3-4ms | 4-5ms |
| Server Streaming | 2-4ms | 2-4ms |
| Client Streaming | 8-9ms | 8-9ms |
| Bidirectional Streaming | 6-7ms | 6-7ms |

## 与 Node.js 版本的兼容性

这些脚本与 `hello-grpc-nodejs` 的脚本保持一致的接口和行为：

| 特性 | Node.js | TypeScript |
|------|---------|------------|
| 参数格式 | ✅ | ✅ |
| TLS 支持 | ✅ | ✅ |
| 证书路径 | ✅ | ✅ |
| 自动构建 | ✅ | ✅ |
| 错误处理 | ✅ | ✅ |

## 相关文档

- [README.md](./README.md) - 项目总体说明
- [TLS_TEST_REPORT.md](./TLS_TEST_REPORT.md) - 详细的 TLS 测试报告
- [TLS_VERIFICATION_SUMMARY.md](./TLS_VERIFICATION_SUMMARY.md) - TLS 验证摘要

## 总结

这些启动脚本提供了：
- ✅ 简单易用的命令行接口
- ✅ 自动依赖和构建管理
- ✅ 灵活的 TLS 配置
- ✅ 完善的错误处理
- ✅ 与 Node.js 版本的一致性

使用这些脚本，你可以快速启动和测试 gRPC 服务，无需手动配置环境变量或构建项目。
