#!/bin/bash
langs=(cpp rust java go csharp python nodejs dart kotlin swift php ts)
for lang in "${langs[@]}"; do
    docker push "feuyeux/grpc_server_$lang:1.0.0"
    docker push "feuyeux/grpc_client_$lang:1.0.0"
done

# java
docker push feuyeux/grpc_with_api_server_java:1.0.0
docker push feuyeux/grpc_with_api_client_java:1.0.0
