# Build-base: alpine gRPC PHP base image (php:8.5-cli-alpine + composer + protoc
# + grpc_php_plugin + grpc.so already installed). We only need to add project
# sources and run composer install here — no more pecl/grpc.so compilation
# inside the per-target build (saves ~10 min per client/server build).
FROM feuyeux/grpc_php_base:latest AS build-base

WORKDIR /app/hello-grpc
COPY hello-grpc-php /app/hello-grpc/hello-grpc-php
COPY proto /app/hello-grpc/proto
COPY scripts/proto2x.sh /app/hello-grpc/
WORKDIR /app/hello-grpc/hello-grpc-php
RUN ../proto2x.sh php
RUN composer install --no-interaction --no-progress --no-scripts --ignore-platform-reqs

# Runtime base reuses the same image — grpc.so, protoc, grpc_php_plugin
# all already present. Final published client/server images inherit only the
# slim layer below (~150MB instead of ~1.5GB previously).
FROM feuyeux/grpc_php_base:latest AS runtime-base

FROM runtime-base AS server
WORKDIR /app
COPY --from=build-base /app/hello-grpc/hello-grpc-php /app
RUN mkdir -p /var/hello_grpc/server_certs /var/hello_grpc/client_certs
COPY docker/tls/server_certs/* /var/hello_grpc/server_certs/
COPY docker/tls/client_certs/* /var/hello_grpc/client_certs/

ENTRYPOINT ["php", "hello_server.php"]

FROM runtime-base AS client
WORKDIR /app
COPY --from=build-base /app/hello-grpc/hello-grpc-php /app
RUN mkdir -p /var/hello_grpc/client_certs
COPY docker/tls/client_certs/* /var/hello_grpc/client_certs/

ENTRYPOINT ["php", "hello_client.php"]
