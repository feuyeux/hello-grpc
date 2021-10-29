#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

cd ..
sh build.sh
export GRPC_SERVER_PORT=9997
export JAVA_HOME=${JAVA_17_HOME}
mvn exec:java -Dexec.mainClass="org.feuyeux.grpc.server.ProtoServer"