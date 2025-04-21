#!/bin/bash
cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit

cd Sources/Common || exit

protoc landing.proto \
    --plugin="${protoc_generate_grpc_swift}" \
    --proto_path=. \
    --grpc-swift_opt=Visibility=Public \
    --grpc-swift_out=.

protoc landing.proto \
    --plugin=${protoc_gen_swift} \
    --proto_path=. \
    --swift_opt=Visibility=Public \
    --swift_out=.
