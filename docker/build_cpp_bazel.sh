#!/bin/bash
cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit
# https://github.com/npclaudiu/grpc-cpp-docker.git

set -e

cd ..
rm -rf docker/hello-grpc-cpp-bazel
cd hello-grpc-cpp-bazel
bazel clean
cd ..
cp -r hello-grpc-cpp-bazel docker/
cd docker
echo "1 build builder"
# --progress=plain
docker build -f grpc-cpp-bazel.dockerfile --target build -t feuyeux/grpc_cpp:1.0.0 .

# docker run --rm -it --entrypoint=bash feuyeux/grpc_cpp:1.0.0
# docker run --rm -it --entrypoint=/source/hello-grpc-cpp-bazel/bazel-bin/hello_server feuyeux/grpc_cpp:1.0.0
# docker run --rm -it --entrypoint=bash -e GRPC_SERVER=192.168.1.4 feuyeux/grpc_cpp:1.0.0
# /source/hello-grpc-cpp-bazel/bazel-bin/hello_client

echo "2 build server"
docker build -f grpc-cpp-bazel.dockerfile --target server -t feuyeux/grpc_server_cpp:1.0.0 .
echo "3 build client"
docker build -f grpc-cpp-bazel.dockerfile --target client -t feuyeux/grpc_client_cpp:1.0.0 .

rm -rf hello-grpc-cpp
echo "DONE"

# docker run --rm -it --entrypoint=bash feuyeux/grpc_server_cpp:1.0.0
