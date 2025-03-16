# encoding: utf-8
import logging
import os
import sys
import time
import uuid

import grpc
from concurrent import futures

from conn import connection, utils, landing_pb2, landing_pb2_grpc

logger = logging.getLogger('grpc-server')
logger.setLevel(logging.INFO)
console = logging.StreamHandler()
console.setLevel(logging.INFO)
formatter = logging.Formatter('%(asctime)s [%(levelname)s] - %(message)s')
console.setFormatter(formatter)
logger.addHandler(console)

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
    """
    Build a TalkResult object containing the response data.
    
    Args:
        data (str): The request ID (typically a language index)
        
    Returns:
        landing_pb2.TalkResult: A TalkResult with timestamp, type and key-value data
    """
    result = landing_pb2.TalkResult()
    result.id = int((time.time()))
    result.type = landing_pb2.OK
    result.kv["id"] = str(uuid.uuid1())
    result.kv["idx"] = data
    index = int(data)
    hello = utils.hellos[index]
    result.kv["data"] = hello + "," + utils.ans.get(hello)
    result.kv["meta"] = "PYTHON"
    return result


def propaganda_headers(method_name, context):
    """
    Extract tracing headers from the incoming request context and prepare them
    for propagation to the next service in the chain.
    
    Args:
        method_name (str): The name of the gRPC method being called
        context (grpc.ServicerContext): The RPC context
        
    Returns:
        list: A list of (key, value) tuples containing the tracing headers
    """
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
    """
    Log all headers from the incoming request context.
    
    Args:
        method_name (str): The name of the gRPC method being called
        context (grpc.ServicerContext): The RPC context
    """
    metadata = context.invocation_metadata()
    for c in metadata:
        logger.info("%s ->H %s:%s", method_name, c.key, c.value)
        if c.key in tracing_keys:
            logger.info("%s ->T %s:%s", method_name, c.key, c.value)


class LandingServiceServer(landing_pb2_grpc.LandingServiceServicer):
    """
    Implementation of the LandingService gRPC service.
    
    This class demonstrates four different types of gRPC communication:
    1. Unary RPC - Simple request/response model (Talk)
    2. Server Streaming RPC - Server sends multiple responses to a single client request (TalkOneAnswerMore)
    3. Client Streaming RPC - Client sends multiple requests and server responds with a single response (TalkMoreAnswerOne)
    4. Bidirectional Streaming RPC - Both client and server send a sequence of messages (TalkBidirectional)
    """
    def __init__(self, next_one):
        """
        Initialize the LandingServiceServer.
        
        Args:
            next_one: The next service in the chain (for proxying requests), 
                     or None if this is the final server in the chain
        """
        self.next_one = next_one

    def Talk(self, request, context):
        """
        Unary RPC implementation.
        Handles a single request and returns a single response.
        If a next service is configured, proxies the request to it.
        
        Args:
            request (landing_pb2.TalkRequest): The client request containing data and metadata
            context (grpc.ServicerContext): The RPC context
            
        Returns:
            landing_pb2.TalkResponse: The response to send back to the client
        """
        logger.info("TALK REQUEST: data=%s,meta=%s",
                    request.data, request.meta)
        if self.next_one:
            headers = propaganda_headers("TALK", context)
            try:
                return self.next_one.Talk(request=request, metadata=headers)
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
        """
        Server streaming RPC implementation.
        Handles a single request and returns multiple responses through the stream.
        If a next service is configured, proxies the request to it.
        
        Args:
            request (landing_pb2.TalkRequest): The client request containing comma-separated data values
            context (grpc.ServicerContext): The RPC context
            
        Yields:
            landing_pb2.TalkResponse: Multiple responses to send back to the client
        """
        logger.info("TalkOneAnswerMore REQUEST: data=%s,meta=%s",
                    request.data, request.meta)
        if self.next_one:
            headers = propaganda_headers("TalkOneAnswerMore", context)
            responses = self.next_one.TalkOneAnswerMore(
                request=request, metadata=headers)
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
        """
        Client streaming RPC implementation.
        Handles multiple requests from the client and returns a single response.
        If a next service is configured, proxies all requests to it.
        
        Args:
            request_iterator: An iterator of client requests
            context (grpc.ServicerContext): The RPC context
            
        Returns:
            landing_pb2.TalkResponse: A single response combining results from all requests
        """
        if self.next_one:
            headers = propaganda_headers("TalkMoreAnswerOne", context)
            return self.next_one.TalkMoreAnswerOne(request_iterator=request_iterator, metadata=headers)
        else:
            response = landing_pb2.TalkResponse()
            response.status = 200
            for request in request_iterator:
                logger.info("TalkMoreAnswerOne REQUEST: data=%s,meta=%s",
                            request.data, request.meta)
                print_headers("TalkMoreAnswerOne", context)
                response.results.append(build_result(request.data))
            return response

    def TalkBidirectional(self, request_iterator, context):
        """
        Bidirectional streaming RPC implementation.
        Handles multiple requests from the client and returns multiple responses.
        Each request receives a corresponding response.
        If a next service is configured, proxies all requests to it.
        
        Args:
            request_iterator: An iterator of client requests
            context (grpc.ServicerContext): The RPC context
            
        Yields:
            landing_pb2.TalkResponse: Multiple responses, one for each request
        """
        if self.next_one:
            headers = propaganda_headers("TalkBidirectional", context)
            responses = self.next_one.TalkBidirectional(
                request_iterator=request_iterator, metadata=headers)
            for response in responses:
                yield response
        else:
            for request in request_iterator:
                logger.info("TalkBidirectional REQUEST: data=%s,meta=%s",
                            request.data, request.meta)
                print_headers("TalkMoreAnswerOne", context)
                response = landing_pb2.TalkResponse()
                response.status = 200
                result = build_result(request.data)
                response.results.append(result)
                yield response


def serve():
    """
    Start the gRPC server with the LandingService implementation.
    Configures TLS if specified in the environment.
    
    The server can be configured with the following environment variables:
    - GRPC_HELLO_BACKEND: Backend service to proxy requests to
    - GRPC_SERVER_PORT: Port to listen on (default: 9996)
    - GRPC_HELLO_SECURE: Whether to use TLS ('Y' for TLS)
    """
    concurrent_nums = 20
    backend = os.getenv("GRPC_HELLO_BACKEND")
    if backend:
        channel = connection.build_channel()
        stub = landing_pb2_grpc.LandingServiceStub(channel)
        # set next_one
        service_server = LandingServiceServer(stub)
    else:
        service_server = LandingServiceServer(None)
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=concurrent_nums))
    landing_pb2_grpc.add_LandingServiceServicer_to_server(
        service_server, server)

    port = os.getenv("GRPC_SERVER_PORT")
    if not port:
        port = "9996"
    address = "[::]:" + port
    secure = os.getenv("GRPC_HELLO_SECURE")
    python_version = sys.version_info
    if secure == "Y":
        # 以二进制格式打开一个文件用于只读
        with open(certKey, 'rb') as f:
            private_key = f.read()
        with open(certChain, 'rb') as f:
            certificate_chain = f.read()
        with open(rootCert, 'rb') as f:
            root_certificates = f.read()
        pairs = ((private_key, certificate_chain),)
        require_client_auth = False
        server_credentials = grpc.ssl_server_credentials(
            pairs, root_certificates, require_client_auth)
        server.add_secure_port(address, server_credentials)
        logger.info("Start GRPC TLS Server:[%s] (version:%s.%s.%s)", port, python_version[0], python_version[1],
                    python_version[2])
    else:
        server.add_insecure_port(address)
        logger.info("Start GRPC Server:[%s] (version:%s.%s.%s)", port, python_version[0], python_version[1],
                    python_version[2])
    server.start()

    try:
        server.wait_for_termination()
        channel.close()
    except KeyboardInterrupt:
        server.stop(0)


if __name__ == '__main__':
    serve()
