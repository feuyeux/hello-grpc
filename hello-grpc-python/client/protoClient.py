# encoding: utf-8
"""
gRPC client implementation that demonstrates four gRPC communication patterns.

This module implements a gRPC client that demonstrates:
1. Unary RPC (Talk)
2. Server Streaming RPC (TalkOneAnswerMore)
3. Client Streaming RPC (TalkMoreAnswerOne)
4. Bidirectional Streaming RPC (TalkBidirectional)

This client follows the standardized structure:
1. Configuration constants
2. Logger initialization
3. Connection setup
4. RPC method implementations (unary, server streaming, client streaming, bidirectional)
5. Helper functions
6. Main execution function
7. Cleanup and shutdown
"""

import os
import sys
import logging
import random
import time
import signal

# Add the parent directory to the Python path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from conn import connection, utils, landing_pb2_grpc, landing_pb2, error_mapper

# Configuration constants
RETRY_ATTEMPTS = 3
RETRY_DELAY_SECONDS = 2
ITERATION_COUNT = 3
REQUEST_DELAY_SECONDS = 0.2
SEND_DELAY_SECONDS = 0.002
REQUEST_TIMEOUT_SECONDS = 5
DEFAULT_BATCH_SIZE = 5

# Configure logging
logger = logging.getLogger('grpc-client')
logger.setLevel(logging.INFO)
console = logging.StreamHandler()
console.setLevel(logging.INFO)
formatter = logging.Formatter('[%(asctime)s] [%(levelname)s] [%(name)s] %(message)s',
                              datefmt='%Y-%m-%d %H:%M:%S.%f')
console.setFormatter(formatter)
logger.addHandler(console)

# Common metadata for all requests
DEFAULT_METADATA = (
    ("k1", "v1"),
    ("k2", "v2")
)

# Global flag for graceful shutdown
shutdown_requested = False


def execute_unary_call(stub, request):
    """
    Execute a unary RPC call (single request, single response).
    
    Args:
        stub: The gRPC service stub
        request: The TalkRequest to send
        
    Returns:
        TalkResponse: The response from the server
    """
    request_id = f"unary-{time.time_ns()}"
    logger.info("Sending unary request: data=%s, meta=%s", request.data, request.meta)
    
    start_time = time.time()
    try:
        response = stub.Talk(request=request, metadata=DEFAULT_METADATA, timeout=REQUEST_TIMEOUT_SECONDS)
        duration = time.time() - start_time
        logger.info("Unary call successful in %.3fs", duration)
        return response
    except Exception as e:
        error_mapper.log_error(e, request_id, "Talk")
        raise


def execute_server_streaming_call(stub, request):
    """
    Execute a server streaming RPC call (single request, multiple responses).
    
    Args:
        stub: The gRPC service stub
        request: The TalkRequest to send
    """
    request_id = f"server-stream-{time.time_ns()}"
    logger.info("Starting server streaming with request: data=%s, meta=%s", request.data, request.meta)
    
    start_time = time.time()
    response_count = 0
    
    try:
        response_stream = stub.TalkOneAnswerMore(request=request, metadata=DEFAULT_METADATA, 
                                                  timeout=REQUEST_TIMEOUT_SECONDS)
        
        for response in response_stream:
            if shutdown_requested:
                logger.info("Server streaming cancelled")
                break
            response_count += 1
            logger.info("Received server streaming response #%d:", response_count)
            log_response(response)
        
        duration = time.time() - start_time
        logger.info("Server streaming completed: received %d responses in %.3fs", response_count, duration)
        
    except Exception as e:
        error_mapper.log_error(e, request_id, "TalkOneAnswerMore")
        raise


def execute_client_streaming_call(stub, requests):
    """
    Execute a client streaming RPC call (multiple requests, single response).
    
    Args:
        stub: The gRPC service stub
        requests: List of TalkRequest objects to send
        
    Returns:
        TalkResponse: The response from the server
    """
    request_id = f"client-stream-{time.time_ns()}"
    logger.info("Starting client streaming with %d requests", len(requests))
    
    start_time = time.time()
    request_count = 0
    
    def request_generator():
        nonlocal request_count
        for request in requests:
            if shutdown_requested:
                logger.info("Client streaming cancelled")
                break
            request_count += 1
            logger.info("Sending client streaming request #%d: data=%s, meta=%s", 
                       request_count, request.data, request.meta)
            yield request
            time.sleep(SEND_DELAY_SECONDS)
    
    try:
        response = stub.TalkMoreAnswerOne(request_iterator=request_generator(), 
                                          metadata=DEFAULT_METADATA,
                                          timeout=REQUEST_TIMEOUT_SECONDS)
        duration = time.time() - start_time
        logger.info("Client streaming completed: sent %d requests in %.3fs", request_count, duration)
        return response
        
    except Exception as e:
        error_mapper.log_error(e, request_id, "TalkMoreAnswerOne")
        raise


def execute_bidirectional_streaming_call(stub, requests):
    """
    Execute a bidirectional streaming RPC call (multiple requests, multiple responses).
    
    Args:
        stub: The gRPC service stub
        requests: List of TalkRequest objects to send
    """
    request_id = f"bidirectional-{time.time_ns()}"
    logger.info("Starting bidirectional streaming with %d requests", len(requests))
    
    start_time = time.time()
    request_count = 0
    response_count = 0
    
    def request_generator():
        nonlocal request_count
        for request in requests:
            if shutdown_requested:
                logger.info("Bidirectional streaming cancelled")
                break
            request_count += 1
            logger.info("Sending bidirectional streaming request #%d: data=%s, meta=%s", 
                       request_count, request.data, request.meta)
            yield request
            time.sleep(SEND_DELAY_SECONDS)
    
    try:
        response_stream = stub.TalkBidirectional(request_iterator=request_generator(), 
                                                  metadata=DEFAULT_METADATA,
                                                  timeout=REQUEST_TIMEOUT_SECONDS)
        
        for response in response_stream:
            if shutdown_requested:
                logger.info("Bidirectional streaming cancelled")
                break
            response_count += 1
            logger.info("Received bidirectional streaming response #%d:", response_count)
            log_response(response)
        
        duration = time.time() - start_time
        logger.info("Bidirectional streaming completed in %.3fs", duration)
        
    except Exception as e:
        error_mapper.log_error(e, request_id, "TalkBidirectional")
        raise


def log_response(response):
    """
    Log the details of a response received from the server in a standardized format.
    
    Args:
        response: TalkResponse received from the server
    """
    if response is None:
        logger.warning("Received nil response")
        return
    
    results_count = len(response.results)
    logger.info("Response status: %d, results: %d", response.status, results_count)
    
    for i, result in enumerate(response.results, 1):
        kv = result.kv
        if not kv:
            logger.info("  Result #%d: id=%d, type=%d, kv=nil", i, result.id, result.type)
            continue
        
        meta = kv.get("meta", "")
        result_id = kv.get("id", "")
        idx = kv.get("idx", "")
        data = kv.get("data", "")
        
        logger.info("  Result #%d: id=%d, type=%d, meta=%s, id=%s, idx=%s, data=%s",
                   i, result.id, result.type, meta, result_id, idx, data)


def signal_handler(signum, frame):
    """
    Handle shutdown signals for graceful termination.
    
    Args:
        signum: Signal number
        frame: Current stack frame
    """
    global shutdown_requested
    logger.info("Received shutdown signal, cancelling operations")
    shutdown_requested = True


def run_grpc_calls(stub, delay_seconds, iterations):
    """
    Execute all four gRPC patterns multiple times.
    
    Args:
        stub: The gRPC service stub
        delay_seconds: Delay between iterations in seconds
        iterations: Number of times to run all patterns
        
    Returns:
        bool: True if all calls completed successfully, False otherwise
    """
    for iteration in range(1, iterations + 1):
        if shutdown_requested:
            logger.info("Client execution cancelled")
            return False
        
        logger.info("====== Starting iteration %d/%d ======", iteration, iterations)
        
        try:
            # 1. Unary RPC
            logger.info("----- Executing unary RPC -----")
            unary_request = landing_pb2.TalkRequest(data="0", meta="PYTHON")
            response = execute_unary_call(stub, unary_request)
            log_response(response)
            
            # 2. Server Streaming RPC
            logger.info("----- Executing server streaming RPC -----")
            server_stream_request = landing_pb2.TalkRequest(data="0,1,2", meta="PYTHON")
            execute_server_streaming_call(stub, server_stream_request)
            
            # 3. Client Streaming RPC
            logger.info("----- Executing client streaming RPC -----")
            client_stream_requests = utils.build_link_requests()
            response = execute_client_streaming_call(stub, list(client_stream_requests))
            log_response(response)
            
            # 4. Bidirectional Streaming RPC
            logger.info("----- Executing bidirectional streaming RPC -----")
            bidirectional_requests = utils.build_link_requests()
            execute_bidirectional_streaming_call(stub, list(bidirectional_requests))
            
            # Wait before next iteration, unless it's the last one
            if iteration < iterations:
                logger.info("Waiting %.3fs before next iteration...", delay_seconds)
                time.sleep(delay_seconds)
                
        except Exception as e:
            if shutdown_requested:
                logger.info("Client execution cancelled")
                return False
            logger.error("Error in iteration %d: %s", iteration, e)
            return False
    
    logger.info("All gRPC calls completed successfully")
    return True


def run():
    """
    Main execution function that runs all four gRPC communication patterns.
    """
    # Setup signal handling for graceful shutdown
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    logger.info("Starting gRPC client [version: %s]", utils.get_version())
    
    channel = None
    success = False
    
    # Attempt to establish connection and run all patterns
    for attempt in range(1, RETRY_ATTEMPTS + 1):
        if shutdown_requested:
            logger.info("Client shutting down, aborting retries")
            break
        
        logger.info("Connection attempt %d/%d", attempt, RETRY_ATTEMPTS)
        
        try:
            # Create a gRPC channel and stub
            channel = connection.build_channel()
            stub = landing_pb2_grpc.LandingServiceStub(channel)
            
            # Run all the gRPC patterns
            success = run_grpc_calls(stub, REQUEST_DELAY_SECONDS, ITERATION_COUNT)
            
            if success or shutdown_requested:
                break  # Success or deliberate cancellation, no retry needed
            
        except Exception as e:
            logger.error("Connection attempt %d failed: %s", attempt, e)
            if attempt < RETRY_ATTEMPTS:
                logger.info("Retrying in %ds...", RETRY_DELAY_SECONDS)
                time.sleep(RETRY_DELAY_SECONDS)
            else:
                logger.error("Maximum connection attempts reached, exiting")
        
        finally:
            # Ensure channel is closed for this attempt
            if channel and not success:
                channel.close()
                channel = None
    
    # Final cleanup
    if channel:
        logger.debug("Closing client connection")
        channel.close()
    
    if not success and not shutdown_requested:
        logger.error("Failed to execute all gRPC calls successfully")
        sys.exit(1)
    
    if shutdown_requested:
        logger.info("Client execution was cancelled")
    else:
        logger.info("Client execution completed successfully")


if __name__ == '__main__':
    run()
