FROM rust:1.91-slim-bookworm AS build-base
# Change APT sources to Aliyun mirrors for the newer debian.sources format
RUN if [ -f "/etc/apt/sources.list.d/debian.sources" ]; then \
    cp /etc/apt/sources.list.d/debian.sources /etc/apt/sources.list.d/debian.sources.bak && \
    sed -i 's|http://deb.debian.org/debian|http://mirrors.aliyun.com/debian|g' /etc/apt/sources.list.d/debian.sources && \
    sed -i 's|http://deb.debian.org/debian-security|http://mirrors.aliyun.com/debian-security|g' /etc/apt/sources.list.d/debian.sources; \
    fi && \
    # For backwards compatibility, also check for traditional sources.list
    if [ -f "/etc/apt/sources.list" ]; then \
    cp /etc/apt/sources.list /etc/apt/sources.list.bak && \
    sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    sed -i 's/security.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list; \
    fi
RUN mkdir -p $HOME/.cargo \
    && echo '[source.crates-io]\nreplace-with = "ustc"\n\n[source.ustc]\nregistry = "https://mirrors.ustc.edu.cn/crates.io-index"' > $HOME/.cargo/config
ENV RUSTUP_DIST_SERVER=https://mirrors.ustc.edu.cn/rustup \
    RUSTUP_UPDATE_ROOT=https://mirrors.ustc.edu.cn/rustup/rustup
RUN apt-get update && apt-get install -y \
    protobuf-compiler \
    pkg-config \
    libssl-dev \
    git \
    && rm -rf /var/lib/apt/lists/*
COPY hello-grpc-rust /app/hello-grpc/hello-grpc-rust
COPY proto /app/hello-grpc/proto
COPY docker/tls/server_certs /var/hello_grpc/server_certs/
COPY docker/tls/client_certs /var/hello_grpc/client_certs/
WORKDIR /app/hello-grpc/hello-grpc-rust
RUN cargo build --release

FROM debian:bookworm-slim AS server
# Change APT sources to Aliyun mirrors for the newer debian.sources format
RUN if [ -f "/etc/apt/sources.list.d/debian.sources" ]; then \
    cp /etc/apt/sources.list.d/debian.sources /etc/apt/sources.list.d/debian.sources.bak && \
    sed -i 's|http://deb.debian.org/debian|http://mirrors.aliyun.com/debian|g' /etc/apt/sources.list.d/debian.sources && \
    sed -i 's|http://deb.debian.org/debian-security|http://mirrors.aliyun.com/debian-security|g' /etc/apt/sources.list.d/debian.sources; \
    fi && \
    # For backwards compatibility, also check for traditional sources.list
    if [ -f "/etc/apt/sources.list" ]; then \
    cp /etc/apt/sources.list /etc/apt/sources.list.bak && \
    sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    sed -i 's/security.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list; \
    fi
RUN apt-get update && apt-get install -y \
    libssl-dev \
    ca-certificates \
    tini \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build-base /app/hello-grpc/hello-grpc-rust/target/release/proto-server /app/server
COPY --from=build-base /app/hello-grpc/hello-grpc-rust/config/log4rs.yml /app/config/log4rs.yml
COPY docker/tls/server_certs /var/hello_grpc/server_certs/
COPY docker/tls/client_certs /var/hello_grpc/client_certs/
ENV RUST_BACKTRACE=1
# Use tini as init system to properly handle signals
ENTRYPOINT ["/usr/bin/tini", "--", "/app/server"]

FROM debian:bookworm-slim AS client
# Change APT sources to Aliyun mirrors for the newer debian.sources format
RUN if [ -f "/etc/apt/sources.list.d/debian.sources" ]; then \
    cp /etc/apt/sources.list.d/debian.sources /etc/apt/sources.list.d/debian.sources.bak && \
    sed -i 's|http://deb.debian.org/debian|http://mirrors.aliyun.com/debian|g' /etc/apt/sources.list.d/debian.sources && \
    sed -i 's|http://deb.debian.org/debian-security|http://mirrors.aliyun.com/debian-security|g' /etc/apt/sources.list.d/debian.sources; \
    fi && \
    # For backwards compatibility, also check for traditional sources.list
    if [ -f "/etc/apt/sources.list" ]; then \
    cp /etc/apt/sources.list /etc/apt/sources.list.bak && \
    sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    sed -i 's/security.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list; \
    fi
RUN apt-get update && apt-get install -y \
    libssl-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build-base /app/hello-grpc/hello-grpc-rust/target/release/proto-client /app/client
COPY --from=build-base /app/hello-grpc/hello-grpc-rust/config/log4rs.yml /app/config/log4rs.yml
COPY docker/tls/client_certs /var/hello_grpc/client_certs/
COPY docker/tls/server_certs /var/hello_grpc/server_certs/
ENTRYPOINT ["/app/client"]