#!/bin/bash
# shellcheck disable=SC2155
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
export PYTHONPATH=$(pwd)
export PYTHONPATH=$PYTHONPATH:$(pwd)/landing_pb2
alias python=python3
python -V
echo "PYTHONPATH=${PYTHONPATH}"
echo "starting server..."
python server/protoServer.py
