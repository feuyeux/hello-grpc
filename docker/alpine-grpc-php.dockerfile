FROM composer
# https://hub.docker.com/_/composer
# https://github.com/composer/docker
# docker run -it --rm composer php -i | grep "php.ini"
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories
RUN apk add --upgrade linux-headers gcc make g++ zlib-dev autoconf
RUN pecl install grpc