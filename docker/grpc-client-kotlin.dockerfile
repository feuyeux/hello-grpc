FROM openjdk:21-jdk-slim
COPY client_start.sh client_start.sh
COPY proto-client-all.jar lib/proto-client-all.jar
COPY tls/client_certs /var/hello_grpc/client_certs
ENTRYPOINT ["sh","client_start.sh"]