#!/bin/bash
cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit

# brew install swift-protobuf grpc-swift
# OR:
# cd grpc-swift (https://github.com/grpc/grpc-swift.git)
# swift build --product protoc-gen-grpc-swift
# cp grpc-swift/.build/debug/protoc-gen-grpc-swift .
# swift build --product protoc-gen-swift
# cp grpc-swift/.build/debug/protoc-gen-swift .
#PATH=$(pwd):$PATH
#export PATH
cd Common
## proto2swift ##
protoc landing.proto \
    --proto_path=. \
    --swift_opt=Visibility=Public \
    --swift_out=. \
    --grpc-swift_opt=Visibility=Public \
    --grpc-swift_out=.
