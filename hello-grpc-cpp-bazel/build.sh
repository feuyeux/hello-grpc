#!/bin/bash
cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit

bazel version

unameOut=$(uname -a)
case "${unameOut}" in
*Microsoft*) OS="WSL" ;;  #must be first since Windows subsystem for linux will have Linux in the name too
*microsoft*) OS="WSL2" ;; #WARNING: My v2 uses ubuntu 20.4 at the moment slightly different name may not always work
Linux*) OS="Linux" ;;
Darwin*) OS="Mac" ;;
CYGWIN*) OS="Cygwin" ;;
MINGW*) OS="Windows" ;;
*Msys) OS="Windows" ;;
*) OS="UNKNOWN:${unameOut}" ;;
esac

if [ "${OS}" == "Windows" ]; then
    # TODO
    export http_proxy=127.0.0.1:56383
    export https_proxy=127.0.0.1:56383
else
    proxy_port=$(lsof -i -P -n | grep lantern | grep LISTEN | sed -n 2p | awk '{print $9}' | awk -F: '{print $NF}')
    if [ "$proxy_port" ]; then
        # TODO
        proxy_port=59503
        export http_proxy=127.0.0.1:$proxy_port
        export https_proxy=127.0.0.1:$proxy_port
    else
        unset http_proxy
        unset https_proxy
    fi
fi
echo "http_proxy: $http_proxy, https_proxy: $https_proxy"

bazel build :hello_server --sandbox_debug
