#!/bin/bash
cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit
chmod +x ./*.sh
dos2unix ./*.sh
chmod +x ../*.sh
dos2unix ../*.sh
