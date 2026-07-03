FROM node:24-alpine AS build-base
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories
RUN apk add --update \
  python3 \
  make \
  g++ \
  git \
  && rm -rf /var/cache/apk/*
RUN npm config set registry https://registry.npmmirror.com && npm install -g node-pre-gyp grpc-tools --unsafe-perm
WORKDIR /app/hello-grpc
COPY hello-grpc-nodejs /app/hello-grpc/hello-grpc-nodejs
COPY proto /app/hello-grpc/proto
# Build Node.js project
WORKDIR /app/hello-grpc/hello-grpc-nodejs
RUN npm install --unsafe-perm
# No build script in package.json, removed: RUN npm run build

FROM node:24-alpine AS server
WORKDIR /app
COPY --from=build-base /app/hello-grpc/hello-grpc-nodejs/package*.json /app/
COPY --from=build-base /app/hello-grpc/hello-grpc-nodejs/node_modules /app/node_modules
COPY --from=build-base /app/hello-grpc/hello-grpc-nodejs/src /app/src
# Create certificate directories
RUN mkdir -p /var/hello_grpc/server_certs /var/hello_grpc/client_certs
COPY docker/tls/server_certs/ /var/hello_grpc/server_certs/
COPY docker/tls/client_certs/ /var/hello_grpc/client_certs/
ENTRYPOINT ["node", "src/server/index.js"]

FROM node:24-alpine AS client
WORKDIR /app
COPY --from=build-base /app/hello-grpc/hello-grpc-nodejs/package*.json /app/
COPY --from=build-base /app/hello-grpc/hello-grpc-nodejs/node_modules /app/node_modules
COPY --from=build-base /app/hello-grpc/hello-grpc-nodejs/src /app/src
# Create certificate directory
RUN mkdir -p /var/hello_grpc/client_certs
COPY docker/tls/client_certs/ /var/hello_grpc/client_certs/
ENTRYPOINT ["node", "src/client/index.js"]