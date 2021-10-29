# https://hub.docker.com/_/rust?tab=tags&page=1&ordering=last_updated&name=alpine
# FROM rust:1.55.0-alpine3.14 AS build
FROM rust:alpine AS build
ENV RUSTUP_DIST_SERVER https://mirrors.ustc.edu.cn/rust-static
ENV RUSTUP_UPDATE_ROOT https://mirrors.ustc.edu.cn/rust-static/rustup
RUN apk add --update \
    protobuf \
    musl-dev \
    && rm -rf /var/cache/apk/*
RUN rustup toolchain install nightly && rustup default nightly && rustup update && rustup component add rustfmt
WORKDIR /source
COPY hello-grpc-rust .
COPY tls/server_certs /var/hello_grpc/server_certs
COPY tls/client_certs /var/hello_grpc/client_certs
RUN cargo build --release --bin proto-server
RUN cargo build --release --bin proto-client

FROM alpine AS server
WORKDIR /app
COPY --from=feuyeux/grpc_rust:1.0.0 /source/target/release/proto-server .
COPY tls/server_certs /var/hello_grpc/server_certs
COPY tls/client_certs /var/hello_grpc/client_certs
COPY hello-grpc-rust/config/log4rs.yml config/log4rs.yml
ENTRYPOINT ["./proto-server"]

FROM alpine AS client
WORKDIR /app
COPY --from=feuyeux/grpc_rust:1.0.0 /source/target/release/proto-client .
COPY tls/client_certs /var/hello_grpc/client_certs
COPY hello-grpc-rust/config/log4rs.yml config/log4rs.yml
CMD ["./proto-client"]