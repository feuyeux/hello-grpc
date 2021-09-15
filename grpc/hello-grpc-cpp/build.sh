#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
#
echo "1. dependencies:"
import_glog.sh
import_uuid.sh
echo "2. cmake:"
rm -rf build common/*.cc common/*.h
mkdir build
pushd build
cmake ..
echo
echo "3. make:"
make -j
popd