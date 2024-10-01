#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
set -e

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

build_server() {
  echo "~~~ build grpc server java ~~~"
  cd ../hello-grpc-java
  mvn clean install -DskipTests -f server_pom.xml
  cp target/hello-grpc-java-server.jar ../docker/

  cd ../docker
  docker build -f java_grpc.dockerfile --target server -t feuyeux/grpc_server_java:1.0.0 .
  rm -rf hello-grpc-java-server.jar
  echo
}

build_client() {
  echo "~~~ build grpc client java ~~~"
  cd ../hello-grpc-java
  mvn clean install -DskipTests -f client_pom.xml
  cp target/hello-grpc-java-client.jar ../docker/

  cd ../docker
  docker build -f java_grpc.dockerfile --target client -t feuyeux/grpc_client_java:1.0.0 .
  rm -rf hello-grpc-java-client.jar
  echo
}

if [ "$2" == "server" ]; then
  build_server
elif [ "$2" == "client" ]; then
  build_client
else
  build_server
  build_client
fi
