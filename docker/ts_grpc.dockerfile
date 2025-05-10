FROM node:23-alpine AS build-base
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories
RUN apk add --update jq && rm -rf /var/cache/apk/*
RUN npm config set registry https://registry.npmmirror.com

WORKDIR /app/hello-grpc
COPY hello-grpc-ts /app/hello-grpc/hello-grpc-ts
COPY proto /app/hello-grpc/hello-grpc-ts/proto

# Build TypeScript project
WORKDIR /app/hello-grpc/hello-grpc-ts
RUN npm install
RUN npm run compile
# Ensure the common directory exists in dist
RUN mkdir -p dist/common
# Copy the gRPC files to the dist/common directory
RUN cp -r common/landing*.js common/landing*.d.ts dist/common/

FROM node:23-alpine AS server
WORKDIR /app
COPY --from=build-base /app/hello-grpc/hello-grpc-ts/dist /app/dist
COPY --from=build-base /app/hello-grpc/hello-grpc-ts/package*.json /app/
RUN npm install --production
COPY docker/tls/server_certs/* /var/hello_grpc/server_certs/
COPY docker/tls/client_certs/* /var/hello_grpc/client_certs/
ENTRYPOINT ["node", "dist/hello_server.js"]

FROM node:23-alpine AS client
WORKDIR /app
COPY --from=build-base /app/hello-grpc/hello-grpc-ts/dist /app/dist
COPY --from=build-base /app/hello-grpc/hello-grpc-ts/package*.json /app/
RUN npm install --production
COPY docker/tls/client_certs/* /var/hello_grpc/client_certs/
ENTRYPOINT ["node", "dist/hello_client.js"]