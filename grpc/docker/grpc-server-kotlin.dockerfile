FROM openjdk:17-jdk-alpine
COPY start_server.sh start_server.sh
COPY proto-server-all.jar lib/proto-server-all.jar
ENTRYPOINT ["sh","start_server.sh"]