#!/bin/bash
if [[ "${1}" == "" ]]; then
    port=9996
else
    port=${1}
fi
echo "stop ${port} ..."
lsof -i tcp:"${port}" | grep LISTEN | awk '{ print $2 }' | xargs kill
