FROM debian:stretch as build

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
    && apt-get clean

ENV GRPC_RELEASE_TAG v1.40.0
ENV HELLO_BUILD_PATH /source/build
ENV GRPC_SRC_PATH /var/grpc/src
ENV GRPC_INSTALL_PATH /var/grpc/install
ENV PATH "$GRPC_INSTALL_PATH/bin:$PATH"

# download newest cmake
RUN  wget -q -O cmake-linux.sh https://github.com/Kitware/CMake/releases/download/v3.19.6/cmake-3.19.6-Linux-x86_64.sh && \
    sh cmake-linux.sh -- --skip-license --prefix=$GRPC_INSTALL_PATH  && \
    rm cmake-linux.sh

# download grpc src
RUN mkdir -p $GRPC_INSTALL_PATH
RUN git clone -b ${GRPC_RELEASE_TAG} https://gitee.com/feuyeux/grpc $GRPC_SRC_PATH && \
    cd $GRPC_SRC_PATH && \
    git submodule update --init --recursive

# build grpc to GRPC_INSTALL_PATH
RUN cd $GRPC_SRC_PATH && \
    mkdir -p cmake/build && \
    cd cmake/build && \
    cmake -DgRPC_INSTALL=ON \
    -DBUILD_SHARED_LIBS=ON \
    -DgRPC_BUILD_TESTS=OFF \
    -DgRPC_PROTOBUF_PROVIDER=package \ 
    -DgRPC_ZLIB_PROVIDER=package \
    -DgRPC_CARES_PROVIDER=package \
    -DgRPC_SSL_PROVIDER=package \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=$GRPC_INSTALL_PATH \
    ../.. && \
    make -j$(nproc) && \
    make install

# build abseil to GRPC_INSTALL_PATH
RUN cd $GRPC_SRC_PATH/third_party/ && \
    mkdir -p abseil-cpp/cmake/build && \
    cd abseil-cpp/cmake/build && \
    cmake -DCMAKE_INSTALL_PREFIX=$GRPC_INSTALL_PATH \
    -DCMAKE_POSITION_INDEPENDENT_CODE=TRUE \
    ../.. && \
    make -j$(nproc) && \
    make install

# build dependencies
WORKDIR /source
RUN echo "dependencies:" && git clone https://gitee.com/feuyeux/glog && \
    mkdir -p glog/cmake/build && \
    cd glog/cmake/build && \
    cmake ../.. && \
    cd ../.. && \
    cmake --build cmake/build

# build hello-grpc-cpp
COPY hello-grpc-cpp .
RUN cd /source && echo "cmake:" && mkdir build && cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=$GRPC_INSTALL_PATH \
    .. && \
    echo "make:" && make -j$(nproc) 

FROM debian:stretch as runtime
COPY --from=build /source/build/ /opt/hello-grpc/
WORKDIR /opt/hello-grpc/