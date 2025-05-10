FROM maven:3.9-eclipse-temurin-24 AS build-base

ARG PROJECT_ROOT=.
WORKDIR /app/hello-grpc
COPY docker/settings.xml /root/.m2/settings.xml
ENV MAVEN_OPTS="-Dmaven.repo.local=/root/.m2/repository"
VOLUME ["/root/.m2/repository"]
COPY hello-grpc-java/src /app/hello-grpc/hello-grpc-java/src
COPY hello-grpc-java/server_pom.xml /app/hello-grpc/hello-grpc-java/server_pom.xml
COPY hello-grpc-java/client_pom.xml /app/hello-grpc/hello-grpc-java/client_pom.xml
COPY proto/ /app/hello-grpc/proto/
RUN mkdir -p /app/hello-grpc/hello-grpc-java/src/main/proto
RUN ln -sf /app/hello-grpc/proto/landing.proto /app/hello-grpc/hello-grpc-java/src/main/proto/landing.proto
RUN if [ -f /app/hello-grpc/proto/landing2.proto ]; then \
    ln -sf /app/hello-grpc/proto/landing2.proto /app/hello-grpc/hello-grpc-java/src/main/proto/landing2.proto; \
    fi

WORKDIR /app/hello-grpc/hello-grpc-java
RUN mvn clean package -DskipTests -f server_pom.xml
RUN cp /app/hello-grpc/hello-grpc-java/target/hello-grpc-java-server.jar /app/hello-grpc/hello-grpc-java/hello-grpc-java-server.jar
RUN mvn clean package -DskipTests -f client_pom.xml
RUN cp /app/hello-grpc/hello-grpc-java/target/hello-grpc-java-client.jar /app/hello-grpc/hello-grpc-java/hello-grpc-java-client.jar


FROM eclipse-temurin:24-jre-alpine AS server
WORKDIR /app
# Try multiple possible locations for the server jar
COPY --from=build-base /app/hello-grpc/hello-grpc-java/hello-grpc-java-server.jar /app/
COPY docker/tls/server_certs/* /var/hello_grpc/server_certs/
COPY docker/tls/client_certs/* /var/hello_grpc/client_certs/
ENTRYPOINT ["java", "-jar", "hello-grpc-java-server.jar"]

FROM eclipse-temurin:24-jre-alpine AS client
WORKDIR /app
COPY --from=build-base /app/hello-grpc/hello-grpc-java/hello-grpc-java-client.jar /app/
COPY docker/tls/client_certs/* /var/hello_grpc/client_certs/
ENTRYPOINT ["java", "-jar", "hello-grpc-java-client.jar"]
