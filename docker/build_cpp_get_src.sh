#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

# get latest version
# https://github.com/grpc/grpc/releases/latest
export GRPC_VERSION=${1:-v1.62.0}
export GRPC_SOURCE=${2:-/tmp/grpc}
export GLOG_SOURCE=${3:-/tmp/glog}
export GFLAGS_SOURCE=${4:-/tmp/gflags}
export CATCH2_SOURCE=${5:-/tmp/Catch2}

echo "GRPC_VERSION: $GRPC_VERSION, GRPC_SOURCE: $GRPC_SOURCE, GLOG_SOURCE: $GLOG_SOURCE, GFLAGS_SOURCE: $GFLAGS_SOURCE, CATCH2_SOURCE: $CATCH2_SOURCE"

# get source code
if [ -d "$GRPC_SOURCE" ]; then
  echo "grpc source code exists"
else
  git clone -b $GRPC_VERSION https://gitee.com/feuyeux/grpc "${GRPC_SOURCE}"
  cd "${GRPC_SOURCE}"
  export port=56383
  export http_proxy=127.0.0.1:$port
  export https_proxy=127.0.0.1:$port
  # cmake only
  git submodule update --init
fi

if [ -d "$GLOG_SOURCE" ]; then
  echo "glog source code exists"
else
  git clone https://gitee.com/feuyeux/glog "${GLOG_SOURCE}"
fi

if [ -d "$GFLAGS_SOURCE" ]; then
  echo "gflags source code exists"
else
  git clone https://gitee.com/feuyeux/gflags "${GFLAGS_SOURCE}"
fi

if [ ! -d "$CATCH2_SOURCE" ]; then
    git clone https://gitee.com/feuyeux/Catch2 "${CATCH2_SOURCE}"
fi
