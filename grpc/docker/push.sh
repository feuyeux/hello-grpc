# https://cr.console.aliyun.com/cn-beijing/instances/credentials
# ACR_USER=$(head $HOME/shop_config/cr)
# docker login --username=$ACR_USER registry.cn-beijing.aliyuncs.com

# java
docker push feuyeux/grpc_server_java:1.0.0
docker push feuyeux/grpc_client_java:1.0.0
docker push feuyeux/grpc_with_api_server_java:1.0.0
docker push feuyeux/grpc_with_api_client_java:1.0.0
# go
docker push feuyeux/grpc_server_go:1.0.0
docker push feuyeux/grpc_client_go:1.0.0
# nodejs
docker push feuyeux/grpc_server_node:1.0.0
docker push feuyeux/grpc_client_node:1.0.0
# python
docker push feuyeux/grpc_server_python:1.0.0
docker push feuyeux/grpc_client_python:1.0.0
# rust
docker push feuyeux/grpc_server_rust:1.0.0
docker push feuyeux/grpc_client_rust:1.0.0