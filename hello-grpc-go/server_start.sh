#!/bin/bash
# shellcheck disable=SC2046
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
export GO111MODULE="on"

if [ "$(uname)" == "Darwin" ] || [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
  export GOPATH=$GOPATH:${PWD}
  echo "[Mac OS X or Linux] GOPATH=$GOPATH"
elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ] || [ "$(expr substr $(uname -s) 1 10)" == "MINGW64_NT" ]; then
  windows_path=$GOPATH
  linux_path=$(echo "$windows_path" | sed 's/^\([a-zA-Z]\):/\/\1/' | sed 's/\\/\//g')
  export GOPATH=$linux_path:${PWD}
  echo "[Windows] GOPATH=$GOPATH"
fi

go run server/proto_server.go
