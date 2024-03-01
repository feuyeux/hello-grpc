FROM node:21-alpine AS build

FROM node:21-alpine AS server
COPY hello-grpc-ts /hello-grpc
WORKDIR /hello-grpc
RUN yarn config set registry https://registry.npmmirror.com && \
    npm config set registry https://registry.npmmirror.com
RUN yarn install && npm install -g ts-node
# RUN tsc hello_server.ts
CMD ["ts-node", "hello_server.ts"]

FROM node:21-alpine AS client
COPY hello-grpc-ts /hello-grpc
WORKDIR /hello-grpc
RUN yarn config set registry https://registry.npmmirror.com && \
    npm config set registry https://registry.npmmirror.com
RUN yarn install && npm install -g ts-node
CMD ["ts-node", "hello_client.ts"]