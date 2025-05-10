# encoding: utf-8
"""
gRPC client implementation that demonstrates four gRPC communication patterns.

This module implements a gRPC client that demonstrates:
1. Unary RPC (Talk)
2. Server Streaming RPC (TalkOneAnswerMore)
3. Client Streaming RPC (TalkMoreAnswerOne)
4. Bidirectional Streaming RPC (TalkBidirectional)
"""

import os
import sys
import logging
import random
import time

# Add the parent directory to the Python path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from conn import connection, utils, landing_pb2_grpc, landing_pb2

# Configure logging
logger = logging.getLogger('grpc-client')
logger.setLevel(logging.INFO)
console = logging.StreamHandler()
console.setLevel(logging.INFO)
formatter = logging.Formatter('%(asctime)s [%(levelname)s] - %(message)s')
console.setFormatter(formatter)
logger.addHandler(console)

# Common metadata for all requests
DEFAULT_METADATA = (
    ("k1", "v1"),
    ("k2", "v2")
)


def execute_unary_call(stub):
    """
    Execute a unary RPC call (single request, single response).
    
    Args:
        stub: The gRPC service stub
    """
    request = landing_pb2.TalkRequest(data="0", meta="PYTHON")
    logger.info("Executing unary call - data: %s, meta: %s", request.data, request.meta)
    
    response = stub.Talk(request=request, metadata=DEFAULT_METADATA)
    log_response("Unary", response)


def execute_server_streaming(stub):
    """
    Execute a server streaming RPC call (single request, multiple responses).
    
    Args:
        stub: The gRPC service stub
    """
    request = landing_pb2.TalkRequest(data="0,1,2", meta="PYTHON")
    logger.info("Executing server streaming - data: %s, meta: %s", request.data, request.meta)
    
    response_stream = stub.TalkOneAnswerMore(request=request, metadata=DEFAULT_METADATA)
    for response in response_stream:
        log_response("ServerStreaming", response)


def execute_client_streaming(stub):
    """
    Execute a client streaming RPC call (multiple requests, single response).
    
    Args:
        stub: The gRPC service stub
    """
    request_iterator = generate_requests("ClientStreaming")
    response = stub.TalkMoreAnswerOne(request_iterator=request_iterator, metadata=DEFAULT_METADATA)
    log_response("ClientStreaming", response)


def execute_bidirectional_streaming(stub):
    """
    Execute a bidirectional streaming RPC call (multiple requests, multiple responses).
    
    Args:
        stub: The gRPC service stub
    """
    request_iterator = generate_requests("BidirectionalStreaming")
    response_stream = stub.TalkBidirectional(request_iterator=request_iterator, metadata=DEFAULT_METADATA)
    
    for response in response_stream:
        log_response("BidirectionalStreaming", response)


def generate_requests(operation_name):
    """
    Generate a sequence of requests with simulated processing time between them.
    
    Args:
        operation_name: Name of the RPC operation (for logging)
        
    Yields:
        landing_pb2.TalkRequest: Request objects to send to the server
    """
    requests = utils.build_link_requests()
    
    # Yield each request with a small random delay between them
    while len(requests) > 0:
        request = requests.pop()
        logger.info("%s - Sending request - data: %s, meta: %s", 
                   operation_name, request.data, request.meta)
        yield request
        
        # Simulate processing time between requests
        time.sleep(random.uniform(0.5, 1.0))


def log_response(operation_name, response):
    """
    Log the details of a response received from the server.
    
    Args:
        operation_name: Name of the RPC operation
        response: Response received from the server
    """
    for result in response.results:
        kv = result.kv
        logger.info("%s response - Status: %d, ID: %d, Language: %s, Type: %s, UUID: %s, Index: %s, Data: %s",
                   operation_name, response.status, result.id, kv["meta"], 
                   result.type, kv["id"], kv["idx"], kv["data"])


def run():
    """
    Run all four gRPC communication patterns.
    """
    # Create a gRPC channel and stub
    channel = connection.build_channel()
    stub = landing_pb2_grpc.LandingServiceStub(channel)
    
    try:
        logger.info("Starting gRPC client demonstration")
        
        # 1. Unary RPC
        logger.info("=== Unary RPC ===")
        execute_unary_call(stub)
        
        # 2. Server Streaming RPC
        logger.info("=== Server Streaming RPC ===")
        execute_server_streaming(stub)
        
        # 3. Client Streaming RPC
        logger.info("=== Client Streaming RPC ===")
        execute_client_streaming(stub)
        
        # 4. Bidirectional Streaming RPC
        logger.info("=== Bidirectional Streaming RPC ===")
        execute_bidirectional_streaming(stub)
        
        logger.info("gRPC client demonstration completed")
    finally:
        # Ensure channel is closed
        channel.close()


if __name__ == '__main__':
    run()
