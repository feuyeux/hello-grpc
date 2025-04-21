FROM swift:6.0.1 AS builder
# https://hub.docker.com/_/swift

COPY hello-grpc-swift building
WORKDIR /building

RUN swift package resolve
RUN swift build -c release
# 收集依赖库
COPY swift_pkg_deps.sh /usr/bin/pkg-swift-deps
RUN chmod +x /usr/bin/pkg-swift-deps
# 运行build容器 获取依赖库
# docker run --rm -it docker.io/feuyeux/grpc_swift:1.0.0 bash
# pkg-swift-deps /building/.build/x86_64-unknown-linux-gnu/release/HelloServer
# pkg-swift-deps /building/.build/x86_64-unknown-linux-gnu/release/HelloClient

FROM swift:6.0.1-slim AS server
COPY --from=builder /building/.build/x86_64-unknown-linux-gnu/release/HelloServer /hello-grpc-swift/
WORKDIR /hello-grpc-swift
RUN chmod +x HelloServer
CMD ["/hello-grpc-swift/HelloServer"]

FROM swift:6.0.1-slim AS client
COPY --from=builder /building/.build/x86_64-unknown-linux-gnu/release/HelloClient /hello-grpc-swift/
WORKDIR /hello-grpc-swift
RUN chmod +x HelloClient
CMD ["/hello-grpc-swift/HelloClient"]