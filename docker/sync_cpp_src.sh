#!/bin/bash
cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit

# https://github.com/npclaudiu/grpc-cpp-docker.git
export GRPC_SOURCE=https://gitee.com/feuyeux/cgrpc
export C_ARES_SOURCE=https://gitee.com/feuyeux/c-ares
export GLOG_SOURCE=https://gitee.com/feuyeux/glog
export GFLAGS_SOURCE=https://gitee.com/feuyeux/gflags
export BORINGSSL_SOURCE=https://gitee.com/feuyeux/boringssl
export GRPC_RELEASE_TAG=v1.62.0
export GRPC_SRC_PATH=grpc_src

if [ -d "$GRPC_SRC_PATH" ]; then
    echo "----update grpc----"
    cd $GRPC_SRC_PATH
    if [ -d "third_party/c-cares" ]; then
        echo "----update c-cares----"
        cd third_party/c-cares
        git pull
        cd ../..
    else
        git clone ${C_ARES_SOURCE} third_party/c-cares
    fi
    if [ -d "third_party/glog" ]; then
        echo "----update glog----"
        cd third_party/glog
        git pull
        cd ../..
    else
        git clone ${GLOG_SOURCE} third_party/glog
    fi
    if [ -d "third_party/gflags" ]; then
        echo "----update gflags----"
        cd third_party/gflags
        git pull
        cd ../..
    else
        git clone ${GFLAGS_SOURCE} third_party/gflags
    fi
    if [ -d "third_party/boringssl-with-bazel" ]; then
        echo "----update boringssl----"
        cd third_party/boringssl-with-bazel
        # git pull
        cd ../..
    else
        git clone ${BORINGSSL_SOURCE} third_party/boringssl-with-bazel
    fi
    git submodule update --init
else
    echo "----clone grpc----"
    mkdir -p $GRPC_SRC_PATH
    git clone -b ${GRPC_RELEASE_TAG} ${GRPC_SOURCE} ${GRPC_SRC_PATH}
    cd ${GRPC_SRC_PATH}
    git clone ${C_ARES_SOURCE} third_party/cares
    git clone ${GLOG_SOURCE} third_party/glog
    git clone ${GFLAGS_SOURCE} third_party/gflags
    git submodule update --init
fi
