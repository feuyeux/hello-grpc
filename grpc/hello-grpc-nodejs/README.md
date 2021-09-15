## grpc nodejs demo
### 1 Setup
```bash
npm install -g grpc-tools
```

### 2 Generate
```bash
proto2js.sh
```

### 3 Build
```bash
npm install
```

### 4 Run
```bash
node proto_server.js
```

```bash
node proto_client.js
```

### Diagnose
```bash
# find
lsof -i tcp:9996
# kill
kill $(lsof -ti:9996)
```
### Reference
- https://github.com/grpc/grpc-node/tree/master/packages/grpc-js https://www.npmjs.com/package/@grpc/grpc-js
- https://github.com/grpc/grpc-node/tree/master/packages/proto-loader https://www.npmjs.com/package/@grpc/proto-loader
- https://github.com/caolan/async https://www.npmjs.com/package/async
- https://github.com/protocolbuffers/protobuf/tree/master/js https://www.npmjs.com/package/google-protobuf
- https://github.com/lodash/lodash https://www.npmjs.com/package/lodash
- https://github.com/substack/minimist https://www.npmjs.com/package/minimist
- https://github.com/winstonjs/winston https://www.npmjs.com/package/winston
- https://github.com/erikdubbelboer/node-sleep https://www.npmjs.com/package/sleep
- https://github.com/uuidjs/uuid https://www.npmjs.com/package/uuid