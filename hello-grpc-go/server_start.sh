#!/bin/bash
# shellcheck disable=SC2046
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
export GO111MODULE="on"

if [ "$(uname)" == "Darwin" ] || [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
    # Do something under Mac OS X or Linux platform
    export GOPATH=$GOPATH:${PWD}
elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ] || [ "$(expr substr $(uname -s) 1 10)" == "MINGW64_NT" ]; then
    # Do something under Windows NT platform
    export GOPATH=$GOPATH;$PWD
fi

go run server/proto_server.go