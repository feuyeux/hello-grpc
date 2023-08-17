#!/bin/bash
cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit

#!/usr/bin/env bash
script_path=$(PWD)

echo "1 Checking protoc installation"
if ! [ -x "$(command -v protoc)" ]; then
    echo "you do not seem to have the protoc executable on your path"
    echo "we need protoc to generate a service defintion (*.pb file) that envoy can understand"
    echo "download the precompiled protoc executable and place it in somewhere in your systems PATH!"
    echo "goto: https://github.com/protocolbuffers/protobuf/releases/latest"
    echo "choose:"
    echo "       for linux:   protoc-3.14.0-linux-x86_64.zip"
    echo "       for windows: protoc-3.14.0-win64.zip"
    echo "       for mac:     protoc-3.14.0-osx-x86_64.zip"
    exit 1
else
    protoc --version
fi

echo "2 Generate Proto Descriptors"
sh gen_pb.sh

if ! [ $? -eq 0 ]; then
    echo "protobuf compilation failed"
    exit 1
fi

echo "3 Start envoy container on $(PWD)"
getenvoy run standard:1.16.2 -- --config-path ./envoy-config.yaml
