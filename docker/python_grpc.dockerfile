FROM python:3.13-slim AS build-base
ARG PROJECT_ROOT=.
ENV PIP_INDEX_URL=https://mirrors.aliyun.com/pypi/simple/
WORKDIR /app/hello-grpc
COPY hello-grpc-python /app/hello-grpc/hello-grpc-python
COPY proto /app/hello-grpc/proto
COPY scripts/proto2x.sh /app/hello-grpc/
WORKDIR /app/hello-grpc/hello-grpc-python
RUN pip install -r requirements.txt
RUN /app/hello-grpc/proto2x.sh py

FROM python:3.13-slim AS server
ENV PIP_INDEX_URL=https://mirrors.aliyun.com/pypi/simple/
RUN useradd --system --create-home --shell /usr/sbin/nologin app
WORKDIR /app
# Python builds use grpcio-tools' bundled protoc (1.81.1 ships its own
# protoc >=25.x, compatible with protobuf 6.x runtime); the legacy
# apt-installed protobuf-compiler was dropped because it was unused and
# its version (3.21.x on bookworm-slim) diverged from the
# google.protobuf==6.33.5 / grpcio==1.81.1 declared in requirements.txt.
COPY --from=build-base --chown=app:app /app/hello-grpc/hello-grpc-python /app
RUN mkdir -p /var/hello_grpc/server_certs /var/hello_grpc/client_certs
COPY --chown=app:app docker/tls/server_certs/* /var/hello_grpc/server_certs/
COPY --chown=app:app docker/tls/client_certs/* /var/hello_grpc/client_certs/
RUN pip install -r requirements.txt
# Set PYTHONPATH to include the current directory
ENV PYTHONPATH=/app
USER app
ENTRYPOINT ["python", "/app/server/protoServer.py"]

FROM python:3.13-slim AS client
ENV PIP_INDEX_URL=https://mirrors.aliyun.com/pypi/simple/
RUN useradd --system --create-home --shell /usr/sbin/nologin app
WORKDIR /app
# See server stage comment re: dropped protobuf-compiler apt step.
COPY --from=build-base --chown=app:app /app/hello-grpc/hello-grpc-python /app
RUN mkdir -p /var/hello_grpc/client_certs
COPY --chown=app:app docker/tls/client_certs/* /var/hello_grpc/client_certs/
RUN pip install -r requirements.txt
# Set PYTHONPATH to include the current directory
ENV PYTHONPATH=/app
USER app
ENTRYPOINT ["python", "/app/client/protoClient.py"]