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

ENV GRPC_SRC_PATH=/source/grpc
ENV HELLO_BUILD_PATH=/source/build
ENV GRPC_INSTALL_PATH=/var/grpc/install
ENV PATH="$GRPC_INSTALL_PATH/bin:$PATH"

# To solve the issue: CMake 3.22 or higher is required
# https://cmake.org/download/
ENV CMAKE_LATEST_SH=cmake-3.29.0-rc2-linux-x86_64.sh
COPY $CMAKE_LATEST_SH cmake-linux.sh
RUN mkdir -p ${GRPC_INSTALL_PATH} && \
    sh cmake-linux.sh -- --skip-license --prefix=${GRPC_INSTALL_PATH}  && \
    rm cmake-linux.sh

COPY grpc $GRPC_SRC_PATH
COPY hello-grpc-cpp /source/hello-grpc-cpp

WORKDIR /source

# build grpc
RUN cd ${GRPC_SRC_PATH} && \
    mkdir -p cmake/build && \
    cd cmake/build && \
    cmake -DgRPC_INSTALL=ON \
    -DgRPC_BUILD_TESTS=OFF \
    -DgRPC_ZLIB_PROVIDER=package \
    -DgRPC_SSL_PROVIDER=package \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=${GRPC_INSTALL_PATH} \
    ../.. && \
    make -j$(nproc) && \
    make install

## build hello-grpc-cpp denpendencies ##

ENV GLOG_SRC_PATH=/source/glog
ENV GFLAGS_SRC_PATH=/source/gflags
ENV CACHE2_SRC_PATH=/source/Cache2

COPY glog $GLOG_SRC_PATH
COPY gflags $GFLAGS_SRC_PATH
COPY Catch2 $CACHE2_SRC_PATH

# build glog
RUN cd /source && mkdir -p glog/cmake/build && cd glog && \
    cmake -S . -B build -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX=${GRPC_INSTALL_PATH} && \
    cmake --build build --target install
# build gflags
RUN cd /source && mkdir -p gflags/cmake/build && cd gflags && \
    cmake -S . -B build -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX=${GRPC_INSTALL_PATH} && \
    cmake --build build --target install
# build Cache2
RUN cd $CACHE2_SRC_PATH && \
    cmake -Bbuild -H. -DBUILD_TESTING=OFF && \
    cmake --build build/ --target install

# build hello-grpc-cpp
RUN cd /source/hello-grpc-cpp && mkdir build && cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=${GRPC_INSTALL_PATH} \
    .. && \
    make -j$(nproc)

# check /source/hello-grpc-cpp/build
# docker run --rm -it feuyeux/grpc_cpp:1.0.0 bash

FROM debian:12-slim AS server
ENV PATH="/var/grpc/install/bin:$PATH"
COPY --from=build /var/grpc/install /var/grpc/install
WORKDIR /opt/hello-grpc/
COPY --from=build /source/glog/build/libglog.so.1 /usr/local/lib/
COPY --from=build /source/build/lib* .
COPY --from=build /source/build/proto_server .
COPY tls/server_certs /var/hello_grpc/server_certs
COPY tls/client_certs /var/hello_grpc/client_certs
RUN /sbin/ldconfig -v
CMD ["./proto_server"]

FROM debian:12-slim AS client
ENV PATH="/var/grpc/install/bin:$PATH"
COPY --from=build /source/glog/build/libglog.so.1 /usr/local/lib/
COPY --from=build /var/grpc/install /var/grpc/install
WORKDIR /opt/hello-grpc/
COPY --from=build /source/build/lib* .
COPY --from=build /source/build/proto_client .
COPY tls/client_certs /var/hello_grpc/client_certs
RUN /sbin/ldconfig -v
CMD ["./proto_client"]
