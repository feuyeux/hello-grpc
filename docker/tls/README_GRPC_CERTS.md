# gRPC TLS 证书使用说明

## 证书生成

本目录包含用于 gRPC TLS 通信的证书文件。

### 生成新证书

#### Windows (PowerShell):
```powershell
.\generate_grpc_certs.ps1
```

#### Linux/Mac (Bash):
```bash
./generate_grpc_certs.sh
```

## 证书文件说明

生成的证书文件包括：

### CA 证书
- `ca.crt` - CA 根证书
- `ca.key` - CA 私钥

### 服务器证书 (server_certs/)
- `cert.pem` - 服务器证书
- `private.key` - 服务器私钥
- `full_chain.pem` - 完整证书链（服务器证书 + CA 证书）
- `myssl_root.cer` - CA 根证书副本

### 客户端证书 (client_certs/)
- `myssl_root.cer` - CA 根证书（用于验证服务器）
- `cert.pem` - 服务器证书副本
- `full_chain.pem` - 完整证书链副本
- `private.key` - 私钥副本

## 证书特性

生成的证书具有以下特性：

- **有效期**: 10 年
- **密钥长度**: 4096 位 RSA
- **扩展用途**: TLS Web Server Authentication
- **主题备用名称 (SAN)**:
  - DNS: hello.grpc.io
  - DNS: localhost
  - IP: 127.0.0.1
  - IP: ::1

## 使用方法

### 启动 TLS Server

#### Windows (PowerShell):
```powershell
cd hello-grpc-nodejs
$env:GRPC_HELLO_SECURE="Y"
$env:CERT_BASE_PATH="D:\coding\hello-grpc\docker\tls\server_certs"
$env:GRPC_SERVER_PORT="50051"
node proto_server.js
```

#### Linux/Mac (Bash):
```bash
cd hello-grpc-nodejs
export GRPC_HELLO_SECURE=Y
export CERT_BASE_PATH=/path/to/docker/tls/server_certs
export GRPC_SERVER_PORT=50051
node proto_server.js
```

### 启动 TLS Client

#### Windows (PowerShell):
```powershell
cd hello-grpc-nodejs
$env:GRPC_HELLO_SECURE="Y"
$env:CERT_BASE_PATH="D:\coding\hello-grpc\docker\tls\client_certs"
$env:GRPC_SERVER_PORT="50051"
node proto_client.js
```

#### Linux/Mac (Bash):
```bash
cd hello-grpc-nodejs
export GRPC_HELLO_SECURE=Y
export CERT_BASE_PATH=/path/to/docker/tls/client_certs
export GRPC_SERVER_PORT=50051
node proto_client.js
```

## 环境变量说明

- `GRPC_HELLO_SECURE`: 设置为 "Y" 启用 TLS
- `CERT_BASE_PATH`: 证书文件所在目录的绝对路径
- `GRPC_SERVER_PORT`: gRPC 服务器端口（默认 9996）
- `TLS_SERVER_NAME`: TLS 服务器名称（默认 hello.grpc.io）

## 验证证书

验证服务器证书：
```bash
openssl verify -CAfile ca.crt server_certs/cert.pem
```

查看证书详情：
```bash
openssl x509 -in server_certs/cert.pem -text -noout
```

测试 TLS 连接：
```bash
openssl s_client -connect localhost:50051 -CAfile client_certs/myssl_root.cer -servername hello.grpc.io
```

## 注意事项

1. 这些证书仅用于开发和测试环境
2. 生产环境请使用由受信任的 CA 签发的证书
3. 证书文件包含私钥，请妥善保管，不要提交到版本控制系统
4. 如需更改证书的 CN 或 SAN，请修改生成脚本中的相应参数

## 故障排除

### 证书用途错误
如果遇到 "unsuitable certificate purpose" 错误，请确保：
- 证书包含 `extendedKeyUsage = serverAuth`
- 使用本脚本重新生成证书

### 连接失败
如果客户端无法连接到服务器：
1. 确认服务器已启动并监听正确的端口
2. 检查 `CERT_BASE_PATH` 是否指向正确的目录
3. 确认 CA 证书文件存在且可读
4. 验证服务器名称与证书的 CN 或 SAN 匹配

### 证书验证失败
如果证书验证失败：
1. 确保客户端使用正确的 CA 证书（myssl_root.cer）
2. 检查证书是否过期
3. 验证证书链是否完整
