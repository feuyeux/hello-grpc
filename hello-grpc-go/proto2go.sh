#!/bin/bash
# shellcheck disable=SC2155
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
export GOROOT=$(go env GOROOT)
export GOPATH=$(go env GOPATH)
echo "GOROOT=$GOROOT GOPATH=$GOPATH"
export PATH="$PATH:$GOPATH/bin"

PROTOC_VERSION=$(protoc --version)
if [ -z "$PROTOC_VERSION" ]; then
  echo "install protoc firstly, see doc/proto.md"
  exit 1
else
  echo "Protoc version: $PROTOC_VERSION"
fi

if [ ! -f "$GOPATH/bin/protoc-gen-go.exe" ]; then
  export GOPROXY=https://mirrors.aliyun.com/goproxy/
  go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
  go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
  go install -v golang.org/x/tools/gopls@latest
  echo "protoc-gen-go.exe has been installed successfully."
else
  echo "protoc-gen-go.exe is already installed."
fi

echo "generate the messages"
protoc --go_out=. ./proto/landing.proto
echo "generate the services"
protoc --go-grpc_out="$(pwd)" ./proto/landing.proto
