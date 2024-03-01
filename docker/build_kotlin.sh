#!/bin/bash
set -e

cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

os_name=""
os_name="$(uname -s)"
if [ "$(uname)" = "Darwin" ]; then
  export JAVA_HOME=/usr/local/opt/openjdk/libexec/openjdk.jdk/Contents/Home
elif
  [ "$(expr substr "${os_name}" 1 5)" = "Linux" ]
then
  echo "Linux"
elif
  [ "$(expr substr "${os_name}" 1 7)" = "MSYS_NT" ]
then
  export JAVA_HOME=D:/zoo/jdk-21
elif
  [ "$(expr substr "${os_name}" 1 10)" = "MINGW64_NT" ]
then
  export JAVA_HOME=D:/zoo/jdk-21
else
  echo "Oops"
fi

echo "JAVA_HOME=${JAVA_HOME}"
gradle --version

echo "~~~ build grpc server kotlin ~~~"
cd ../hello-grpc-kotlin
cd server
# gradle clean installShadowDist >/dev/null 2>&1
gradle clean installShadowDist
cp build/install/server-shadow/bin/server ../../docker/server_start.sh
cp build/install/server-shadow/lib/proto-server-all.jar ../../docker/proto-server-all.jar
echo "build server image"
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
echo "build client image"
cd ../../docker
docker build -f grpc-client-kotlin.dockerfile -t feuyeux/grpc_client_kotlin:1.0.0 .
rm -rf client_start.sh
rm -rf proto-client-all.jar
echo
