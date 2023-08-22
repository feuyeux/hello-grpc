#!/bin/bash
set -e

echo " == build UT Catch2 == "
if [ ! -d "$HOME/github/Catch2" ]; then
    git clone https://gitee.com/feuyeux/Catch2
    cd "$HOME"/github/Catch2
else
    cd "$HOME"/github/Catch2
    git pull
fi
cmake -Bbuild -H. -DBUILD_TESTING=OFF
cmake --build build/ --target install