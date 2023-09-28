# Hello gRPC php

## setup

```sh

$ brew install php composer

$ php -version                                                                                                              

PHP 8.2.10 (cli) (built: Aug 31 2023 19:16:09) (NTS)
Copyright (c) The PHP Group
Zend Engine v4.2.10, Copyright (c) Zend Technologies
    with Zend OPcache v8.2.10, Copyright (c), by Zend 
Technologies

# PECL(The PHP Extension Community Library)

$ composer --version
Composer version 2.6.3 2023-09-15 09:38:21
```

```sh
$ pecl install grpc

$ php --ini
Configuration File (php.ini) Path: /usr/local/etc/php/8.2
Loaded Configuration File:         /usr/local/etc/php/8.2/php.ini
Scan for additional .ini files in: /usr/local/etc/php/8.2/conf.d
Additional .ini files parsed:      /usr/local/etc/php/8.2/conf.d/ext-opcache.ini

$ code /usr/local/etc/php/8.2/php.ini

extension=grpc.so

$ php --modules | grep grpc
```

## composer

<https://getcomposer.org/doc/00-intro.md>

### packagist

- <https://packagist.org/packages/grpc/grpc>
- <https://packagist.org/packages/google/protobuf>

## build

### generate code

```sh
sh init.sh
```

### load dependencies

```sh
composer install
```

```sh
php -d extension=grpc.so hello_server.php

php -d extension=grpc.so hello_client.php
```