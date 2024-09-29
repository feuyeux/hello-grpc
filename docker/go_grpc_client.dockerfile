FROM golang:1.23-alpine
COPY proto_client grpc-client
COPY tls/client_certs /var/hello_grpc/client_certs
ENTRYPOINT ["./grpc-client"]
