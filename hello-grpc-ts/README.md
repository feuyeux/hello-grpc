# grpc typescript demo

```sh
npm install -g uuid
npm install -g ts-node
npm config list
code /Users/han/.npmrc
# npm config delete proxy
# npm config delete https-proxy
# npm config set  proxy http://127.0.0.1:50911
# npm config set  https-proxy http://127.0.0.1:50911

# init
export http_proxy=''
# export https_proxy='http://127.0.0.1:50911'
yarn install

# gen code
yarn add @grpc/grpc-js google-protobuf 
yarn add -D grpc-tools grpc_tools_node_protoc_ts typescript

npx grpc_tools_node_protoc --grpc_out=grpc_js:common --js_out=import_style=commonjs,binary:common --ts_out=grpc_js:common -I protos --plugin=protoc-gen-ts=./node_modules/.bin/protoc-gen-ts C:\Users\han\coding\hello-grpc\hello-grpc-ts\protos\landing.proto

# build & run
tsc hello_server.ts && ts-node hello_server.ts 
tsc hello_client.ts && ts-node hello_client.ts 
```
