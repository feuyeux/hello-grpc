#!/bin/bash
cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit

cargo clean
cargo tree -d >tree.txt
