# hello-grpc 工程瘦身分析报告(已完结)

本报告的分析与整改已全部完成,保留此文件仅作为收尾记录。

## 整改结果(2026-07-04 核销)

| 项 | 内容 | 状态 |
|---|---|---|
| Tier F1 | C# dead code(`LoadCertificateWithPrivateKey`/`ParsePemPrivateKey`/`RetryConfig`/`ExecuteWithRetry`/`AddToAspNetCore`) | ✅ 已删除,源码中无残留 |
| Tier F2 | Java `ErrorMapper.isRetryableError` | ✅ 已失效——该方法现被 `common/ErrorMapper.java` 的重试路径实际调用,不再是 dead code |
| Tier F3 | Python `conn/error_mapper.py` | ✅ 已失效——client/server 均已引用,不再是 dead code |
| Tier G1 | 顶层 `.gitignore` 补 `.hermes/`、`MODULE.bazel.lock` | ✅ `.hermes/` 已加;`MODULE.bazel.lock` 由既有 `*.lock` 规则覆盖 |
| Tier G2 | kotlin `build/reports/` | ✅ 由顶层 `build/` 规则覆盖 |
| Tier G3 | php `.gitignore` | ✅ 已存在 |
| U1 | Tauri `gen/apple/` | ✅ `src-tauri/gen/` 已整体 ignore |
| U2 | `MODULE.bazel.lock` 未跟踪 | ✅ 由 `*.lock` 规则 ignore |
| U3 | 运行日志残留(`log/hello-grpc.log`、dart/cpp `log/`、`docker/smoke_logs/`) | ✅ 已删除,`.gitignore` 已覆盖 |
| 附加 | `proto_bk/` 目录名误导 | ✅ 已改名为 `proto-gateway/`,AGENTS.md 与 `scripts/k8s/transcoder/gen_pb.sh` 已同步 |
