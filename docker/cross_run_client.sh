#!/bin/bash
cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit
set -e

langs=(
    cpp
    rust
    java
    go
    csharp
    python
    kotlin
)
for lang in "${langs[@]}"; do
    echo "~~~ run grpc $lang client ~~~"
    # pass the first argument to the script
    sh "${lang}_run_client.sh" "$1"
done

# TODO support TLS

langs=(
    swift
    php
    dart
    node
    ts
)

for lang in "${langs[@]}"; do
    echo "~~~ run grpc $lang client ~~~"
    # pass the first argument to the script
    sh "${lang}_run_client.sh" "$1"
done
