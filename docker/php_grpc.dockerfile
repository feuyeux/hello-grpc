FROM feuyeux/grpc_php_base:1.0.0 AS server
COPY hello-grpc-php /hello-grpc
WORKDIR /hello-grpc
RUN composer install
COPY tls/server_certs /var/hello_grpc/server_certs
CMD ["sh","server_start.sh"]

FROM feuyeux/grpc_php_base:1.0.0 AS client
COPY hello-grpc-php /hello-grpc
WORKDIR /hello-grpc
RUN composer install
COPY tls/client_certs /var/hello_grpc/client_certs
CMD ["sh","client_start.sh"]
