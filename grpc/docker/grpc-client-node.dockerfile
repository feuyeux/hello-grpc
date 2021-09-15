FROM node:16-alpine3.11
RUN apk add --update \
      python \
      make \
      g++ \
  && rm -rf /var/cache/apk/*
RUN npm config set registry https://registry.npm.taobao.org && npm install -g node-pre-gyp grpc-tools --unsafe-perm
COPY node/package.json .
RUN npm install --unsafe-perm
COPY node .
RUN npm install --unsafe-perm
# ENTRYPOINT ["node","proto_client.js"]