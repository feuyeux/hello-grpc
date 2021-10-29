# encoding: utf-8
import logging
import os
import time
import uuid

import grpc
from concurrent import futures

from conn import connection
from landing_pb2 import landing_pb2
from landing_pb2 import landing_pb2_grpc

logger = logging.getLogger('grpc-server')
logger.setLevel(logging.INFO)
console = logging.StreamHandler()
console.setLevel(logging.INFO)
formatter = logging.Formatter('%(asctime)s [%(levelname)s] - %(message)s')
console.setFormatter(formatter)
logger.addHandler(console)

hellos = ["Hello", "Bonjour", "Hola", "こんにちは", "Ciao", "안녕하세요"]
tracing_keys = [
    "x-request-id",
    "x-b3-traceid",
    "x-b3-spanid",
    "x-b3-parentspanid",
    "x-b3-sampled",
    "x-b3-flags",
    "x-ot-span-context"
]
cert = "/var/hello_grpc/server_certs/cert.pem"
certKey = "/var/hello_grpc/server_certs/private.key"
certChain = "/var/hello_grpc/server_certs/full_chain.pem"
rootCert = "/var/hello_grpc/server_certs/myssl_root.cer"


def build_result(data):
    result = landing_pb2.TalkResult()
    result.id = int((time.time()))
    result.type = landing_pb2.OK
    result.kv["id"] = str(uuid.uuid1())
    result.kv["idx"] = data
    index = int(data)
    result.kv["data"] = hellos[index]
    result.kv["meta"] = "PYTHON"
    return result


def propaganda_headers(method_name, context):
    metadata = context.invocation_metadata()
    metadata_dict = {}
    for c in metadata:
        logger.info("%s ->H %s:%s", method_name, c.key, c.value)
        if c.key in tracing_keys:
            logger.info("%s ->T %s:%s", method_name, c.key, c.value)
            metadata_dict[c.key] = c.value
    # Converting dictionary into list of tuple
    return list(metadata_dict.items())


def print_headers(method_name, context):
    metadata = context.invocation_metadata()
    for c in metadata:
        logger.info("%s ->H %s:%s", method_name, c.key, c.value)
        if c.key in tracing_keys:
            logger.info("%s ->T %s:%s", method_name, c.key, c.value)


class LandingServiceServer(landing_pb2_grpc.LandingServiceServicer):
    def __init__(self, next_one):
        self.next_one = next_one

    def Talk(self, request, context):
        logger.info("TALK REQUEST: data=%s,meta=%s", request.data, request.meta)
        if self.next_one:
            headers = propaganda_headers("TALK", context)
            try:
                return self.next_one.talk(request=request, metadata=headers)
            except Exception as e:
                logger.error("Unexpected Error: {}".format(e))
        else:
            print_headers("TALK", context)
            response = landing_pb2.TalkResponse()
            response.status = 200
            result = build_result(request.data)
            response.results.append(result)
            return response

    def TalkOneAnswerMore(self, request, context):
        logger.info("TalkOneAnswerMore REQUEST: data=%s,meta=%s", request.data, request.meta)
        if self.next_one:
            headers = propaganda_headers("TalkOneAnswerMore", context)
            responses = self.next_one.talkOneAnswerMore(request=request, metadata=headers)
            for response in responses:
                yield response
        else:
            print_headers("TalkOneAnswerMore", context)
            datas = request.data.split(",")
            for data in datas:
                response = landing_pb2.TalkResponse()
                response.status = 200
                result = build_result(data)
                response.results.append(result)
                yield response

    def TalkMoreAnswerOne(self, request_iterator, context):
        if self.next_one:
            headers = propaganda_headers("TalkMoreAnswerOne", context)
            return self.next_one.talkMoreAnswerOne(request_iterator=request_iterator, metadata=headers)
        else:
            response = landing_pb2.TalkResponse()
            response.status = 200
            for request in request_iterator:
                logger.info("TalkMoreAnswerOne REQUEST: data=%s,meta=%s", request.data, request.meta)
                print_headers("TalkMoreAnswerOne", context)
                response.results.append(build_result(request.data))
            return response

    def TalkBidirectional(self, request_iterator, context):
        if self.next_one:
            headers = propaganda_headers("TalkBidirectional", context)
            responses = self.next_one.talkBidirectional(request_iterator=request_iterator, metadata=headers)
            for response in responses:
                yield response
        else:
            for request in request_iterator:
                logger.info("TalkBidirectional REQUEST: data=%s,meta=%s", request.data, request.meta)
                print_headers("TalkMoreAnswerOne", context)
                response = landing_pb2.TalkResponse()
                response.status = 200
                result = build_result(request.data)
                response.results.append(result)
                yield response


def serve():
    backend = os.getenv("GRPC_HELLO_BACKEND")
    back_port = os.getenv("GRPC_HELLO_BACKEND_PORT")
    current_port = os.getenv("GRPC_SERVER_PORT")
    if backend:
        if back_port:
            address = backend + ":" + back_port
        else:
            address = backend + ":9996"
        logger.info("BACKEND:" + address)
        channel = connection.build_channel(address)

        stub = landing_pb2_grpc.LandingServiceStub(channel)
        # set next_one
        service_server = LandingServiceServer(stub)
    else:
        service_server = LandingServiceServer(None)
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    landing_pb2_grpc.add_LandingServiceServicer_to_server(service_server, server)
    if current_port:
        address = "[::]:" + current_port
    else:
        address = '[::]:9996'

    secure = os.getenv("GRPC_HELLO_SECURE")

    if secure == "Y":
        # 以二进制格式打开一个文件用于只读
        with open(certKey, 'rb') as f:
            private_key = f.read()
        with open(certChain, 'rb') as f:
            certificate_chain = f.read()
        with open(rootCert, 'rb') as f:
            root_certificates = f.read()
        server_credentials = grpc.ssl_server_credentials(((private_key, certificate_chain),), root_certificates, True)
        server.add_secure_port(address, server_credentials)
        logger.info("Start GRPC TLS Server:" + address)
    else:
        server.add_insecure_port(address)
        logger.info("Start GRPC Server:" + address)
    server.start()

    try:
        server.wait_for_termination()
    except KeyboardInterrupt:
        server.stop(0)
    channel.close()


if __name__ == '__main__':
    serve()
