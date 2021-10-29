#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
#
echo "1. dependencies:"
#sh import_glog.sh
echo "2. cmake:"
rm -rf build common/*.cc common/*.h
mkdir build
pushd build
cmake -DCMAKE_BUILD_TYPE=Release ..
echo
echo "3. make:"
make -j$(nproc)
popd
echo "ls build dir:"
ls build