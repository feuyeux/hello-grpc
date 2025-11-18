# encoding: utf-8
"""
Retry helper for gRPC client calls.

Implements unified retry strategy:
- Max 3 retries (4 total attempts)
- Exponential backoff: 0.2s, 0.4s, 0.8s
- Retryable status codes: UNAVAILABLE, DEADLINE_EXCEEDED
"""

import time
import logging
from functools import wraps
import grpc

logger = logging.getLogger('grpc-retry')

# Retry configuration
MAX_RETRY_ATTEMPTS = 3  # Max retries (total attempts = 4)
INITIAL_BACKOFF = 0.2  # Initial backoff in seconds
BACKOFF_MULTIPLIER = 2.0  # Exponential backoff multiplier
MAX_BACKOFF = 2.0  # Maximum backoff in seconds

# Retryable gRPC status codes
RETRYABLE_STATUS_CODES = {
    grpc.StatusCode.UNAVAILABLE,
    grpc.StatusCode.DEADLINE_EXCEEDED,
}


def with_retry(func):
    """
    Decorator that adds retry logic to gRPC client calls.
    
    Retries the function call up to MAX_RETRY_ATTEMPTS times with exponential backoff
    when encountering retryable gRPC errors.
    
    Args:
        func: The function to wrap with retry logic
        
    Returns:
        Wrapped function with retry capability
    """
    @wraps(func)
    def wrapper(*args, **kwargs):
        last_exception = None
        backoff = INITIAL_BACKOFF
        
        for attempt in range(MAX_RETRY_ATTEMPTS + 1):  # +1 for initial attempt
            try:
                return func(*args, **kwargs)
            except grpc.RpcError as e:
                last_exception = e
                status_code = e.code()
                
                # Check if this is a retryable error
                if status_code not in RETRYABLE_STATUS_CODES:
                    logger.error(f"Non-retryable error: {status_code} - {e.details()}")
                    raise
                
                # Check if we've exhausted retries
                if attempt >= MAX_RETRY_ATTEMPTS:
                    logger.error(f"Max retry attempts ({MAX_RETRY_ATTEMPTS}) reached for {func.__name__}")
                    raise
                
                # Log retry attempt
                logger.warning(
                    f"Retry attempt {attempt + 1}/{MAX_RETRY_ATTEMPTS} for {func.__name__} "
                    f"after {status_code} error. Backing off for {backoff:.2f}s"
                )
                
                # Wait before retrying
                time.sleep(backoff)
                
                # Calculate next backoff with exponential increase
                backoff = min(backoff * BACKOFF_MULTIPLIER, MAX_BACKOFF)
            except Exception as e:
                # Non-gRPC errors are not retried
                logger.error(f"Non-gRPC error in {func.__name__}: {type(e).__name__} - {str(e)}")
                raise
        
        # This should never be reached, but just in case
        if last_exception:
            raise last_exception
    
    return wrapper


def retry_grpc_call(call_func, *args, **kwargs):
    """
    Execute a gRPC call with retry logic.
    
    This is a functional alternative to the decorator for cases where
    you want to explicitly wrap a call.
    
    Args:
        call_func: The gRPC call function to execute
        *args: Positional arguments to pass to the call function
        **kwargs: Keyword arguments to pass to the call function
        
    Returns:
        The result of the gRPC call
        
    Raises:
        grpc.RpcError: If the call fails after all retry attempts
    """
    last_exception = None
    backoff = INITIAL_BACKOFF
    
    for attempt in range(MAX_RETRY_ATTEMPTS + 1):
        try:
            return call_func(*args, **kwargs)
        except grpc.RpcError as e:
            last_exception = e
            status_code = e.code()
            
            if status_code not in RETRYABLE_STATUS_CODES:
                logger.error(f"Non-retryable error: {status_code} - {e.details()}")
                raise
            
            if attempt >= MAX_RETRY_ATTEMPTS:
                logger.error(f"Max retry attempts ({MAX_RETRY_ATTEMPTS}) reached")
                raise
            
            logger.warning(
                f"Retry attempt {attempt + 1}/{MAX_RETRY_ATTEMPTS} "
                f"after {status_code} error. Backing off for {backoff:.2f}s"
            )
            
            time.sleep(backoff)
            backoff = min(backoff * BACKOFF_MULTIPLIER, MAX_BACKOFF)
        except Exception as e:
            logger.error(f"Non-gRPC error: {type(e).__name__} - {str(e)}")
            raise
    
    if last_exception:
        raise last_exception
