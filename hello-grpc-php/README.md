# Hello gRPC php

## setup

```sh
# https://windows.php.net/download/

$ brew install php composer

$ php -version
```

```sh
# https://getcomposer.org/download/

$ composer --version
```

### grpc module

```sh
# PECL(The PHP Extension Community Library)
# PEAR(PHP Extension and Application Repository)
$ pecl install grpc

$ php --ini
Configuration File (php.ini) Path: /usr/local/etc/php/8.2
Loaded Configuration File:         /usr/local/etc/php/8.2/php.ini
Scan for additional .ini files in: /usr/local/etc/php/8.2/conf.d
Additional .ini files parsed:      /usr/local/etc/php/8.2/conf.d/ext-opcache.ini

$ code /usr/local/etc/php/8.2/php.ini

extension=grpc.so
```

### windows

- <https://pecl.php.net/package/gRPC>
- <https://pecl.php.net/package/protobuf>

```sh
extension=./php_grpc.dll
extension=./php_protobuf.dll
```

```sh
php --modules | grep grpc
```

## composer

<https://getcomposer.org/doc/00-intro.md>

### composer packagist

- <https://packagist.org/packages/grpc/grpc>
- <https://packagist.org/packages/google/protobuf>
- <https://packagist.org/packages/ramsey/uuid>
- <https://packagist.org/packages/apache/log4php>
- <https://packagist.org/packages/phpunit/phpunit>

[composer.json](composer.json)

### load dependencies

```sh
rm composer.lock
composer install
```

## build

### generate code

```sh
sh init.sh
```

```sh
php -d extension=grpc.so hello_server.php
php -d extension=grpc.so hello_client.php
```

```sh
php -d extension=php_grpc.dll hello_server.php
php -d extension=php_grpc.dll hello_client.php
```
