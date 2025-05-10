FROM feuyeux/grpc_php_base:1.0.0 AS build-base

# Copy the entire project for building
ARG PROJECT_ROOT=.
WORKDIR /app/hello-grpc
COPY hello-grpc-php /app/hello-grpc/hello-grpc-php
COPY proto /app/hello-grpc/proto
COPY proto2x.sh /app/hello-grpc/
# Generate PHP code from protobuf
WORKDIR /app/hello-grpc/hello-grpc-php
RUN ../proto2x.sh php
RUN composer install --no-interaction --no-progress --no-scripts --ignore-platform-reqs

FROM feuyeux/grpc_php_base:1.0.0 AS server
WORKDIR /app
COPY --from=build-base /app/hello-grpc/hello-grpc-php /app
COPY docker/tls/server_certs/* /var/hello_grpc/server_certs/
COPY docker/tls/client_certs/* /var/hello_grpc/client_certs/

ENTRYPOINT ["php", "hello_server.php"]

FROM feuyeux/grpc_php_base:1.0.0 AS client
WORKDIR /app
COPY --from=build-base /app/hello-grpc/hello-grpc-php /app
COPY docker/tls/client_certs/* /var/hello_grpc/client_certs/

ENTRYPOINT ["php", "hello_client.php"]
