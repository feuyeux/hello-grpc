# https://hub.docker.com/r/grpc/php
FROM grpc/php:0.11-onbuild
COPY tls/client_certs /var/hello_grpc/client_certs
COPY hello-grpc-php .
sh init.sh
composer install
ENTRYPOINT ["sh","client_start.sh"]
