#!/usr/bin/env sh
SCRIPT_PATH="$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/"
cd "$SCRIPT_PATH" || exit
export JAVA_HOME=${JAVA_19_HOME}
cd server
gradle clean installShadowDist
build/install/server-shadow/bin/server