#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
git submodule update --remote
cd grpc
# 
cd hello-grpc-csharp
git checkout main
git pull
# 
cd ../hello-grpc-java
git checkout main
git pull
# 
cd ../hello-grpc-nodejs
git checkout main
git pull
# 
cd ../hello-grpc-rust
git checkout main
git pull
# 
cd ../hello-grpc-cpp
git checkout main
git pull
# 
cd ../hello-grpc-go
git checkout main
git pull
# 
cd ../hello-grpc-kotlin
git checkout main
git pull
# 
cd ../hello-grpc-python
git checkout main
git pull
