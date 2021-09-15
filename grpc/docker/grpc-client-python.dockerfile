FROM python:2
RUN pip install grpcio-tools --no-cache-dir
COPY py grpc-client
RUN sh /grpc-client/proto2py.sh && touch /grpc-client/landing_pb2/__init__.py 
# ENTRYPOINT ["sh","/grpc-client/start_client.sh"]