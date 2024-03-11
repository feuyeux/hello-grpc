#!/bin/bash
cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit

# proxy_port
# export http_proxy=127.0.0.1:$proxy_port
# export https_proxy=127.0.0.1:$proxy_port
http_proxy=${http_proxy:-""}
https_proxy=${https_proxy:-""}
echo "http_proxy: $http_proxy, https_proxy: $https_proxy"
echo "CHECK BAZEL"
bazel version
sleep 5
echo "CHECK GCC"
gcc -v
sleep 5
bazel build --compiler=gcc-13 --sandbox_debug //:hello_server //:hello_client
