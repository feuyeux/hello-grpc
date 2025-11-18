# encoding: utf-8
"""
Unified log formatter for gRPC services.

Provides consistent logging format across all RPC methods with standard fields:
service, request_id, method, peer, secure, duration_ms, status
"""

import os
import time
import logging
import grpc

SERVICE_NAME = "python"
IS_SECURE = os.getenv("GRPC_HELLO_SECURE") == "Y"

# Define tracing headers to extract
TRACING_HEADERS = [
    "x-request-id",
    "request-id",
    "x-b3-traceid",
    "x-b3-spanid",
    "x-b3-parentspanid",
    "x-b3-sampled",
    "x-b3-flags",
    "x-ot-span-context"
]


def extract_request_id(context):
    """
    Extract request ID from context metadata.
    
    Args:
        context (grpc.ServicerContext): The RPC context
        
    Returns:
        str: The request ID or "unknown" if not found
    """
    metadata = context.invocation_metadata()
    
    # Try multiple request ID header variants
    for item in metadata:
        if item.key in ["x-request-id", "request-id"]:
            return item.value
    
    return "unknown"


def extract_peer(context):
    """
    Extract peer address from context.
    
    Args:
        context (grpc.ServicerContext): The RPC context
        
    Returns:
        str: The peer address or "unknown" if not found
    """
    try:
        peer = context.peer()
        return peer if peer else "unknown"
    except:
        return "unknown"


def is_secure(context):
    """
    Check if the connection is secure.
    
    Args:
        context (grpc.ServicerContext): The RPC context
        
    Returns:
        bool: True if connection is secure, False otherwise
    """
    try:
        auth_context = context.auth_context()
        return auth_context is not None and len(auth_context) > 0
    except:
        return IS_SECURE


def log_request_start(logger, method, context):
    """
    Log the start of an RPC request.
    
    Args:
        logger (logging.Logger): The logger instance
        method (str): The RPC method name
        context (grpc.ServicerContext): The RPC context
        
    Returns:
        tuple: (request_id, peer, secure, start_time) for use in log_request_end
    """
    request_id = extract_request_id(context)
    peer = extract_peer(context)
    secure = is_secure(context)
    start_time = time.time()
    
    logger.info(
        "service=%s request_id=%s method=%s peer=%s secure=%s status=STARTED",
        SERVICE_NAME, request_id, method, peer, secure
    )
    
    return request_id, peer, secure, start_time


def log_request_end(logger, method, request_id, peer, secure, start_time, status_code="OK"):
    """
    Log the completion of an RPC request.
    
    Args:
        logger (logging.Logger): The logger instance
        method (str): The RPC method name
        request_id (str): The request ID
        peer (str): The peer address
        secure (bool): Whether the connection is secure
        start_time (float): The request start time
        status_code (str): The gRPC status code
    """
    duration_ms = int((time.time() - start_time) * 1000)
    
    logger.info(
        "service=%s request_id=%s method=%s peer=%s secure=%s duration_ms=%d status=%s",
        SERVICE_NAME, request_id, method, peer, secure, duration_ms, status_code
    )


def log_request_error(logger, method, request_id, peer, secure, start_time, 
                     status_code, error_code, message, exception=None):
    """
    Log an error during RPC processing.
    
    Args:
        logger (logging.Logger): The logger instance
        method (str): The RPC method name
        request_id (str): The request ID
        peer (str): The peer address
        secure (bool): Whether the connection is secure
        start_time (float): The request start time
        status_code (str): The gRPC status code
        error_code (str): Error classification code
        message (str): Error message
        exception (Exception): Optional exception for stack trace
    """
    duration_ms = int((time.time() - start_time) * 1000)
    
    if exception:
        logger.error(
            "service=%s request_id=%s method=%s peer=%s secure=%s duration_ms=%d status=%s error_code=%s message=%s",
            SERVICE_NAME, request_id, method, peer, secure, duration_ms, 
            status_code, error_code, message,
            exc_info=exception
        )
    else:
        logger.error(
            "service=%s request_id=%s method=%s peer=%s secure=%s duration_ms=%d status=%s error_code=%s message=%s",
            SERVICE_NAME, request_id, method, peer, secure, duration_ms, 
            status_code, error_code, message
        )


def extract_tracing_headers(context):
    """
    Extract tracing headers from the incoming request context.
    
    Args:
        context (grpc.ServicerContext): The RPC context
        
    Returns:
        list: A list of (key, value) tuples containing the tracing headers
    """
    metadata = context.invocation_metadata()
    tracing_data = []
    
    for item in metadata:
        if item.key in TRACING_HEADERS:
            tracing_data.append((item.key, item.value))
    
    return tracing_data


def set_response_headers(context, request_id):
    """
    Set standard response headers for the RPC call.
    
    Args:
        context (grpc.ServicerContext): The RPC context
        request_id (str): The request ID to include in headers
    """
    try:
        # Send initial metadata (headers)
        context.send_initial_metadata([
            ('server-id', 'python-server'),
            ('x-server-version', '1.0.0'),
            ('x-request-id', request_id),
            ('x-response-timestamp', str(int(time.time() * 1000)))
        ])
    except Exception as e:
        # Ignore errors if headers already sent
        pass


def set_response_trailers(context, duration_ms, status_code):
    """
    Set standard trailing metadata for the RPC call.
    
    Args:
        context (grpc.ServicerContext): The RPC context
        duration_ms (int): Request duration in milliseconds
        status_code (str): The gRPC status code
    """
    try:
        context.set_trailing_metadata([
            ('x-duration-ms', str(duration_ms)),
            ('x-status', status_code)
        ])
    except Exception as e:
        # Ignore errors if trailers already set
        pass


class LoggingInterceptor(grpc.ServerInterceptor):
    """
    gRPC server interceptor that logs requests with unified format.
    """
    
    def __init__(self, logger):
        self.logger = logger
    
    def intercept_service(self, continuation, handler_call_details):
        """
        Intercept the service call to add logging.
        
        Args:
            continuation: The next handler in the chain
            handler_call_details: Details about the RPC call
            
        Returns:
            The RPC handler
        """
        # Get the handler from the continuation
        handler = continuation(handler_call_details)
        
        if handler is None:
            return None
        
        # Wrap the handler to add logging
        if handler.unary_unary:
            return self._wrap_unary_unary(handler, handler_call_details.method)
        elif handler.unary_stream:
            return self._wrap_unary_stream(handler, handler_call_details.method)
        elif handler.stream_unary:
            return self._wrap_stream_unary(handler, handler_call_details.method)
        elif handler.stream_stream:
            return self._wrap_stream_stream(handler, handler_call_details.method)
        
        return handler
    
    def _wrap_unary_unary(self, handler, method):
        """Wrap unary-unary handler with logging."""
        def wrapper(request, context):
            request_id, peer, secure, start_time = log_request_start(self.logger, method, context)
            try:
                response = handler.unary_unary(request, context)
                log_request_end(self.logger, method, request_id, peer, secure, start_time)
                return response
            except Exception as e:
                log_request_error(
                    self.logger, method, request_id, peer, secure, start_time,
                    "INTERNAL", "INTERNAL", str(e), e
                )
                raise
        
        return grpc.unary_unary_rpc_method_handler(
            wrapper,
            request_deserializer=handler.request_deserializer,
            response_serializer=handler.response_serializer
        )
    
    def _wrap_unary_stream(self, handler, method):
        """Wrap unary-stream handler with logging."""
        def wrapper(request, context):
            request_id, peer, secure, start_time = log_request_start(self.logger, method, context)
            try:
                for response in handler.unary_stream(request, context):
                    yield response
                log_request_end(self.logger, method, request_id, peer, secure, start_time)
            except Exception as e:
                log_request_error(
                    self.logger, method, request_id, peer, secure, start_time,
                    "INTERNAL", "INTERNAL", str(e), e
                )
                raise
        
        return grpc.unary_stream_rpc_method_handler(
            wrapper,
            request_deserializer=handler.request_deserializer,
            response_serializer=handler.response_serializer
        )
    
    def _wrap_stream_unary(self, handler, method):
        """Wrap stream-unary handler with logging."""
        def wrapper(request_iterator, context):
            request_id, peer, secure, start_time = log_request_start(self.logger, method, context)
            try:
                response = handler.stream_unary(request_iterator, context)
                log_request_end(self.logger, method, request_id, peer, secure, start_time)
                return response
            except Exception as e:
                log_request_error(
                    self.logger, method, request_id, peer, secure, start_time,
                    "INTERNAL", "INTERNAL", str(e), e
                )
                raise
        
        return grpc.stream_unary_rpc_method_handler(
            wrapper,
            request_deserializer=handler.request_deserializer,
            response_serializer=handler.response_serializer
        )
    
    def _wrap_stream_stream(self, handler, method):
        """Wrap stream-stream handler with logging."""
        def wrapper(request_iterator, context):
            request_id, peer, secure, start_time = log_request_start(self.logger, method, context)
            try:
                for response in handler.stream_stream(request_iterator, context):
                    yield response
                log_request_end(self.logger, method, request_id, peer, secure, start_time)
            except Exception as e:
                log_request_error(
                    self.logger, method, request_id, peer, secure, start_time,
                    "INTERNAL", "INTERNAL", str(e), e
                )
                raise
        
        return grpc.stream_stream_rpc_method_handler(
            wrapper,
            request_deserializer=handler.request_deserializer,
            response_serializer=handler.response_serializer
        )
