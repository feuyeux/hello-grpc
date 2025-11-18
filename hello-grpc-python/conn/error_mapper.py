"""
Error mapper for translating gRPC status codes to human-readable messages
and implementing retry logic with exponential backoff.
"""

import asyncio
import logging
import time
from typing import Callable, Dict, Optional, TypeVar, Any
from dataclasses import dataclass

import grpc

logger = logging.getLogger(__name__)

T = TypeVar('T')


@dataclass
class RetryConfig:
    """Configuration for retry logic"""
    max_retries: int = 3
    initial_delay: float = 2.0  # seconds
    max_delay: float = 30.0  # seconds
    multiplier: float = 2.0

    @staticmethod
    def default() -> 'RetryConfig':
        """Creates default retry configuration"""
        return RetryConfig()


def map_grpc_error(error: Exception) -> str:
    """
    Maps gRPC status codes to human-readable error messages
    
    Args:
        error: The exception to map
        
    Returns:
        Human-readable error message
    """
    if error is None:
        return "Success"
    
    if isinstance(error, grpc.RpcError):
        code = error.code()
        message = error.details() if hasattr(error, 'details') else str(error)
        description = _get_status_description(code)
        
        if message:
            return f"{description}: {message}"
        return description
    
    return f"Unknown error: {str(error)}"


def _get_status_description(code: grpc.StatusCode) -> str:
    """
    Gets human-readable description for a gRPC status code
    
    Args:
        code: The status code
        
    Returns:
        Human-readable description
    """
    descriptions = {
        grpc.StatusCode.OK: "Success",
        grpc.StatusCode.CANCELLED: "Operation cancelled",
        grpc.StatusCode.UNKNOWN: "Unknown error",
        grpc.StatusCode.INVALID_ARGUMENT: "Invalid request parameters",
        grpc.StatusCode.DEADLINE_EXCEEDED: "Request timeout",
        grpc.StatusCode.NOT_FOUND: "Resource not found",
        grpc.StatusCode.ALREADY_EXISTS: "Resource already exists",
        grpc.StatusCode.PERMISSION_DENIED: "Permission denied",
        grpc.StatusCode.RESOURCE_EXHAUSTED: "Resource exhausted",
        grpc.StatusCode.FAILED_PRECONDITION: "Precondition failed",
        grpc.StatusCode.ABORTED: "Operation aborted",
        grpc.StatusCode.OUT_OF_RANGE: "Out of range",
        grpc.StatusCode.UNIMPLEMENTED: "Not implemented",
        grpc.StatusCode.INTERNAL: "Internal server error",
        grpc.StatusCode.UNAVAILABLE: "Service unavailable",
        grpc.StatusCode.DATA_LOSS: "Data loss",
        grpc.StatusCode.UNAUTHENTICATED: "Authentication required",
    }
    return descriptions.get(code, "Unknown error code")


def is_retryable_error(error: Exception) -> bool:
    """
    Determines if an error should be retried
    
    Args:
        error: The exception to check
        
    Returns:
        True if the error is retryable, False otherwise
    """
    if error is None:
        return False
    
    if not isinstance(error, grpc.RpcError):
        return False
    
    code = error.code()
    return code in (
        grpc.StatusCode.UNAVAILABLE,
        grpc.StatusCode.DEADLINE_EXCEEDED,
        grpc.StatusCode.RESOURCE_EXHAUSTED,
        grpc.StatusCode.INTERNAL,
    )


def handle_rpc_error(error: Exception, operation: str, context: Optional[Dict[str, Any]] = None) -> None:
    """
    Handles RPC errors with logging and context
    
    Args:
        error: The exception that occurred
        operation: The operation name
        context: Additional context information
    """
    if error is None:
        return
    
    error_msg = map_grpc_error(error)
    log_context = context.copy() if context else {}
    log_context['operation'] = operation
    log_context['error'] = error_msg
    
    if is_retryable_error(error):
        logger.warning(f"Retryable error occurred: {log_context}")
    else:
        logger.error(f"Non-retryable error occurred: {log_context}")


def retry_with_backoff(
    operation: str,
    func: Callable[[], T],
    config: Optional[RetryConfig] = None
) -> T:
    """
    Executes a function with exponential backoff retry logic (synchronous)
    
    Args:
        operation: The operation name for logging
        func: The function to execute
        config: The retry configuration
        
    Returns:
        The result of the function
        
    Raises:
        Exception: If all retries are exhausted
    """
    if config is None:
        config = RetryConfig.default()
    
    last_error = None
    delay = config.initial_delay
    
    for attempt in range(config.max_retries + 1):
        if attempt > 0:
            logger.info(
                f"Retry attempt {attempt}/{config.max_retries} for {operation} "
                f"after {delay}s"
            )
            time.sleep(delay)
        
        try:
            result = func()
            if attempt > 0:
                logger.info(f"Operation {operation} succeeded after {attempt + 1} attempts")
            return result
        except Exception as e:
            last_error = e
            
            if not is_retryable_error(e):
                logger.warning(f"Non-retryable error for {operation}: {map_grpc_error(e)}")
                raise
            
            if attempt < config.max_retries:
                # Calculate next delay with exponential backoff
                delay = min(delay * config.multiplier, config.max_delay)
    
    logger.error(
        f"Operation {operation} failed after {config.max_retries + 1} attempts: "
        f"{map_grpc_error(last_error)}"
    )
    raise Exception(f"Max retries exceeded for {operation}") from last_error


async def retry_with_backoff_async(
    operation: str,
    func: Callable[[], T],
    config: Optional[RetryConfig] = None
) -> T:
    """
    Executes a function with exponential backoff retry logic (asynchronous)
    
    Args:
        operation: The operation name for logging
        func: The async function to execute
        config: The retry configuration
        
    Returns:
        The result of the function
        
    Raises:
        Exception: If all retries are exhausted
    """
    if config is None:
        config = RetryConfig.default()
    
    last_error = None
    delay = config.initial_delay
    
    for attempt in range(config.max_retries + 1):
        if attempt > 0:
            logger.info(
                f"Retry attempt {attempt}/{config.max_retries} for {operation} "
                f"after {delay}s"
            )
            await asyncio.sleep(delay)
        
        try:
            result = await func()
            if attempt > 0:
                logger.info(f"Operation {operation} succeeded after {attempt + 1} attempts")
            return result
        except Exception as e:
            last_error = e
            
            if not is_retryable_error(e):
                logger.warning(f"Non-retryable error for {operation}: {map_grpc_error(e)}")
                raise
            
            if attempt < config.max_retries:
                # Calculate next delay with exponential backoff
                delay = min(delay * config.multiplier, config.max_delay)
    
    logger.error(
        f"Operation {operation} failed after {config.max_retries + 1} attempts: "
        f"{map_grpc_error(last_error)}"
    )
    raise Exception(f"Max retries exceeded for {operation}") from last_error
