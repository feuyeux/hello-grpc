#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
git submodule update --remote
cd grpc
# 
cd hello-grpc-csharp
git co main
git pull
# 
cd ../hello-grpc-java
git co main
git pull
# 
cd ../hello-grpc-nodejs
git co main
git pull
# 
cd ../hello-grpc-rust
git co main
git pull
# 
cd ../hello-grpc-cpp
git co main
git pull
# 
cd ../hello-grpc-go
git co main
git pull
# 
cd ../hello-grpc-kotlin
git co main
git pull
# 
cd ../hello-grpc-python
git co main
git pull
