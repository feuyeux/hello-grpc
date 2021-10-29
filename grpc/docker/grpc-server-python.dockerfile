FROM python:2
COPY py grpc-server
RUN pip config set global.index-url https://mirrors.aliyun.com/pypi/simple/
WORKDIR /grpc-server
RUN pip install --upgrade pip
RUN pip install -r requirements.txt --no-cache-dir
RUN sh proto2py.sh && touch landing_pb2/__init__.py 
ENTRYPOINT ["sh","server_start.sh"]