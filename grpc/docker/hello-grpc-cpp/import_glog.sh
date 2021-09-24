#!/bin/bash
if [[ $(uname) == 'Darwin' ]]; then
    cd ~/cooding/github
    cd glog
    git pull -r
else
    git clone https://gitee.com/feuyeux/glog
    cd glog
fi
rm -rf build
cmake -S . -B build -G "Unix Makefiles"
cmake --build build