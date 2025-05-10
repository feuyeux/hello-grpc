# encoding: utf-8
"""
gRPC server implementation that demonstrates four gRPC communication patterns.

This module implements a gRPC server that supports:
1. Unary RPC (Talk)
2. Server Streaming RPC (TalkOneAnswerMore)
3. Client Streaming RPC (TalkMoreAnswerOne)
4. Bidirectional Streaming RPC (TalkBidirectional)

The server can act as an endpoint or proxy requests to a backend service.
"""

import os
import sys
import logging
import time
import uuid
import platform
from concurrent import futures
from pathlib import Path
import grpc

# Add the parent directory to the Python path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from conn import connection, utils, landing_pb2, landing_pb2_grpc

# Configure logging
logger = logging.getLogger('grpc-server')
logger.setLevel(logging.INFO)
console = logging.StreamHandler()
console.setLevel(logging.INFO)
formatter = logging.Formatter('%(asctime)s [%(levelname)s] - %(message)s')
console.setFormatter(formatter)
logger.addHandler(console)

# Define tracing headers to propagate
TRACING_HEADERS = [
    "x-request-id",
    "x-b3-traceid",
    "x-b3-spanid",
    "x-b3-parentspanid",
    "x-b3-sampled",
    "x-b3-flags",
    "x-ot-span-context"
]


def get_certificate_paths():
    """
    Get platform-specific certificate paths.
    
    Uses environment variable CERT_BASE_PATH if set, otherwise
    determines appropriate path based on operating system.
    
    Returns:
        tuple: A tuple containing (cert_path, key_path, chain_path, root_path)
    """
    # Check for environment variable override
    base_path = os.getenv("CERT_BASE_PATH")
    if not base_path:
        # Use platform-specific paths
        system = platform.system()
        if system == "Windows":
            base_path = Path("d:/garden/var/hello_grpc/server_certs")
        elif system == "Darwin":  # macOS
            base_path = Path("/var/hello_grpc/server_certs")
        else:  # Linux or other Unix
            base_path = Path("/var/hello_grpc/server_certs")
    else:
        base_path = Path(base_path)
    
    return (
        base_path / "cert.pem",
        base_path / "private.key",
        base_path / "full_chain.pem",
        base_path / "myssl_root.cer"
    )


def create_response(data):
    """
    Create a TalkResult object with response data.

    Args:
        data (str): The request ID (typically a language index)

    Returns:
        landing_pb2.TalkResult: A result object with timestamp, type and key-value data
    """
    index = int(data)
    hello = utils.hellos[index]
    answer = utils.ans.get(hello)
    
    result = landing_pb2.TalkResult()
    result.id = int(time.time())
    result.type = landing_pb2.OK
    
    # Add metadata to the response
    result.kv.update({
        "id": str(uuid.uuid4()),
        "idx": data,
        "data": f"{hello},{answer}",
        "meta": "PYTHON"
    })
    
    return result


def extract_tracing_headers(method_name, context):
    """
    Extract tracing headers from the incoming request context.

    Args:
        method_name (str): The name of the gRPC method being called
        context (grpc.ServicerContext): The RPC context

    Returns:
        list: A list of (key, value) tuples containing the tracing headers
    """
    metadata = context.invocation_metadata()
    tracing_data = {}
    
    for item in metadata:
        if item.key in TRACING_HEADERS:
            logger.info("%s - Tracing header: %s:%s", method_name, item.key, item.value)
            tracing_data[item.key] = item.value
    
    return list(tracing_data.items())


def log_request_headers(method_name, context):
    """
    Log headers from the incoming request context.

    Args:
        method_name (str): The name of the gRPC method being called
        context (grpc.ServicerContext): The RPC context
    """
    metadata = context.invocation_metadata()
    for item in metadata:
        logger.info("%s - Header: %s:%s", method_name, item.key, item.value)


class LandingServiceServer(landing_pb2_grpc.LandingServiceServicer):
    """
    Implementation of the LandingService gRPC service.
    
    This class demonstrates four types of gRPC communication patterns:
    1. Unary RPC
    2. Server Streaming RPC
    3. Client Streaming RPC
    4. Bidirectional Streaming RPC
    """

    def __init__(self, backend_service=None):
        """
        Initialize the LandingServiceServer.

        Args:
            backend_service: The next service in the chain (for proxying requests), 
                           or None if this is the final server in the chain
        """
        self.backend_service = backend_service

    def Talk(self, request, context):
        """
        Unary RPC implementation.
        
        Args:
            request (landing_pb2.TalkRequest): Client request with data and metadata
            context (grpc.ServicerContext): The RPC context

        Returns:
            landing_pb2.TalkResponse: Response to send back to the client
        """
        logger.info("Unary call - data: %s, meta: %s", request.data, request.meta)
        
        if self.backend_service:
            # Forward request to backend service
            headers = extract_tracing_headers("Talk", context)
            try:
                return self.backend_service.Talk(request=request, metadata=headers)
            except Exception as e:
                logger.error("Error forwarding unary request: %s", e)
                context.set_code(grpc.StatusCode.INTERNAL)
                context.set_details(str(e))
                return landing_pb2.TalkResponse()
        else:
            # Process request locally
            log_request_headers("Talk", context)
            response = landing_pb2.TalkResponse()
            response.status = 200
            response.results.append(create_response(request.data))
            return response

    def TalkOneAnswerMore(self, request, context):
        """
        Server streaming RPC implementation.
        
        Args:
            request (landing_pb2.TalkRequest): Client request with comma-separated data
            context (grpc.ServicerContext): The RPC context

        Yields:
            landing_pb2.TalkResponse: Multiple responses to send back to the client
        """
        logger.info("Server streaming call - data: %s, meta: %s", request.data, request.meta)
        
        if self.backend_service:
            # Forward request to backend service
            headers = extract_tracing_headers("TalkOneAnswerMore", context)
            try:
                responses = self.backend_service.TalkOneAnswerMore(
                    request=request, metadata=headers)
                for response in responses:
                    yield response
            except Exception as e:
                logger.error("Error in server streaming: %s", e)
                context.abort(grpc.StatusCode.INTERNAL, str(e))
        else:
            # Process request locally
            log_request_headers("TalkOneAnswerMore", context)
            data_items = request.data.split(",")
            
            for item in data_items:
                response = landing_pb2.TalkResponse()
                response.status = 200
                response.results.append(create_response(item))
                yield response

    def TalkMoreAnswerOne(self, request_iterator, context):
        """
        Client streaming RPC implementation.
        
        Args:
            request_iterator: An iterator of client requests
            context (grpc.ServicerContext): The RPC context

        Returns:
            landing_pb2.TalkResponse: A single response for all requests
        """
        if self.backend_service:
            # Forward requests to backend service
            headers = extract_tracing_headers("TalkMoreAnswerOne", context)
            try:
                return self.backend_service.TalkMoreAnswerOne(
                    request_iterator=request_iterator, metadata=headers)
            except Exception as e:
                logger.error("Error in client streaming: %s", e)
                context.abort(grpc.StatusCode.INTERNAL, str(e))
                return landing_pb2.TalkResponse()
        else:
            # Process requests locally
            log_request_headers("TalkMoreAnswerOne", context)
            response = landing_pb2.TalkResponse()
            response.status = 200
            
            for request in request_iterator:
                logger.info("Client streaming request - data: %s, meta: %s", 
                           request.data, request.meta)
                response.results.append(create_response(request.data))
            
            return response

    def TalkBidirectional(self, request_iterator, context):
        """
        Bidirectional streaming RPC implementation.
        
        Args:
            request_iterator: An iterator of client requests
            context (grpc.ServicerContext): The RPC context

        Yields:
            landing_pb2.TalkResponse: Multiple responses, one for each request
        """
        if self.backend_service:
            # Forward requests to backend service
            headers = extract_tracing_headers("TalkBidirectional", context)
            try:
                responses = self.backend_service.TalkBidirectional(
                    request_iterator=request_iterator, metadata=headers)
                for response in responses:
                    yield response
            except Exception as e:
                logger.error("Error in bidirectional streaming: %s", e)
                context.abort(grpc.StatusCode.INTERNAL, str(e))
        else:
            # Process requests locally
            log_request_headers("TalkBidirectional", context)
            
            for request in request_iterator:
                logger.info("Bidirectional streaming request - data: %s, meta: %s", 
                           request.data, request.meta)
                
                response = landing_pb2.TalkResponse()
                response.status = 200
                response.results.append(create_response(request.data))
                yield response


def serve():
    """
    Start the gRPC server with the LandingService implementation.
    
    The server can be configured with the following environment variables:
    - GRPC_HELLO_BACKEND: Backend service to proxy requests to
    - GRPC_SERVER_PORT: Port to listen on (default: 9996)
    - GRPC_HELLO_SECURE: Whether to use TLS ('Y' for TLS)
    """
    # Set up backend connection if configured
    backend_host = os.getenv("GRPC_HELLO_BACKEND")
    backend_service = None
    channel = None
    
    if backend_host:
        channel = connection.build_channel()
        backend_service = landing_pb2_grpc.LandingServiceStub(channel)
    
    # Create and configure gRPC server
    server_impl = LandingServiceServer(backend_service)
    max_workers = os.cpu_count() or 4  # More efficient worker determination
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=max_workers))
    landing_pb2_grpc.add_LandingServiceServicer_to_server(server_impl, server)
    
    # Configure server port and optional TLS
    port = os.getenv("GRPC_SERVER_PORT", "9996")
    address = f"[::]:{port}"
    secure_mode = os.getenv("GRPC_HELLO_SECURE") == "Y"
    
    if secure_mode:
        # Set up TLS
        try:
            cert_path, key_path, chain_path, root_path = get_certificate_paths()
            logger.info("Using TLS with certificates from: %s", cert_path.parent)
            
            with open(cert_path, 'rb') as f:
                certificate = f.read()
            with open(key_path, 'rb') as f:
                private_key = f.read()
            with open(chain_path, 'rb') as f:
                certificate_chain = f.read()
            with open(root_path, 'rb') as f:
                root_certificates = f.read()
            
            server_credentials = grpc.ssl_server_credentials(
                [(private_key, certificate_chain)], 
                root_certificates, 
                require_client_auth=False
            )
            server.add_secure_port(address, server_credentials)
            logger.info("Starting secure gRPC server on port %s", port)
        except (FileNotFoundError, PermissionError) as e:
            logger.error("TLS certificate error: %s", e)
            logger.warning("Falling back to insecure mode")
            server.add_insecure_port(address)
            logger.info("Starting insecure gRPC server on port %s", port)
    else:
        server.add_insecure_port(address)
        logger.info("Starting insecure gRPC server on port %s", port)
        
    # Start server
    python_version = f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}"
    logger.info("Python gRPC server version: %s (Python %s)", utils.get_version(), python_version)
    server.start()
    
    try:
        server.wait_for_termination()
    except KeyboardInterrupt:
        logger.info("Server shutting down...")
        server.stop(0)
    finally:
        if channel:
            channel.close()


if __name__ == '__main__':
    serve()
