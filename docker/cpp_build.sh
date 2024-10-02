#!/bin/bash
cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit
# https://github.com/npclaudiu/grpc-cpp-docker.git

set -e
docker images | grep debian
cd ..
rm -rf docker/hello-grpc-cpp
cd hello-grpc-cpp
bazel clean
cd ..
cp -r hello-grpc-cpp docker/
cd docker
echo "1 build builder"
# --progress=plain
docker build -f cpp_grpc.dockerfile --target build -t feuyeux/grpc_cpp:1.0.0 .
# docker run --rm -it --entrypoint=bash feuyeux/grpc_cpp:1.0.0
echo "2 build server"
docker build -f cpp_grpc.dockerfile --target server -t feuyeux/grpc_server_cpp:1.0.0 .
echo "3 build client"
docker build -f cpp_grpc.dockerfile --target client -t feuyeux/grpc_client_cpp:1.0.0 .
rm -rf hello-grpc-cpp
echo "DONE"
# docker run --rm -it --entrypoint=bash feuyeux/grpc_server_cpp:1.0.0
