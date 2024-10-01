#!/bin/bash
set -e

cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

docker images | grep openjdk

#
if [ "$(uname)" == "Darwin" ]; then
  echo "macOS detected"
elif [ "$(expr substr "$(uname -s)" 1 5)" == "Linux" ]; then
  echo "Linux detected"
else
  export JAVA_HOME_8=/d/zoo/java-se-8u44/
  export JAVA_HOME_11=/d/zoo/jdk-11.0.23/
  export JAVA_HOME_21=/d/zoo/jdk-21.0.3/
  export JAVA_HOME_23=/d/zoo/jdk-23/
fi
# if the first input parameter is empty, use JAVA_HOME_21, otherwise use it.
if [ -z "$1" ]; then
  export JAVA_HOME=$JAVA_HOME_21
else
  export JAVA_HOME="JAVA_HOME_$1"
fi
echo "JAVA_HOME=$JAVA_HOME"
gradle --version
#
echo "~~~ build grpc server kotlin ~~~"
cd ../hello-grpc-kotlin
cd server
# gradle clean installShadowDist >/dev/null 2>&1
gradle clean installShadowDist
cp build/install/server-shadow/bin/server ../../docker/server_start.sh
cp build/install/server-shadow/lib/proto-server-all.jar ../../docker/proto-server-all.jar
echo "build server image"
cd ../../docker
docker build -f kotlin_grpc.dockerfile --target server -t feuyeux/grpc_server_kotlin:1.0.0 .
rm -rf server_start.sh
rm -rf proto-server-all.jar
echo

echo "~~~ build grpc client kotlin ~~~"
cd ../hello-grpc-kotlin
cd client
gradle clean installShadowDist >/dev/null 2>&1
cp build/install/client-shadow/bin/client ../../docker/client_start.sh
cp build/install/client-shadow/lib/proto-client-all.jar ../../docker/proto-client-all.jar
echo "build client image"
cd ../../docker
docker build -f kotlin_grpc.dockerfile --target client -t feuyeux/grpc_client_kotlin:1.0.0 .
rm -rf client_start.sh
rm -rf proto-client-all.jar
echo
