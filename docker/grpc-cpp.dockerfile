FROM debian:11-slim AS build

RUN apt-get update && apt-get install -y \
    autoconf \
    automake \
    build-essential \
    cmake \
    curl \
    g++ \
    git \
    libtool \
    make \
    pkg-config \
    unzip \
    wget \
    libprotobuf-dev  \
    protobuf-compiler  \
    libssl-dev \
    && apt-get clean
# 
ENV GRPC_SOURCE https://gitee.com/feuyeux/grpc
ENV C_ARES_SOURCE https://gitee.com/feuyeux/c-ares
ENV GLOG_SOURCE https://gitee.com/feuyeux/glog
ENV GFLAGS_SOURCE https://gitee.com/feuyeux/gflags
ENV GRPC_RELEASE_TAG v1.62.0
# 
ENV HELLO_BUILD_PATH /source/build
ENV GRPC_SRC_PATH /var/grpc/src
ENV GRPC_INSTALL_PATH /var/grpc/install
ENV PATH "$GRPC_INSTALL_PATH/bin:$PATH"

# clone grpc src
RUN echo "clone grpc" && git clone -b ${GRPC_RELEASE_TAG} ${GRPC_SOURCE} ${GRPC_SRC_PATH}
# RUN cd $GRPC_SRC_PATH && git submodule update --init --recursive
RUN echo "clone grpc submodules" && cd ${GRPC_SRC_PATH} && git submodule update --init

# build cmake to GRPC_INSTALL_PATH
# https://github.com/Kitware/CMake/releases/download/v3.19.6/cmake-3.19.6-Linux-x86_64.sh
COPY cmake-3.19.6-Linux-x86_64.sh cmake-linux.sh
RUN echo "build cmake" && mkdir -p ${GRPC_INSTALL_PATH} && \
    sh cmake-linux.sh -- --skip-license --prefix=${GRPC_INSTALL_PATH}  && \
    rm cmake-linux.sh

# build c-ares to GRPC_INSTALL_PATH
RUN echo "build c-ares" && git clone ${C_ARES_SOURCE} && \
    cd c-ares && ./buildconf && autoconf configure.ac && \
    ./configure --prefix=${GRPC_INSTALL_PATH} && make -j$(nproc) && make install

# build grpc to GRPC_INSTALL_PATH
RUN echo "build grpc" && cd ${GRPC_SRC_PATH} && \
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

# build abseil to GRPC_INSTALL_PATH
RUN echo "build abseil" && cd ${GRPC_SRC_PATH}/third_party/ && \
    mkdir -p abseil-cpp/cmake/build && \
    cd abseil-cpp/cmake/build && \
    cmake -DCMAKE_INSTALL_PREFIX=${GRPC_INSTALL_PATH} \
    -DCMAKE_POSITION_INDEPENDENT_CODE=TRUE \
    ../.. && \
    make -j$(nproc) && \
    make install

WORKDIR /source
# clone dependencies
RUN echo "clone gflags" && git clone ${GFLAGS_SOURCE}
RUN echo "clone glog" && git clone ${GLOG_SOURCE}
# build dependencies

RUN echo "build glog" && cd /source && mkdir -p glog/cmake/build && cd glog && git checkout v0.6.0 && \
    cmake -S . -B build -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX=${GRPC_INSTALL_PATH} && \
    cmake --build build --target install

RUN echo "build gflags" && cd /source && mkdir -p gflags/cmake/build && cd gflags && \
    cmake -S . -B build -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX=${GRPC_INSTALL_PATH} && \
    cmake --build build --target install

# build hello-grpc-cpp
COPY hello-grpc-cpp .
RUN echo "build hello-grpc-cpp" && cd /source && echo "cmake:" && mkdir build && cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=${GRPC_INSTALL_PATH} \
    .. && \
    echo "make:" && make -j$(nproc)
#docker run --rm -it feuyeux/grpc_cpp:1.0.0 bash

FROM debian:11-slim AS server
ENV PATH "/var/grpc/install/bin:$PATH"
COPY --from=build /var/grpc/install /var/grpc/install 
WORKDIR /opt/hello-grpc/
COPY --from=build /source/glog/build/libglog.so.1 /usr/local/lib/
COPY --from=build /source/build/lib* .
COPY --from=build /source/build/proto_server .
COPY tls/server_certs /var/hello_grpc/server_certs
COPY tls/client_certs /var/hello_grpc/client_certs
RUN /sbin/ldconfig -v
CMD ["./proto_server"]

FROM debian:11-slim AS client
ENV PATH "/var/grpc/install/bin:$PATH"
COPY --from=build /source/glog/build/libglog.so.1 /usr/local/lib/
COPY --from=build /var/grpc/install /var/grpc/install 
WORKDIR /opt/hello-grpc/
COPY --from=build /source/build/lib* .
COPY --from=build /source/build/proto_client .
COPY tls/client_certs /var/hello_grpc/client_certs
RUN /sbin/ldconfig -v
CMD ["./proto_client"]
