FROM rust:1.96.1-slim-bookworm AS build-base
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
RUN apt-get update && apt-get install -y \
    libssl-dev \
    ca-certificates \
    tini \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --create-home --shell /usr/sbin/nologin app
WORKDIR /app
COPY --from=build-base --chown=app:app /app/hello-grpc/hello-grpc-rust/target/release/proto-server /app/server
COPY --from=build-base --chown=app:app /app/hello-grpc/hello-grpc-rust/config/log4rs.yml /app/config/log4rs.yml
COPY --chown=app:app docker/tls/server_certs /var/hello_grpc/server_certs/
COPY --chown=app:app docker/tls/client_certs /var/hello_grpc/client_certs/
ENV RUST_BACKTRACE=1
USER app
# Use tini as init system to properly handle signals
ENTRYPOINT ["/usr/bin/tini", "--", "/app/server"]

FROM debian:bookworm-slim AS client
RUN apt-get update && apt-get install -y \
    libssl-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --create-home --shell /usr/sbin/nologin app
WORKDIR /app
COPY --from=build-base --chown=app:app /app/hello-grpc/hello-grpc-rust/target/release/proto-client /app/client
COPY --from=build-base --chown=app:app /app/hello-grpc/hello-grpc-rust/config/log4rs.yml /app/config/log4rs.yml
COPY --chown=app:app docker/tls/client_certs /var/hello_grpc/client_certs/
COPY --chown=app:app docker/tls/server_certs /var/hello_grpc/server_certs/
USER app
ENTRYPOINT ["/app/client"]
