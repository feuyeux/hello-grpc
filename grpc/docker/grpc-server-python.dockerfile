FROM python:2
RUN pip install grpcio-tools --no-cache-dir
COPY py grpc-server
RUN sh /grpc-server/proto2py.sh && touch /grpc-server/landing_pb2/__init__.py 
ENTRYPOINT ["sh","/grpc-server/start_server.sh"]