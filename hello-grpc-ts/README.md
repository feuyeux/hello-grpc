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
# build & run
tsc hello_server.ts && ts-node hello_server.ts 
tsc hello_client.ts && ts-node hello_client.ts 
```