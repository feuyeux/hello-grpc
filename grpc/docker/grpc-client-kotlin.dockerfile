FROM openjdk:17-jdk-alpine
COPY start_client.sh start_client.sh
COPY proto-client-all.jar lib/proto-client-all.jar
ENTRYPOINT ["sh","start_client.sh"]