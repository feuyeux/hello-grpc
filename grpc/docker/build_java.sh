#!/bin/bash
set -e

cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

export JAVA_HOME=${JAVA_17_HOME}
echo "JAVA_HOME=${JAVA_HOME}"
mvn -v
echo

echo "~~~ build grpc server java ~~~"
cd ../hello-grpc-java
mvn clean install -DskipTests -f server_pom.xml
cp target/hello-grpc-java-server.jar ../docker/

cd ../docker
docker build -f grpc-server-java.dockerfile -t feuyeux/grpc_server_java:1.0.0 --pull .
rm -rf hello-grpc-java-server.jar
echo

echo "~~~ build grpc client java ~~~"
cd ../hello-grpc-java
mvn clean install -DskipTests -f client_pom.xml
cp target/hello-grpc-java-client.jar ../docker/

cd ../docker
docker build -f grpc-client-java.dockerfile -t feuyeux/grpc_client_java:1.0.0 --pull .
rm -rf hello-grpc-java-client.jar
echo
