FROM node:16-alpine
RUN apk add --update \
      python3 \
      make \
      g++ \
  && rm -rf /var/cache/apk/*
RUN npm config set registry https://registry.npm.taobao.org && npm install -g node-pre-gyp grpc-tools --unsafe-perm
COPY tls/client_certs /var/hello_grpc/client_certs
COPY node/package.json .
RUN npm install --unsafe-perm
COPY node .
RUN npm install --unsafe-perm
CMD ["node","proto_client.js"]