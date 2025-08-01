#!/bin/bash
# Script to set up symbolic link from Flutter project's proto directory to central proto directory

cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit

echo "==== Setting up Flutter proto symbolic link ===="

# Create protos directory if it doesn't exist
mkdir -p protos

# Remove existing content if any
if [ -d "protos" ]; then
    rm -rf protos/*
fi

# Create symbolic link to central proto directory
ln -s ../proto/*.proto protos/

echo "Symbolic links created in protos/ pointing to ../proto/"
echo "DONE"
