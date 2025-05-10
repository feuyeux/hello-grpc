#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

cd ..
# Set JAVA_HOME based on OS
case "$(uname -s)" in
Darwin)
    export JAVA_HOME="/Users/han/zoo/jdk-24.0.1.jdk/Contents/Home"
    ;;
Linux)
    echo "Linux"
    # TODO: Set Linux JAVA_HOME here
    ;;
MSYS_NT* | MINGW64_NT*)
    export JAVA_HOME="D:/zoo/jdk-24.0.1"
    ;;
*)
    echo "Unsupported OS: $(uname -s)"
    ;;
esac

export GRPC_SERVER_PORT=8887
export GRPC_HELLO_BACKEND=localhost
export GRPC_HELLO_BACKEND_PORT=9997
java -jar target/hello-grpc-java-server.jar
#mvn exec:java -Dexec.mainClass="org.feuyeux.grpc.server.ProtoServer"