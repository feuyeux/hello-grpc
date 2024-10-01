FROM dart:3.3.0 AS build

COPY hello-grpc-dart /hello-grpc
WORKDIR /hello-grpc
ENV PUB_HOSTED_URL="https://pub.flutter-io.cn"
RUN dart pub get
RUN dart compile exe server.dart -o bin/server
RUN dart compile exe client.dart -o bin/client

# Build minimal serving image from AOT-compiled `/server` and required system
# libraries and configuration files stored in `/runtime/` from the build stage.
FROM scratch AS server
COPY --from=build /runtime/ /
COPY --from=build /hello-grpc/bin/server /hello-grpc/bin/
CMD ["/hello-grpc/bin/server"]

FROM scratch AS client
COPY --from=build /runtime/ /
COPY --from=build /hello-grpc/bin/client /hello-grpc/bin/
CMD ["/hello-grpc/bin/client"]