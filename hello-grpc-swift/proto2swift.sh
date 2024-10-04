#!/bin/bash
cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit

cd Sources/Common || exit

protoc landing.proto \
    --proto_path=. \
    --swift_opt=Visibility=Public \
    --swift_out=. \
    --grpc-swift_opt=Visibility=Public \
    --grpc-swift_out=.
