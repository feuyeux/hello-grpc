FROM composer:2.8
# https://hub.docker.com/_/composer
# https://hub.docker.com/_/php
# https://github.com/composer/docker
# docker run -it --rm composer php -i | grep "php.ini"
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories
RUN apk add --upgrade linux-headers gcc make g++ zlib-dev autoconf
# https://pecl.php.net/package/gRPC
RUN pecl install grpc