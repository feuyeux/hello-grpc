FROM feuyeux/grpc_php_base:1.0.0
COPY hello-grpc-php /hello-grpc
WORKDIR /hello-grpc
RUN composer install
COPY tls/server_certs /var/hello_grpc/server_certs
ENTRYPOINT ["sh","server_start.sh"]
