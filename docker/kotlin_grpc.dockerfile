FROM openjdk:21-jdk-slim AS server
COPY server_start.sh server_start.sh
COPY proto-server-all.jar lib/proto-server-all.jar
COPY tls/server_certs /var/hello_grpc/server_certs
COPY tls/client_certs /var/hello_grpc/client_certs
ENTRYPOINT ["sh","server_start.sh"]

FROM openjdk:21-jdk-slim AS client
COPY client_start.sh client_start.sh
COPY proto-client-all.jar lib/proto-client-all.jar
COPY tls/client_certs /var/hello_grpc/client_certs
ENTRYPOINT ["sh","client_start.sh"]