#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
export PYTHONPATH=$(pwd)
echo "PYTHONPATH=${PYTHONPATH}"
python client/protoClient.py