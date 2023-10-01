FROM node:18-alpine AS build

FROM node:18-alpine AS server
COPY hello-grpc-ts /hello-grpc
WORKDIR /hello-grpc
RUN yarn install
RUN npm install -g ts-node
# RUN tsc hello_server.ts
CMD ["ts-node", "hello_server.ts"]

FROM node:18-alpine AS client
COPY hello-grpc-ts /hello-grpc
WORKDIR /hello-grpc
RUN yarn install
RUN npm install -g ts-node
CMD ["ts-node", "hello_client.ts"]