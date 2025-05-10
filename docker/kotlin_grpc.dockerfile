FROM gradle:8.13-jdk21 AS build-base

# Copy the entire project for building
ARG PROJECT_ROOT=.
WORKDIR /app/hello-grpc
COPY hello-grpc-kotlin /app/hello-grpc/hello-grpc-kotlin
COPY proto /app/hello-grpc/proto

# Build Kotlin server and client
WORKDIR /app/hello-grpc/hello-grpc-kotlin
RUN gradle clean distTar

FROM eclipse-temurin:24-jre-alpine AS server
WORKDIR /app
COPY --from=build-base /app/hello-grpc/hello-grpc-kotlin/server/build/distributions/server.tar /app/
RUN tar -xf server.tar
# 创建证书目录
RUN mkdir -p /var/hello_grpc/server_certs /var/hello_grpc/client_certs
# 使用简化路径，复制目录内的文件而不是整个目录
COPY docker/tls/server_certs/* /var/hello_grpc/server_certs/
COPY docker/tls/client_certs/* /var/hello_grpc/client_certs/
ENTRYPOINT ["/app/server/bin/server"]

FROM eclipse-temurin:24-jre-alpine AS client
WORKDIR /app
COPY --from=build-base /app/hello-grpc/hello-grpc-kotlin/client/build/distributions/client.tar /app/
RUN tar -xf client.tar
# 创建证书目录
RUN mkdir -p /var/hello_grpc/client_certs
# 使用简化路径，复制目录内的文件而不是整个目录
COPY docker/tls/client_certs/* /var/hello_grpc/client_certs/
ENTRYPOINT ["/app/client/bin/client"]