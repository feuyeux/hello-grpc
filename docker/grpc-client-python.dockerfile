FROM python:3-slim
COPY hello-grpc-python grpc-client
RUN pip config set global.index-url https://mirrors.aliyun.com/pypi/simple/
WORKDIR /grpc-client
RUN pip install --upgrade pip
RUN pip install -r requirements.txt --no-cache-dir
RUN sh proto2py.sh
COPY tls/client_certs /var/hello_grpc/client_certs
CMD ["sh","client_start.sh"]