FROM golang:1.15-alpine
COPY proto_server grpc-server
COPY tls/server_certs /var/hello_grpc/server_certs
ENTRYPOINT ["./grpc-server"]