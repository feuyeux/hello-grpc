FROM openjdk:17-jdk-alpine
COPY hello-grpc-java-client.jar grpc-client.jar
COPY tls/client_certs /var/hello_grpc/client_certs
# ENTRYPOINT ["java","-jar","/grpc-client.jar"]