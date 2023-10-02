FROM swift:5.8.1 as builder
# https://hub.docker.com/_/swift/tags Ubuntu 22.04

COPY hello-grpc-swift building
WORKDIR /building

RUN swift package resolve
RUN swift build -c release
# 收集依赖库
COPY pkg-swift-deps.sh /usr/bin/pkg-swift-deps
RUN chmod +x /usr/bin/pkg-swift-deps
# RUN pkg-swift-deps /building/.build/x86_64-unknown-linux-gnu/release/HelloServer
# pkg-swift-deps /building/.build/x86_64-unknown-linux-gnu/release/HelloClient

FROM swift:5.8.1-slim as server
COPY --from=builder /usr/lib/swift/linux/libswiftCore.so /usr/lib/swift/linux/
COPY --from=builder /usr/lib/swift/linux/libswiftGlibc.so /usr/lib/swift/linux/
COPY --from=builder /lib/x86_64-linux-gnu/libm.so.6 /usr/lib/swift/linux/
COPY --from=builder /usr/lib/swift/linux/libFoundation.so /usr/lib/swift/linux/
COPY --from=builder /usr/lib/swift/linux/libswiftDispatch.so /usr/lib/swift/linux/
COPY --from=builder /usr/lib/swift/linux/libdispatch.so /usr/lib/swift/linux/
COPY --from=builder /usr/lib/swift/linux/libBlocksRuntime.so /usr/lib/swift/linux/
COPY --from=builder /usr/lib/swift/linux/libswift_RegexParser.so /usr/lib/swift/linux/
COPY --from=builder /usr/lib/swift/linux/libswift_StringProcessing.so /usr/lib/swift/linux/
COPY --from=builder /usr/lib/swift/linux/libswift_Concurrency.so /usr/lib/swift/linux/
COPY --from=builder /usr/lib/swift/linux/libswiftCore.so /usr/lib/swift/linux/
COPY --from=builder /lib/x86_64-linux-gnu/libstdc++.so.6 /usr/lib/swift/linux/
COPY --from=builder /lib/x86_64-linux-gnu/libz.so.1 /usr/lib/swift/linux/
COPY --from=builder /lib/x86_64-linux-gnu/libgcc_s.so.1 /usr/lib/swift/linux/
COPY --from=builder /lib/x86_64-linux-gnu/libc.so.6 /usr/lib/swift/linux/
COPY --from=builder /lib64/ld-linux-x86-64.so.2 /usr/lib/swift/linux/
COPY --from=builder /usr/lib/swift/linux/libicuucswift.so.65 /usr/lib/swift/linux/
COPY --from=builder /usr/lib/swift/linux/libicui18nswift.so.65 /usr/lib/swift/linux/
COPY --from=builder /usr/lib/swift/linux/libicudataswift.so.65 /usr/lib/swift/linux/
#
COPY --from=builder /building/.build/x86_64-unknown-linux-gnu/release/HelloServer /hello-grpc-swift/
WORKDIR /hello-grpc-swift
# 将依赖库解压到相应路径
# COPY --from=builder /building/swift_libs.tar.gz /tmp/swift_libs.tar.gz
# RUN tar -xzvf /tmp/swift_libs.tar.gz && \
#     rm -rf /tmp/*
RUN chmod +x HelloServer
CMD ["/hello-grpc-swift/HelloServer"]

FROM swift:5.8.1-slim as client
COPY --from=builder /usr/lib/swift/linux/libswiftCore.so /usr/lib/swift/linux/
COPY --from=builder /usr/lib/swift/linux/libswiftGlibc.so /usr/lib/swift/linux/
COPY --from=builder /lib/x86_64-linux-gnu/libm.so.6 /usr/lib/swift/linux/
COPY --from=builder /usr/lib/swift/linux/libFoundation.so /usr/lib/swift/linux/
COPY --from=builder /usr/lib/swift/linux/libswiftDispatch.so /usr/lib/swift/linux/
COPY --from=builder /usr/lib/swift/linux/libdispatch.so /usr/lib/swift/linux/
COPY --from=builder /usr/lib/swift/linux/libBlocksRuntime.so /usr/lib/swift/linux/
COPY --from=builder /usr/lib/swift/linux/libswift_RegexParser.so /usr/lib/swift/linux/
COPY --from=builder /usr/lib/swift/linux/libswift_StringProcessing.so /usr/lib/swift/linux/
COPY --from=builder /usr/lib/swift/linux/libswift_Concurrency.so /usr/lib/swift/linux/
COPY --from=builder /usr/lib/swift/linux/libswiftCore.so /usr/lib/swift/linux/
COPY --from=builder /lib/x86_64-linux-gnu/libstdc++.so.6 /usr/lib/swift/linux/
COPY --from=builder /lib/x86_64-linux-gnu/libz.so.1 /usr/lib/swift/linux/
COPY --from=builder /lib/x86_64-linux-gnu/libgcc_s.so.1 /usr/lib/swift/linux/
COPY --from=builder /lib/x86_64-linux-gnu/libc.so.6 /usr/lib/swift/linux/
COPY --from=builder /lib64/ld-linux-x86-64.so.2 /usr/lib/swift/linux/
COPY --from=builder /usr/lib/swift/linux/libicuucswift.so.65 /usr/lib/swift/linux/
COPY --from=builder /usr/lib/swift/linux/libicui18nswift.so.65 /usr/lib/swift/linux/
COPY --from=builder /usr/lib/swift/linux/libicudataswift.so.65 /usr/lib/swift/linux/
#
COPY --from=builder /building/.build/x86_64-unknown-linux-gnu/release/HelloClient /hello-grpc-swift/
WORKDIR /hello-grpc-swift
# 将依赖库解压到相应路径
# COPY --from=builder /building/swift_libs.tar.gz /tmp/swift_libs.tar.gz
# RUN tar -xzvf /tmp/swift_libs.tar.gz && \
#     rm -rf /tmp/*
RUN chmod +x HelloClient
CMD ["/hello-grpc-swift/HelloClient"]