#!/bin/bash
set -e

cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

export JAVA_HOME=$JAVA_17_HOME

echo "build grpc server java"
cd ../hello-grpc-java
rm -f src/main/proto/landing.proto
cd ..
ln -s "$PWD"/proto/landing2.proto hello-grpc-java/src/main/proto/landing.proto
cd hello-grpc-java

mvn clean install -DskipTests -f server_pom.xml
cp target/hello-grpc-java-server.jar ../docker/
cd ../docker
docker build -f grpc-server-java.dockerfile -t feuyeux/grpc_with_api_server_java:1.0.0 .
rm -rf hello-grpc-java-server.jar
echo

echo "build grpc client java"
cd ../hello-grpc-java
mvn clean install -DskipTests -f client_pom.xml
cp target/hello-grpc-java-client.jar ../docker/
cd ../docker
docker build -f grpc-client-java.dockerfile -t feuyeux/grpc_with_api_client_java:1.0.0 .
rm -rf hello-grpc-java-client.jar
echo

cd ../hello-grpc-java
rm -f src/main/proto/landing.proto
cd ..
ln -s "$PWD"/proto/landing.proto hello-grpc-java/src/main/proto/landing.proto

docker images | grep grpc_with_api
