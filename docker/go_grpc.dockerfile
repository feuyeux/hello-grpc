FROM golang:1.24-alpine AS build-base
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories
RUN apk add --update git bash protobuf protobuf-dev make && rm -rf /var/cache/apk/*

ENV GOPROXY=https://goproxy.cn,direct
ENV GO111MODULE=on
# Install the required Go protoc plugins
RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
RUN go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

COPY hello-grpc-go /app/hello-grpc/hello-grpc-go
COPY proto /app/hello-grpc/proto
COPY proto2x.sh /app/hello-grpc

WORKDIR /app/hello-grpc/hello-grpc-go
RUN bash init.sh
WORKDIR /app/hello-grpc
# Generate protobuf code
RUN bash proto2x.sh go
# Build
WORKDIR /app/hello-grpc/hello-grpc-go
RUN go build -o proto_server server/proto_server.go
RUN go build -o proto_client client/proto_client.go

FROM alpine:latest AS server
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories
RUN apk add --update ca-certificates && rm -rf /var/cache/apk/*

WORKDIR /app
COPY --from=build-base /app/hello-grpc/hello-grpc-go/proto_server /app/
# 创建证书目录
RUN mkdir -p /var/hello_grpc/server_certs /var/hello_grpc/client_certs
# 使用简化路径，复制目录内的文件而不是整个目录
COPY docker/tls/server_certs/* /var/hello_grpc/server_certs/
COPY docker/tls/client_certs/* /var/hello_grpc/client_certs/

ENTRYPOINT ["./proto_server"]

FROM alpine:latest AS client
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories
RUN apk add --update ca-certificates && rm -rf /var/cache/apk/*

WORKDIR /app
COPY --from=build-base /app/hello-grpc/hello-grpc-go/proto_client /app/
# 创建证书目录
RUN mkdir -p /var/hello_grpc/client_certs
# 使用简化路径，复制目录内的文件而不是整个目录
COPY docker/tls/client_certs/* /var/hello_grpc/client_certs/

ENTRYPOINT ["./proto_client"]
