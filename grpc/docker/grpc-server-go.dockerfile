FROM golang:1.18-alpine
COPY proto_server grpc-server
COPY tls/server_certs /var/hello_grpc/server_certs
COPY tls/client_certs /var/hello_grpc/client_certs
ENTRYPOINT ["./grpc-server"]