FROM node:21-alpine AS server
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories
RUN apk add --update \
  python3 \
  make \
  g++ \
  && rm -rf /var/cache/apk/*
RUN npm config set registry https://registry.npmmirror.com && npm install -g node-pre-gyp grpc-tools --unsafe-perm
COPY tls/server_certs /var/hello_grpc/server_certs
COPY tls/client_certs /var/hello_grpc/client_certs
COPY hello-grpc-nodejs/package.json .
RUN npm install --unsafe-perm
COPY hello-grpc-nodejs .
ENTRYPOINT ["node","proto_server.js"]

FROM node:21-alpine AS client
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories
RUN apk add --update \
  python3 \
  make \
  g++ \
  && rm -rf /var/cache/apk/*
RUN npm config set registry https://registry.npmmirror.com && npm install -g node-pre-gyp grpc-tools --unsafe-perm
COPY tls/client_certs /var/hello_grpc/client_certs
COPY hello-grpc-nodejs/package.json .
RUN npm install --unsafe-perm
COPY hello-grpc-nodejs .
RUN npm install --unsafe-perm
CMD ["node","proto_client.js"]