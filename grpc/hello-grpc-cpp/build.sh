#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
set -e

echo "cmake:"
if [ ! -d "build" ]; then
  mkdir build
else
  rm -rf build
  mkdir build
fi
pushd build
cmake -DCMAKE_BUILD_TYPE=Release ..
echo

echo "make:"
make -j$(nproc)
popd
echo "DONE."
