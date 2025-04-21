#!/bin/bash
cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit

if [ "$1" == "create" ]; then
    # conda search python
    conda create -n grpc_env python=3.12 -y
elif [ "$1" == "delete" ]; then
    conda env remove -n grpc_env -y
    conda env list
else
    conda activate grpc_env
    echo "upgrade pip"
    python -m pip install --upgrade pip
    echo "install dependencies"
    pip install -r requirements.txt
fi

# quit
# conda deactivate
