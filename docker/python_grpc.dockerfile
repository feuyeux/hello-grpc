FROM python:3.11-slim AS server
# https://hub.docker.com/_/python
COPY hello-grpc-python grpc-server
RUN pip config set global.index-url https://mirrors.aliyun.com/pypi/simple/
WORKDIR /grpc-server
RUN pip install --upgrade pip
RUN pip install -r requirements.txt --no-cache-dir
RUN sh proto2py.sh
COPY tls/server_certs /var/hello_grpc/server_certs
COPY tls/client_certs /var/hello_grpc/client_certs
ENTRYPOINT ["sh","server_start.sh"]

FROM python:3.11-slim AS client
COPY hello-grpc-python grpc-client
RUN pip config set global.index-url https://mirrors.aliyun.com/pypi/simple/
WORKDIR /grpc-client
RUN pip install --upgrade pip
RUN pip install -r requirements.txt --no-cache-dir
RUN sh proto2py.sh
COPY tls/client_certs /var/hello_grpc/client_certs
CMD ["sh","client_start.sh"]