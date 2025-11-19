# hello-grpc-kotlin TLS 状态

## 当前状态

⚠️ **TLS 功能部分完成，需要进一步调试**

## 已完成的工作

### ✅ 脚本标准化
- 脚本已移动到 `scripts/` 目录
- `server_start.sh` 和 `client_start.sh` 已更新
- 支持 `--tls` 参数
- 证书路径自动检测（优先使用项目本地证书）

### ✅ 服务器启动
- TLS 服务器可以成功启动
- 证书加载正常
- 监听端口 9996

```bash
bash scripts/server_start.sh --tls
```

**服务器日志：**
```
Using project certificates: /Users/han/coding/hello-grpc/docker/tls/server_certs
Using certificate paths: cert=.../cert.pem, key=.../private.pkcs8.key, chain=.../full_chain.pem, root=.../myssl_root.cer
Starting secure gRPC server with TLS on port 9996 [grpc.version=1.68.0]
Server started successfully
```

## ⚠️ 待解决问题

### 客户端 TLS 握手失败

**错误信息：**
```
Request failed - request_id: unary-1763537384733, method: Talk, error_code: UNAVAILABLE, message: io exception
15:29:44.791 Request failed - request_id: unary-xxx, method: Talk, error_code: UNAVAILABLE, message: io exception
```

**已验证（2025-11-19 15:29）：**
- ✅ 服务器正在运行并监听端口 9996
- ✅ 客户端可以连接到服务器
- ✅ 证书文件路径正确
- ✅ 证书文件加载成功
- ❌ TLS 握手失败

**可能原因：**
1. **证书链验证问题** - 最可能的原因
   - 服务器要求客户端证书（ClientAuth.REQUIRE）
   - 客户端发送的证书可能无法被服务器验证
   
2. **服务器名称验证（SNI）配置**
   - 客户端使用 `overrideAuthority("hello.grpc.io")`
   - 证书中的 CN 必须匹配
   
3. **SSL/TLS 协议版本不匹配**
   - 客户端和服务器可能使用不同的 TLS 版本

4. **证书格式问题**
   - Kotlin 使用 PKCS8 格式的私钥
   - 可能需要检查证书编码

## 已尝试的修复

### 1. 修改服务器客户端认证模式
```kotlin
// 从 ClientAuth.REQUIRE 改为 ClientAuth.OPTIONAL
sslContextBuilder.clientAuth(ClientAuth.OPTIONAL)

// 尝试完全禁用客户端证书要求
// sslContextBuilder.clientAuth(ClientAuth.NONE)
```

### 2. 使用绝对路径
脚本已更新为使用绝对路径：
```bash
PROJECT_CERT_PATH="$(cd "$PROJECT_ROOT/../docker/tls/server_certs" 2>/dev/null && pwd)"
```

### 3. 证书文件验证
- ✅ 所有证书文件存在
- ✅ 证书格式正确（PEM）
- ✅ 私钥格式正确（PKCS8）

## 下一步调试建议

### 1. 启用详细的 SSL 调试日志
```bash
export JAVA_OPTS="-Djavax.net.debug=ssl:handshake:verbose"
bash scripts/server_start.sh --tls
```

### 2. 检查证书链完整性
```bash
# 验证服务器证书链
openssl verify -CAfile docker/tls/server_certs/myssl_root.cer \
  docker/tls/server_certs/full_chain.pem

# 验证客户端证书链
openssl verify -CAfile docker/tls/client_certs/myssl_root.cer \
  docker/tls/client_certs/full_chain.pem
```

### 3. 简化 SSL 配置
尝试最简单的 TLS 配置：
```kotlin
// 服务器端 - 只使用服务器证书，不验证客户端
private fun buildSslContext(): SslContextBuilder? {
    return SslContextBuilder.forServer(
        File(certChainPath),
        File(certKeyPath)
    )
}

// 客户端 - 只验证服务器证书
private fun buildSslContext(): SslContext {
    val builder: SslContextBuilder = GrpcSslContexts.forClient()
    builder.trustManager(File(rootCert))
    // 不发送客户端证书
    // builder.keyManager(File(certChain), File(certKey))
    return builder.build()
}
```

### 4. 测试非 TLS 模式
确认非 TLS 模式工作正常：
```bash
bash scripts/server_start.sh --port=9996
bash scripts/client_start.sh --addr=localhost:9996
```

## 相关文件

### 服务器 TLS 配置
- `server/src/main/kotlin/org/feuyeux/grpc/ProtoServer.kt` - 第 204-215 行

### 客户端 TLS 配置
- `stub/src/main/kotlin/org/feuyeux/grpc/conn/Connection.kt` - 第 54-60 行

### 启动脚本
- `scripts/server_start.sh`
- `scripts/client_start.sh`

## 参考

### 成功的实现
- **hello-grpc-ts** - TypeScript 实现，TLS 完全正常
- **hello-grpc-nodejs** - Node.js 实现，TLS 完全正常

### Kotlin/Java gRPC TLS 文档
- [gRPC Java Security](https://grpc.io/docs/guides/auth/)
- [Netty SSL Context](https://netty.io/4.1/api/io/netty/handler/ssl/SslContext.html)

## 临时解决方案

在 TLS 问题解决之前，可以使用非 TLS 模式：

```bash
# 服务器
bash scripts/server_start.sh --port=9996

# 客户端
bash scripts/client_start.sh --addr=localhost:9996
```

---

**最后更新**: 2025-11-19  
**状态**: 需要进一步调试 TLS 握手问题
