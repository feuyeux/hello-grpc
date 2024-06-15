#!/bin/bash
set -e

cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

prepare() {
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
    export JAVA_HOME=D:/zoo/jdk-21.0.3
  elif
    [ "$(expr substr "${os_name}" 1 10)" = "MINGW64_NT" ]
  then
    export JAVA_HOME=D:/zoo/jdk-21.0.3
  else
    echo "Oops"
  fi

  echo "JAVA_HOME=${JAVA_HOME}"
  mvn -v
  echo
}

build_server() {
  echo "~~~ build grpc server java ~~~"
  cd ../hello-grpc-java
  mvn clean install -DskipTests -f server_pom.xml
  cp target/hello-grpc-java-server.jar ../docker/

  cd ../docker
  docker build -f grpc-server-java.dockerfile -t feuyeux/grpc_server_java:1.0.0 --pull .
  rm -rf hello-grpc-java-server.jar
  echo
}

build_client() {
  echo "~~~ build grpc client java ~~~"
  cd ../hello-grpc-java
  mvn clean install -DskipTests -f client_pom.xml
  cp target/hello-grpc-java-client.jar ../docker/

  cd ../docker
  docker build -f grpc-client-java.dockerfile -t feuyeux/grpc_client_java:1.0.0 --pull .
  rm -rf hello-grpc-java-client.jar
  echo
}

prepare
echo "arg=$1"

if [ "$1" == "server" ]; then
  build_server
elif [ "$1" == "client" ]; then
  build_client
else
  build_server

  build_client
fi
