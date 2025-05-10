FROM python:3.12-slim AS build-base
ARG PROJECT_ROOT=.
WORKDIR /app/hello-grpc
COPY hello-grpc-python /app/hello-grpc/hello-grpc-python
COPY proto /app/hello-grpc/proto
COPY proto2x.sh /app/hello-grpc/
WORKDIR /app/hello-grpc/hello-grpc-python
RUN pip install -r requirements.txt
RUN /app/hello-grpc/proto2x.sh py

FROM python:3.12-slim AS server
RUN if [ -f "/etc/apt/sources.list.d/debian.sources" ]; then \
    cp /etc/apt/sources.list.d/debian.sources /etc/apt/sources.list.d/debian.sources.bak && \
    sed -i 's|http://deb.debian.org/debian|http://mirrors.aliyun.com/debian|g' /etc/apt/sources.list.d/debian.sources && \
    sed -i 's|http://deb.debian.org/debian-security|http://mirrors.aliyun.com/debian-security|g' /etc/apt/sources.list.d/debian.sources; \
    fi && \
    # For backwards compatibility, also check for traditional sources.list
    if [ -f "/etc/apt/sources.list" ]; then \
    cp /etc/apt/sources.list /etc/apt/sources.list.bak && \
    sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    sed -i 's/security.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list; \
    fi
RUN apt-get update && apt-get install -y \
    protobuf-compiler \
    git \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
# Copy the entire directory structure to maintain Python package hierarchy
COPY --from=build-base /app/hello-grpc/hello-grpc-python /app
COPY docker/tls/server_certs/* /var/hello_grpc/server_certs/
COPY docker/tls/client_certs/* /var/hello_grpc/client_certs/
RUN pip install -r requirements.txt
# Set PYTHONPATH to include the current directory
ENV PYTHONPATH=/app
ENTRYPOINT ["python", "/app/server/protoServer.py"]

FROM python:3.12-slim AS client
RUN if [ -f "/etc/apt/sources.list.d/debian.sources" ]; then \
    cp /etc/apt/sources.list.d/debian.sources /etc/apt/sources.list.d/debian.sources.bak && \
    sed -i 's|http://deb.debian.org/debian|http://mirrors.aliyun.com/debian|g' /etc/apt/sources.list.d/debian.sources && \
    sed -i 's|http://deb.debian.org/debian-security|http://mirrors.aliyun.com/debian-security|g' /etc/apt/sources.list.d/debian.sources; \
    fi && \
    # For backwards compatibility, also check for traditional sources.list
    if [ -f "/etc/apt/sources.list" ]; then \
    cp /etc/apt/sources.list /etc/apt/sources.list.bak && \
    sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    sed -i 's/security.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list; \
    fi
RUN apt-get update && apt-get install -y \
    protobuf-compiler \
    git \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
# Copy the entire directory structure to maintain Python package hierarchy
COPY --from=build-base /app/hello-grpc/hello-grpc-python /app
COPY docker/tls/client_certs/* /var/hello_grpc/client_certs/
RUN pip install -r requirements.txt
# Set PYTHONPATH to include the current directory
ENV PYTHONPATH=/app
ENTRYPOINT ["python", "/app/client/protoClient.py"]