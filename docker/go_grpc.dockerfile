FROM golang:1.24-alpine AS server
# https://hub.docker.com/_/golang
COPY proto_server grpc-server
COPY tls/server_certs /var/hello_grpc/server_certs
COPY tls/client_certs /var/hello_grpc/client_certs
ENTRYPOINT ["./grpc-server"]

FROM golang:1.24-alpine AS client
COPY proto_client grpc-client
COPY tls/client_certs /var/hello_grpc/client_certs
ENTRYPOINT ["./grpc-client"]
