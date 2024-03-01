FROM golang:1.22-alpine
COPY proto_client grpc-client
COPY tls/client_certs /var/hello_grpc/client_certs
ENTRYPOINT ["./grpc-client"]
