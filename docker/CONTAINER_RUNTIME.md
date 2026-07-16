# 在 macOS 上使用 Apple `container`

本指南说明如何在本仓库的镜像启动脚本中使用 Apple 开源的 `container` 运行时。

---

## 1. 适用范围

**Apple `container`** 在 macOS 26 及以上版本的 Apple Silicon Mac 上运行 Linux OCI 容器。本仓库的 `feuyeux/grpc_*` Docker Hub 镜像可作为 OCI 镜像被拉取和运行。

脚本会按以下规则选择运行时：

| 条件 | 默认运行时 |
|---|---|
| macOS、Apple Silicon、已安装 `container` | `container` |
| 其他平台或未安装 `container` | Docker |

可使用环境变量覆盖选择：

```sh
GRPC_CONTAINER_RUNTIME=container sh docker/run_container.sh -l go -c server
GRPC_CONTAINER_RUNTIME=docker sh docker/run_container.sh -l go -c server
```

---

## 2. 首次配置

安装 Apple 的签名安装包后，启动服务：

```sh
container system start
container system status
```

服务端容器通过 `-p 9996:9996` 将 gRPC 端口发布到 macOS 的回环地址。客户端容器运行在轻量级虚拟机中，不能把该地址当作自己的 `localhost` 使用。因此需要创建一次 **宿主机访问域名**：

```sh
sudo container system dns create host.container.internal --localhost 203.0.113.113
```

该命令会创建本机 DNS 和包过滤规则。它需要管理员权限；Apple 文档指出，重启后该规则会被移除，届时重新执行此命令即可。

---

## 3. 启动示例

在两个终端中执行：

```sh
# 终端 1：启动服务端。脚本会自动选用 container。
sh docker/run_container.sh -l go -c server
```

```sh
# 终端 2：运行客户端。
sh docker/run_container.sh -l go -c client
```

运行客户端前，脚本会检查 `host.container.internal` 是否存在。缺失时会输出创建命令并停止，避免客户端错误连接至自身的回环地址。

---

## 4. 构建与限制

`docker/build_image.sh` 同样支持选择 `container`，并将本脚本使用的 `build`、`run`、`images` 和 `info` 子命令映射到对应的 Apple 命令。对于构建失败、私有注册表认证或复杂 BuildKit 配置，优先显式使用 Docker：

```sh
GRPC_CONTAINER_RUNTIME=docker sh docker/build_image.sh -l go -c server
```

以下场景仍以 Docker 为准，暂未由本次适配覆盖：

- `docker/smoke_test_all.sh` 与 `integration-tests/test-interop.sh`
- Kubernetes、服务网格和基准测试脚本
- 依赖 Docker 自定义网络、`host-gateway` 或 Docker Compose 的示例

`container` 默认优先运行 `linux/arm64` 镜像。使用本仓库镜像前，应确认目标镜像包含 `arm64` 清单；不包含时可改用 Docker，或按 Apple `container` 文档评估 Rosetta 支持。

---

## 5. 验证与排障

先确认运行时和系统服务：

```sh
container --version
container system status
container image list
```

查看已运行的容器：

```sh
container list --all
```

如需恢复 Docker 行为，单次命令中设置：

```sh
GRPC_CONTAINER_RUNTIME=docker sh docker/run_container.sh -l go -c server
```

如果 `container system status` 失败，先执行 `container system start`。如果客户端无法访问服务端，先重新创建 `host.container.internal`，再确认服务端容器仍在运行且端口 `9996` 已发布。
