FROM rust:1.49.0-alpine3.12
COPY proto-server grpc-server
ENTRYPOINT ["./grpc-server"]