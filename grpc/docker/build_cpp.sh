# https://github.com/npclaudiu/grpc-cpp-docker.git
#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

echo "~~~ build grpc c++ ~~~"
cd ..
rm -rf docker/hello-grpc-cpp
cp -r hello-grpc-cpp docker/
rm -rf docker/hello-grpc-cpp/build
cd docker
docker build -f grpc-cpp.dockerfile --target build -t feuyeux/grpc_cpp:1.0.0 .
docker build -f grpc-cpp.dockerfile --target server -t feuyeux/grpc_server_cpp:1.0.0 .
docker build -f grpc-cpp.dockerfile --target client -t feuyeux/grpc_client_cpp:1.0.0 .

rm -rf hello-grpc-cpp
echo

# [+] Building 839.6s (19/19) FINISHED
#  => [internal] load build definition from grpc-cpp.dockerfile                                                                                                            0.0s
#  => => transferring dockerfile: 3.48kB                                                                                                                                   0.0s
#  => [internal] load .dockerignore                                                                                                                                        0.0s
#  => => transferring context: 2B                                                                                                                                          0.0s
#  => [internal] load metadata for docker.io/library/debian:bullseye-slim                                                                                                  2.5s
#  => [auth] library/debian:pull token for registry-1.docker.io                                                                                                            0.0s
#  => [internal] load build context                                                                                                                                        1.4s
#  => => transferring context: 95.24MB                                                                                                                                     1.3s
#  => [build  1/13] FROM docker.io/library/debian:bullseye-slim@sha256:a23887a2e830b815955e010f30d4c2430cd5ef82e93c130471024bc9f808d5d3                                    0.0s
#  => CACHED [build  2/13] RUN apt-get update && apt-get install -y     autoconf     automake     build-essential     cmake     curl     g++     git     libtool     make  0.0s
#  => [build  3/13] RUN echo "clone grpc" && git clone -b v1.42.0 https://gitee.com/feuyeux/grpc /var/grpc/src                                                           113.0s
#  => [build  4/13] RUN echo "clone grpc submodules" && cd /var/grpc/src && git submodule update --init                                                                  250.9s
#  => [build  5/13] COPY cmake-3.19.6-Linux-x86_64.sh cmake-linux.sh                                                                                                       0.1s
#  => [build  6/13] RUN echo "build cmake" && mkdir -p /var/grpc/install && sh cmake-linux.sh -- --skip-license --prefix=/var/grpc/install  &&     rm cmake-linux.sh       1.7s
#  => [build  7/13] RUN echo "build c-ares" && git clone https://gitee.com/feuyeux/c-ares &&     cd c-ares && ./buildconf && autoconf configure.ac &&     ./configure --  59.0s
#  => [build  8/13] RUN echo "build grpc" && cd /var/grpc/src &&     mkdir -p cmake/build &&     cd cmake/build &&     cmake -DgRPC_INSTALL=ON     -DgRPC_BUILD_TESTS=O  340.9s
#  => [build  9/13] RUN echo "build abseil" && cd /var/grpc/src/third_party/ &&     mkdir -p abseil-cpp/cmake/build &&     cd abseil-cpp/cmake/build &&     cmake -DCMAK  20.6s
#  => [build 10/13] WORKDIR /source                                                                                                                                        0.1s
#  => [build 11/13] RUN echo "build dependencies" && git clone https://gitee.com/feuyeux/glog &&     mkdir -p glog/cmake/build &&     cd glog/cmake/build &&     cmake .  21.2s
#  => [build 12/13] COPY hello-grpc-cpp .                                                                                                                                  0.3s
#  => [build 13/13] RUN echo "build hello-grpc-cpp" && cd /source && echo "cmake:" && mkdir build && cd build &&     cmake -DCMAKE_BUILD_TYPE=Release     -DCMAKE_INSTAL  16.4s

# docker run --rm -it --entrypoint=bash feuyeux/grpc_server_cpp:1.0.0