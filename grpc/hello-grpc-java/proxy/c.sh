#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

cd ..
export GRPC_SERVER=localhost
export GRPC_SERVER_PORT=8887
export JAVA_HOME=${JAVA_17_HOME}
mvn exec:java -Dexec.mainClass="org.feuyeux.grpc.client.ProtoClient"