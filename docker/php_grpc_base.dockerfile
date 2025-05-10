# 优化的gRPC PHP插件基础镜像，采用最小化编译策略以提高构建速度
FROM composer:2.8
# https://hub.docker.com/_/composer
# https://hub.docker.com/_/php
# https://github.com/composer/docker
# docker run -it --rm composer php -i | grep "php.ini"

# 优化包安装，合并 RUN 命令减少镜像层数
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories && \
    apk add --no-cache --upgrade linux-headers gcc g++ protobuf protobuf-dev curl unzip cmake git autoconf

# 安装 protoc (使用预编译的二进制文件)
# 使用与composer.json中google/protobuf匹配的版本 (30.2)
RUN PROTOC_VERSION=30.2 && \
    ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then ARCH="x86_64"; else ARCH="aarch_64"; fi && \
    curl -OL https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-linux-${ARCH}.zip && \
    unzip protoc-${PROTOC_VERSION}-linux-${ARCH}.zip -d /usr/local && \
    chmod 755 /usr/local/bin/protoc && \
    rm protoc-${PROTOC_VERSION}-linux-${ARCH}.zip

# 安装 grpc_php_plugin (最小编译方式并优化构建过程)
RUN GRPC_VERSION=1.70.2 && \
    cd /tmp && \
    git clone -b v${GRPC_VERSION} --depth 1 --single-branch --shallow-submodules https://github.com/grpc/grpc.git && \
    cd grpc && \
    # 只更新必要的子模块
    git submodule update --init --depth 1 --recursive third_party/abseil-cpp third_party/cares/cares third_party/protobuf third_party/re2 && \
    mkdir -p cmake/build && \
    cd cmake/build && \
    # 设置最小化构建配置，只编译grpc_php_plugin所需的组件
    cmake ../.. \
        -DCMAKE_BUILD_TYPE=Release \
        -DgRPC_BUILD_TESTS=OFF \
        -DgRPC_BUILD_CSHARP_EXT=OFF \
        -DgRPC_BUILD_GRPC_CSHARP_PLUGIN=OFF \
        -DgRPC_BUILD_GRPC_NODE_PLUGIN=OFF \
        -DgRPC_BUILD_GRPC_OBJECTIVE_C_PLUGIN=OFF \
        -DgRPC_BUILD_GRPC_PYTHON_PLUGIN=OFF \
        -DgRPC_BUILD_GRPC_RUBY_PLUGIN=OFF \
        && \
    # 使用所有可用核心进行并行编译，提高构建速度
    make grpc_php_plugin -j$(nproc) && \
    # 复制编译好的二进制文件到最终位置
    cp ./grpc_php_plugin /usr/local/bin/ && \
    # 赋予执行权限
    chmod +x /usr/local/bin/grpc_php_plugin && \
    # 清理构建文件以减小镜像大小
    cd /tmp && \
    rm -rf /tmp/grpc
# 安装 PHP gRPC 扩展并配置
RUN pecl install grpc && \
    echo "extension=grpc.so" > /usr/local/etc/php/conf.d/grpc.ini && \
    # 验证安装
    composer --version && php -m | grep grpc
