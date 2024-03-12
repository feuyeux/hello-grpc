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
ncpu=$(sysctl hw.ncpu)
physicalcpu=$(sysctl hw.physicalcpu)
logicalcpu=$(sysctl hw.logicalcpu)
echo "hw.ncpu: $ncpu,hw.physicalcpu: $physicalcpu,hw.logicalcpu: $logicalcpu"
job_number=$ncpu+2
bazel build --compiler=gcc-13 --jobs="$job_number" --sandbox_debug //:hello_server //:hello_client
