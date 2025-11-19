# 请重启服务器

代码已更新，请在服务器终端执行以下操作：

1. 按 Ctrl+C 停止当前服务器

2. 重新启动服务器：
```bash
cd hello-grpc-kotlin
bash scripts/server_start.sh --tls --port=9996
```

## 修改内容

### 服务器端 (ProtoServer.kt)
- 将 `ClientAuth.REQUIRE` 改为 `ClientAuth.OPTIONAL`
- 允许客户端不提供证书

### 客户端 (Connection.kt)  
- 注释掉客户端证书配置
- 只验证服务器证书，不发送客户端证书
- 这样更接近 TypeScript 的实现（已验证工作正常）

## 原因

双向 TLS（mutual TLS）配置可能导致握手失败。简化为单向 TLS（只验证服务器）更容易调试和使用。

服务器重启后，我会再次运行客户端测试。
