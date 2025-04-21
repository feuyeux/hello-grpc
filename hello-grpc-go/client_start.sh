#!/bin/bash
# shellcheck disable=SC2046
cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit
export GO111MODULE="on"

export GRPC_SERVER

if [ "$(uname)" == "Darwin" ]; then
    # Do something under Mac OS X platform
    export GOPATH=$GOPATH:${PWD}
    GRPC_SERVER=$(ifconfig en0 | grep inet | awk '$1=="inet" {print $2}')
elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
    # Do something under Linux platform
    export GOPATH=$GOPATH:${PWD}
    GRPC_SERVER=$(hostname -I | cut -d' ' -f1)
elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ] || [ "$(expr substr $(uname -s) 1 10)" == "MINGW64_NT" ]; then
    windows_path=$GOPATH
    linux_path=$(echo "$windows_path" | sed 's/^\([a-zA-Z]\):/\/\1/' | sed 's/\\/\//g')
    export GOPATH=$linux_path:${PWD}
    GRPC_SERVER=$(ipconfig | grep -A 3 'Ethernet adapter Ethernet' | grep 'IPv4 Address' | cut -d: -f2 | sed 's/ //g')
fi

go run client/proto_client.go
