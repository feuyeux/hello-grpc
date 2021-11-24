#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

rm -rf landing && mkdir landing
py_proto_path=$(pwd)/landing

## https://developers.google.com/protocol-buffers/docs/reference/python-generated
## *_pb2.py which contains our generated request and response classes
## *_pb2_grpc.py which contains our generated client and server classes.
python -m grpc.tools.protoc \
  -I $(pwd)/proto \
  --python_out=${py_proto_path} \
  --grpc_python_out=${py_proto_path} \
  $(pwd)/proto/landing.proto
#touch $(pwd)/landing/__init__.py