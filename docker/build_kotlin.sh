#!/bin/bash
set -e

cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

export JAVA_HOME=${JAVA_17_HOME}
echo "JAVA_HOME=${JAVA_HOME}"

echo "~~~ build grpc server kotlin ~~~"
cd ../hello-grpc-kotlin
cd server
gradle clean installShadowDist >/dev/null 2>&1
cp build/install/server-shadow/bin/server ../../docker/server_start.sh
cp build/install/server-shadow/lib/proto-server-all.jar ../../docker/proto-server-all.jar

cd ../../docker
docker build -f grpc-server-kotlin.dockerfile -t feuyeux/grpc_server_kotlin:1.0.0 .
rm -rf server_start.sh
rm -rf proto-server-all.jar
echo

echo "~~~ build grpc client kotlin ~~~"
cd ../hello-grpc-kotlin
cd client
gradle clean installShadowDist >/dev/null 2>&1
cp build/install/client-shadow/bin/client ../../docker/client_start.sh
cp build/install/client-shadow/lib/proto-client-all.jar ../../docker/proto-client-all.jar

cd ../../docker
docker build -f grpc-client-kotlin.dockerfile -t feuyeux/grpc_client_kotlin:1.0.0 .
rm -rf client_start.sh
rm -rf proto-client-all.jar
echo
