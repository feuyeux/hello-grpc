FROM swift:5

WORKDIR /build
COPY Sources ./Sources
COPY Package.swift .

RUN swift package resolve
RUN swift build

COPY pkg-swift-deps.sh /usr/bin/pkg-swift-deps
RUN pkg-swift-deps /build/.build/x86_64-unknown-linux/debug/swift-multistage-test

FROM busybox:glibc

COPY --from=0 /build/swift_libs.tar.gz /tmp/swift_libs.tar.gz
COPY --from=0 /build/.build/x86_64-unknown-linux/debug/swift-multistage-test /usr/bin/

RUN tar -xzvf /tmp/swift_libs.tar.gz && \
    rm -rf /tmp/*

CMD ["swift-multistage-test"]