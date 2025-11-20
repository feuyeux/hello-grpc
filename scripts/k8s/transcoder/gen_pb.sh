#!/bin/bash
cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit

cd ..
proto_path="$(PWD)/proto"
# https://github.com/googleapis/googleapis.git
proto_dep_path="$(PWD)/hello-grpc-java/target/protoc-dependencies/3495bb91958122dbbfb579bead6834ec"
cd ${script_path}

# Generate Proto Descriptors
# -IPATH, --proto_path=PATH
# Specify the directory in which to search for imports.
# May be specified multiple times; directories will be searched in order.
# If not given, the current working directory is used.
# If not found in any of the these directories, the --descriptor_set_in descriptors will be checked for required proto file.

# -oFILE, --descriptor_set_out=FILE
# Writes a FileDescriptorSet (a protocol buffer, defined in descriptor.proto) containing all of the input files to FILE.

# --include_imports
# When using --descriptor_set_out, also include all dependencies of the input files in the set, so that the set is self-contained.

# --include_source_info
# When using --descriptor_set_out, do not strip SourceCodeInfo from the FileDescriptorProto.
# This results in vastly larger descriptors that include information about the original location of each decl in the source file as well as surrounding comments.

echo "proto_path=$proto_path"
echo "proto_dep_path=$proto_dep_path"

protoc \
    --proto_path=${proto_path} \
    --proto_path=${proto_dep_path} \
    --include_imports \
    --include_source_info \
    --descriptor_set_out=landing.pb \
    "${proto_path}"/landing2.proto