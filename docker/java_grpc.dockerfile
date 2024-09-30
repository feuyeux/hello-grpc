FROM openjdk:21-jdk-slim AS server
COPY hello-grpc-java-server.jar grpc-server.jar
COPY tls/server_certs /var/hello_grpc/server_certs
COPY tls/client_certs /var/hello_grpc/client_certs
ENTRYPOINT ["java","-jar","/grpc-server.jar"]

FROM openjdk:21-jdk-slim AS client
COPY hello-grpc-java-client.jar grpc-client.jar
COPY tls/client_certs /var/hello_grpc/client_certs
CMD ["java","-jar","/grpc-client.jar"]
