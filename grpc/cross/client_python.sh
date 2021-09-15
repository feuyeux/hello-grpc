#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

cd ../hello-grpc-python
export PYTHONPATH=$(pwd)
python client/protoClient.py