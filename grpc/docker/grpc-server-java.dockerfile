FROM openjdk:20-jdk-slim
COPY hello-grpc-java-server.jar grpc-server.jar
COPY tls/server_certs /var/hello_grpc/server_certs
COPY tls/client_certs /var/hello_grpc/client_certs
ENTRYPOINT ["java","-jar","/grpc-server.jar"]