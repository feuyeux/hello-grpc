#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
docker stop "$(docker ps -a -q)" >/dev/null 2>&1
docker rm "$(docker ps -a -q)" >/dev/null 2>&1
docker rmi "$(docker images | grep none | awk "{print $3}")" >/dev/null 2>&1
bash kill_port.sh >/dev/null 2>&1
# docker images
