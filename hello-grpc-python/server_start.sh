#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
export PYTHONPATH=$(pwd)
export PYTHONPATH=$PYTHONPATH:$(pwd)/landing
echo "PYTHONPATH=${PYTHONPATH}"
python server/protoServer.py
