#!/bin/bash
echo "SERVER_NAME=$SERVER_NAME SERVER_IMG=$SERVER_IMG"
docker run --rm --name "$SERVER_NAME" -p 9996:9996 -e GRPC_HELLO_SECURE=Y "$SERVER_IMG"
