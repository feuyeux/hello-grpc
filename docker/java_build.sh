#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
set -e

build_server() {
  echo "~~~ build grpc server java ~~~"
  cd ../hello-grpc-java
  mvn clean install -DskipTests -f server_pom.xml
  cp target/hello-grpc-java-server.jar ../docker/

  cd ../docker
  docker build -f java_grpc.dockerfile --target server -t feuyeux/grpc_server_java:1.0.0 --pull .
  rm -rf hello-grpc-java-server.jar
  echo
}

build_client() {
  echo "~~~ build grpc client java ~~~"
  cd ../hello-grpc-java
  mvn clean install -DskipTests -f client_pom.xml
  cp target/hello-grpc-java-client.jar ../docker/

  cd ../docker
  docker build -f java_grpc.dockerfile --target client -t feuyeux/grpc_client_java:1.0.0 --pull .
  rm -rf hello-grpc-java-client.jar
  echo
}

if [ "$1" == "server" ]; then
  build_server
elif [ "$1" == "client" ]; then
  build_client
else
  build_server
  build_client
fi
