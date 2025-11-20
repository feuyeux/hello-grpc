#!/usr/bin/env bash
set -e
SCRIPT_PATH="$(
  cd "$(dirname "$0")" >/dev/null 2>&1 || exit
  pwd -P
)"
# Set JAVA_HOME based on OS
case "$(uname -s)" in
Darwin)
    export JAVA_HOME="/Library/Java/JavaVirtualMachines/openjdk-21.jdk/Contents/Home"
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
cd "$SCRIPT_PATH/.." || exit
mvn clean package -DskipTests -Pclient
#export GRPC_HELLO_SECURE=Y
#export GRPC_SERVER=$(ipconfig getifaddr en0)
export GRPC_SERVER=host.docker.internal
echo "GRPC_SERVER=$GRPC_SERVER"
java -jar target/hello-grpc-java-client.jar

