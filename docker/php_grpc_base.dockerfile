# Multi-stage build for minimal gRPC PHP base image.
#
# Strategy: Build all tools in Alpine builder (musl-libc compatible), then 
# copy to slim Alpine runtime. Final image: ~100-120MB vs 1.96GB.
#
# Offline build support: pre-stage these files in docker/ before building:
#   composer.phar       — https://mirrors.aliyun.com/composer/composer.phar
#   grpc-1.82.0.tgz     — https://pecl.php.net/get/grpc
#   grpc-src.tar        — grpc v1.81.1 + submodules (abseil, re2, protobuf, c-ares)
#
# Build tools stage (Alpine for musl-libc compatibility)
FROM php:8.5-cli-alpine AS builder

COPY composer.phar /tmp/composer.phar
COPY grpc-1.82.0.tgz /tmp/grpc-1.82.0.tgz
COPY grpc-src.tar /tmp/grpc-src.tar

# Install build dependencies (Alpine packages)
RUN apk add --no-cache \
        build-base autoconf libtool pkgconfig \
        protobuf-dev cmake \
        zlib-dev linux-headers && \
    rm -rf /var/cache/apk/*

# Build grpc_php_plugin (only need this binary, ~8MB stripped)
RUN mkdir -p /tmp/grpc && tar xf /tmp/grpc-src.tar -C /tmp/grpc --strip-components=1 && \
    cd /tmp/grpc && mkdir -p cmake/build && cd cmake/build && \
    cmake ../.. \
        -DCMAKE_BUILD_TYPE=MinSizeRel \
        -DgRPC_BUILD_TESTS=OFF \
        -DgRPC_BUILD_CSHARP_EXT=OFF \
        -DgRPC_BUILD_GRPC_CSHARP_PLUGIN=OFF \
        -DgRPC_BUILD_GRPC_NODE_PLUGIN=OFF \
        -DgRPC_BUILD_GRPC_OBJECTIVE_C_PLUGIN=OFF \
        -DgRPC_BUILD_GRPC_PYTHON_PLUGIN=OFF \
        -DgRPC_BUILD_GRPC_RUBY_PLUGIN=OFF && \
    make grpc_php_plugin -j2 && \
    strip --strip-all ./grpc_php_plugin && \
    cp ./grpc_php_plugin /tmp/grpc_php_plugin

# Build grpc.so PHP extension (stripped, ~18MB)
RUN MAKEFLAGS="-j2" pecl install /tmp/grpc-1.82.0.tgz && \
    GRPC_SO=$(find /usr/local/lib/php/extensions -name grpc.so) && \
    strip --strip-debug "$GRPC_SO" && \
    cp "$GRPC_SO" /tmp/grpc.so

# Runtime stage: Alpine for minimal size (~80-100MB final)
FROM php:8.5-cli-alpine

# Install runtime dependencies + bash (needed for proto2x.sh in downstream builds)
RUN apk add --no-cache \
        bash \
        protobuf \
        libstdc++ \
        zlib \
        ca-certificates && \
    rm -rf /var/cache/apk/*

# Copy pre-built artifacts from builder
COPY --from=builder /tmp/composer.phar /usr/local/bin/composer
COPY --from=builder /tmp/grpc_php_plugin /usr/local/bin/grpc_php_plugin
COPY --from=builder /tmp/grpc.so /tmp/grpc.so

RUN chmod +x /usr/local/bin/composer /usr/local/bin/grpc_php_plugin && \
    EXT_DIR=$(php -r "echo ini_get('extension_dir');") && \
    mv /tmp/grpc.so "$EXT_DIR/grpc.so" && \
    echo "extension=grpc.so" > /usr/local/etc/php/conf.d/grpc.ini

# Verify installation
RUN composer --version && \
    php -m | grep -i grpc && \
    which protoc grpc_php_plugin

