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
COPY hello-grpc-cpp-bazel /source/hello-grpc-cpp-bazel
WORKDIR /source
RUN chmod +x bazel-installer.sh && ./bazel-installer.sh && export PATH="$PATH:$/source/bin"
RUN cd hello-grpc-cpp-bazel && bazel build //:hello_server //:hello_client

FROM debian:12-slim AS server
ENV PATH "/var/grpc/install/bin:$PATH"
COPY --from=build /var/grpc/install /var/grpc/install
WORKDIR /opt/hello-grpc/
COPY --from=build /source/glog/build/libglog.so.1 /usr/local/lib/
COPY --from=build /source/build/lib* .
COPY --from=build /source/hello-grpc-cpp-bazel/bazel-bin/hello_server .
COPY tls/server_certs /var/hello_grpc/server_certs
COPY tls/client_certs /var/hello_grpc/client_certs
RUN /sbin/ldconfig -v
CMD ["./proto_server"]

FROM debian:12-slim AS client
ENV PATH "/var/grpc/install/bin:$PATH"
COPY --from=build /source/glog/build/libglog.so.1 /usr/local/lib/
COPY --from=build /var/grpc/install /var/grpc/install
WORKDIR /opt/hello-grpc/
COPY --from=build /source/build/lib* .
COPY --from=build /source/hello-grpc-cpp-bazel/bazel-bin/hello_client .
COPY tls/client_certs /var/hello_grpc/client_certs
RUN /sbin/ldconfig -v
CMD ["./proto_client"]