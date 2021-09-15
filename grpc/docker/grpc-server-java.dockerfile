FROM openjdk:17-jdk-alpine
COPY hello-grpc-java-server.jar grpc-server.jar
COPY tls/server_certs /var/hello_grpc/server_certs
ENTRYPOINT ["java","-jar","/grpc-server.jar"]