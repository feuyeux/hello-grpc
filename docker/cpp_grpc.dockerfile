# https://hub.docker.com/_/debian
FROM debian:12-slim AS build

RUN sed -i 's@deb.debian.org@mirrors.tuna.tsinghua.edu.cn@g' /etc/apt/sources.list.d/debian.sources

RUN apt-get update && apt-get install -y \
    autoconf \
    automake \
    build-essential \
    curl \
    g++ \
    git \
    libtool \
    make \
    cmake \
    pkg-config \
    unzip \
    wget \
    libprotobuf-dev  \
    protobuf-compiler  \
    libssl-dev \
    && apt-get clean

COPY bazel-7.0.2-installer-linux-x86_64.sh /source/bazel-installer.sh
COPY hello-grpc-cpp /source/hello-grpc-cpp
WORKDIR /source
RUN chmod +x bazel-installer.sh && ./bazel-installer.sh && export PATH="$PATH:$/source/bin"
WORKDIR /source/hello-grpc-cpp
RUN bazel build --jobs=8 //protos:hello_cc_grpc
RUN bazel build --jobs=8 //common:hello_utils
RUN bazel build --jobs=8 //common:hello_conn
RUN bazel build --jobs=8 //:hello_server //:hello_client

FROM debian:12-slim AS server
WORKDIR /opt/hello-grpc/
COPY --from=build /source/hello-grpc-cpp/bazel-bin/hello_server .
COPY tls/server_certs /var/hello_grpc/server_certs
COPY tls/client_certs /var/hello_grpc/client_certs
RUN /sbin/ldconfig -v
CMD ["./hello_server"]

FROM debian:12-slim AS client
WORKDIR /opt/hello-grpc/
COPY --from=build /source/hello-grpc-cpp/bazel-bin/hello_client .
COPY tls/client_certs /var/hello_grpc/client_certs
RUN /sbin/ldconfig -v
CMD ["./hello_client"]