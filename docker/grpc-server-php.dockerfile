# https://hub.docker.com/r/grpc/php
FROM grpc/php:0.11-onbuild
COPY tls/server_certs /var/hello_grpc/server_certs
COPY hello-grpc-php .
sh init.sh
composer install
ENTRYPOINT ["sh","server_start.sh"]
