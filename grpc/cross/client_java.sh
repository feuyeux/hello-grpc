#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

cd ../hello-grpc-java
mvn exec:java -Dexec.mainClass="org.feuyeux.grpc.client.ProtoClient"