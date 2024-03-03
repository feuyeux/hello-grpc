#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
# https://github.com/npclaudiu/grpc-cpp-docker.git

set -e

export GRPC_VERSION=v1.62.0
export GRPC_SOURCE=$(PWD)/grpc
export GLOG_SOURCE=$(PWD)/glog
export GFLAGS_SOURCE=$(PWD)/gflags
export CATCH2_SOURCE=$(PWD)/Catch2

echo "~~~ get grpc c++ sourcecode ~~~"
sh build_cpp_get_src.sh $GRPC_VERSION $GRPC_SOURCE $GLOG_SOURCE $GFLAGS_SOURCE $CATCH2_SOURCE

cd ..
rm -rf docker/hello-grpc-cpp
cp -r hello-grpc-cpp docker/
rm -rf docker/hello-grpc-cpp/build

cd docker
echo "~~~ build grpc c++ PWD:$(PWD) ~~~"
export port=56383
export http_proxy=127.0.0.1:$port
export https_proxy=127.0.0.1:$port
echo "http_proxy: $http_proxy, https_proxy: $https_proxy"
echo "1 build builder"
docker build \
 --progress=plain \
 -f grpc-cpp.dockerfile --target build -t feuyeux/grpc_cpp:1.0.0 .
echo "2 build server"
docker build -f grpc-cpp.dockerfile --target server -t feuyeux/grpc_server_cpp:1.0.0 .
echo "3 build client"
docker build -f grpc-cpp.dockerfile --target client -t feuyeux/grpc_client_cpp:1.0.0 .

rm -rf hello-grpc-cpp
echo "DONE"

# docker run --rm -it --entrypoint=bash feuyeux/grpc_server_cpp:1.0.0
