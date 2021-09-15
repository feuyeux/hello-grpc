FROM rust:1.49.0-alpine3.12
COPY proto-client grpc-client
# ENTRYPOINT ["./grpc-client"]