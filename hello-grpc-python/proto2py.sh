#!/bin/bash
# shellcheck disable=SC2139
# shellcheck disable=SC2155
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

export proto_file_name="landing"
export proto_gen_name=${proto_file_name}_pb2
rm -f conn/${proto_gen_name}*

# grpcio-tools
export tools_version=$(python -m grpc.tools.protoc --version | cut -d' ' -f2)
alias protoc=protoc"${tools_version}"
echo "protoc version:$(protoc --version | cut -d' ' -f2);tools version: ${tools_version}"
# generate python code to conn folder
export proto_gen_path="$(pwd)/${proto_gen_name}"
python -m grpc.tools.protoc \
  --proto_path="$(pwd)/proto" \
  --python_out=conn \
  --pyi_out=conn \
  --grpc_python_out=conn \
  "$(pwd)/proto/${proto_file_name}.proto"
sed -i "s/landing_pb2/conn.landing_pb2/g" conn/${proto_gen_name}_grpc.py
echo "DONE"
