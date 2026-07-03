# hello-grpc 工程瘦身分析报告

## 七、Tier F — 文件内 dead code(~250 行)

### F1. csharp 内部 dead code(~170 行)

| 文件 | 死代码段 | 行数 |
|---|---|---|
| `Common/Connection.cs` | `LoadCertificateWithPrivateKey` + `ParsePemPrivateKey` | 75 |
| `Common/ErrorMapper.cs` | `RetryConfig` 类 + 3 个 retry 方法 + `ExecuteWithRetry` | 165 |
| `Common/Otel.cs` | `AddToAspNetCore` 扩展方法(注释明说"hook server side only") | 6 |
| `HelloServer/ProtoServer.cs` | `LoadCertificateWithPrivateKey` + `ParsePemPrivateKey`(与 Connection.cs 重复) | 70 |

### F2. java 内部 dead code(~4 行)

| 文件 | 死代码段 |
|---|---|
| `tracing/ErrorMapper.java` | `isRetryableError` 方法(L36-39) |

### F3. python 内部 dead code(已包含在 B11 文件删除里)

`conn/error_mapper.py` 完整文件就是 dead code。

### F4. python log_formatter.py 内部 dead code

`log_formatter.py` 完整保留(被 server 引用),但其中 `format_error` 方法在 server 中未使用。

---

## 八、Tier G — .gitignore 漏洞修复

### G1. 顶层 `.gitignore`

需添加:
```gitignore
.hermes/
MODULE.bazel.lock
```

### G2. hello-grpc-kotlin/.gitignore

需添加:
```gitignore
build/reports/
```

### G3. hello-grpc-php/.gitignore

不存在(项目根有 `.gitignore` 但 php 目录没有),需创建:
```gitignore
/vendor/
composer.lock
.phpunit.result.cache
.phpunit.cache/
```

---

## 九、未跟踪文件层核查(working dir 残留)

### U1. hello-grpc-app/gen/apple/

Tauri 自动生成的 Xcode 工程骨架(17 个文件)。理论上应该被 `.gitignore` 忽略,但项目根 `.gitignore` **只 ignore 了 `gen/schemas`,未 ignore `gen/apple`**。

**判断**:tauri.conf.json L40-42 配置了 iOS target + developmentTeam,所以 gen/apple **对功能是必要的**(Tauri iOS 构建依赖它)。

**建议**:
- 保留已入库的 gen/apple/(避免破坏现有开发环境)
- 修改 `.gitignore` 加 `src-tauri/gen/apple/` 防止未来再次扩大(虽然已经入库)

### U2. hello-grpc-cpp/MODULE.bazel.lock

5462 行 bazel 锁文件,在 working dir 中存在但 **未被 git 跟踪**。是否需要入库由项目约定决定,**建议 ignore**(多数 bazel 开源项目都不跟踪)。

### U3. log/hello-grpc.log

`log/` 目录下的 hello-grpc.log,grep 显示 0 引用,工作目录残留。本地运行产生的日志。

---
