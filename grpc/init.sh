#!/usr/bin/env bash

brew install protobuf
brew install protoc-gen-go
sh grpc/docker/tls/copy_certs.sh
