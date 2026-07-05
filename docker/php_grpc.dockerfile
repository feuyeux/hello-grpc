# Build-base: slim Alpine gRPC PHP base image (php:8.5-cli-alpine + composer + 
# protoc + grpc_php_plugin + grpc.so, ~223MB uncompressed vs 1.96GB previously).
# We only need to add project sources and run composer install here.
FROM feuyeux/grpc_php_base:slim AS build-base

WORKDIR /app/hello-grpc
COPY hello-grpc-php /app/hello-grpc/hello-grpc-php
COPY proto /app/hello-grpc/proto
COPY scripts/proto2x.sh /app/hello-grpc/
WORKDIR /app/hello-grpc/hello-grpc-php
RUN ../proto2x.sh php
RUN composer install --no-interaction --no-progress --no-scripts --ignore-platform-reqs

# Runtime base reuses the same slim image (~223MB).
# Final published client/server images inherit only the slim layer below
# (~170-190MB vs ~1.87GB previously, reduction of ~90%).
FROM feuyeux/grpc_php_base:slim AS runtime-base

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
