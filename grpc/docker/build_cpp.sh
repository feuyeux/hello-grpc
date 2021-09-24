# https://github.com/npclaudiu/grpc-cpp-docker.git
#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

echo "~~~ build grpc c++ ~~~"
cd ..
cp -r hello-grpc-cpp docker/
rm -rf docker/hello-grpc-cpp/build
cd docker
docker build -f grpc-cpp.dockerfile -t feuyeux/grpc_cpp:1.0.0 .
rm -rf hello-grpc-cpp
echo