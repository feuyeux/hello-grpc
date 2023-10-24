#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

alias python=python3
python -V

export PYTHONPATH=$(pwd)
export PYTHONPATH=$PYTHONPATH:$(pwd)/landing
echo "PYTHONPATH=${PYTHONPATH}"
python3 client/protoClient.py
