FROM python:3-slim
COPY hello-grpc-python grpc-server
RUN pip config set global.index-url https://mirrors.aliyun.com/pypi/simple/
WORKDIR /grpc-server
RUN pip install --upgrade pip
RUN pip install -r requirements.txt --no-cache-dir
RUN sh proto2py.sh
COPY tls/server_certs /var/hello_grpc/server_certs
COPY tls/client_certs /var/hello_grpc/client_certs
ENTRYPOINT ["sh","server_start.sh"]