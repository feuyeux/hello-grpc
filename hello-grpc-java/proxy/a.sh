#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

cd ..
export GRPC_SERVER_PORT=8887
export GRPC_HELLO_BACKEND=localhost
export GRPC_HELLO_BACKEND_PORT=9997
export JAVA_HOME=/usr/local/opt/openjdk/libexec/openjdk.jdk/Contents/Home
mvn exec:java -Dexec.mainClass="org.feuyeux.grpc.server.ProtoServer"