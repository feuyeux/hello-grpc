#!/bin/bash
cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit

find . -type f -name "*.sh" -print0 | xargs -0 dos2unix