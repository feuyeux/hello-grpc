FROM openjdk:19-jdk-alpine
COPY hello-grpc-java-client.jar grpc-client.jar
COPY tls/client_certs /var/hello_grpc/client_certs
CMD ["java","-jar","/grpc-client.jar"]