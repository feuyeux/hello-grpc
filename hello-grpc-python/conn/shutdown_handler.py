"""
Manages graceful shutdown of the application
"""

import asyncio
import logging
import signal
import sys
from typing import Callable, List, Optional

logger = logging.getLogger(__name__)

DEFAULT_SHUTDOWN_TIMEOUT = 30.0  # seconds


class ShutdownHandler:
    """Manages graceful shutdown with signal handling and cleanup functions"""

    def __init__(self, timeout: float = DEFAULT_SHUTDOWN_TIMEOUT):
        """
        Initialize shutdown handler
        
        Args:
            timeout: Timeout in seconds for graceful shutdown
        """
        self.timeout = timeout
        self.cleanup_functions: List[Callable[[], None]] = []
        self.shutdown_event = asyncio.Event()
        self.shutdown_initiated = False
        
        # Register signal handlers
        self._register_signal_handlers()

    def _register_signal_handlers(self):
        """Register handlers for SIGINT and SIGTERM"""
        try:
            signal.signal(signal.SIGINT, self._signal_handler)
            signal.signal(signal.SIGTERM, self._signal_handler)
        except ValueError as e:
            logger.warning(f"Could not register signal handlers: {e}")

    def _signal_handler(self, signum, frame):
        """Handle shutdown signals"""
        sig_name = signal.Signals(signum).name
        logger.info(f"Received {sig_name} signal")
        self.initiate_shutdown()

    def register_cleanup(self, cleanup_fn: Callable[[], None]):
        """
        Register a cleanup function to be called during shutdown
        
        Args:
            cleanup_fn: Function to call during shutdown
        """
        self.cleanup_functions.append(cleanup_fn)

    def initiate_shutdown(self):
        """Initiate the shutdown process"""
        if self.shutdown_initiated:
            return
        self.shutdown_initiated = True
        self.shutdown_event.set()

    def wait(self):
        """Wait for a shutdown signal (synchronous)"""
        try:
            signal.pause()
        except KeyboardInterrupt:
            logger.info("Received keyboard interrupt")
            self.initiate_shutdown()

    async def wait_async(self):
        """Wait for a shutdown signal (asynchronous)"""
        await self.shutdown_event.wait()

    def shutdown(self) -> bool:
        """
        Perform graceful shutdown with timeout (synchronous)
        
        Returns:
            True if shutdown completed successfully, False if timeout occurred
        """
        logger.info("Starting graceful shutdown...")

        # Execute cleanup functions in reverse order (LIFO)
        has_errors = False
        for cleanup_fn in reversed(self.cleanup_functions):
            try:
                cleanup_fn()
            except Exception as e:
                logger.error(f"Error during cleanup: {e}")
                has_errors = True

        if has_errors:
            logger.warning("Shutdown completed with errors")
        else:
            logger.info("Graceful shutdown completed successfully")

        return not has_errors

    async def shutdown_async(self) -> bool:
        """
        Perform graceful shutdown with timeout (asynchronous)
        
        Returns:
            True if shutdown completed successfully, False if timeout occurred
        """
        logger.info("Starting graceful shutdown...")

        try:
            # Execute cleanup functions in reverse order (LIFO)
            has_errors = False
            for cleanup_fn in reversed(self.cleanup_functions):
                try:
                    if asyncio.iscoroutinefunction(cleanup_fn):
                        await asyncio.wait_for(cleanup_fn(), timeout=self.timeout)
                    else:
                        cleanup_fn()
                except asyncio.TimeoutError:
                    logger.warning(f"Cleanup function timed out after {self.timeout}s")
                    has_errors = True
                except Exception as e:
                    logger.error(f"Error during cleanup: {e}")
                    has_errors = True

            if has_errors:
                logger.warning("Shutdown completed with errors")
            else:
                logger.info("Graceful shutdown completed successfully")

            return not has_errors

        except asyncio.TimeoutError:
            logger.warning("Shutdown timeout exceeded, forcing shutdown")
            return False

    def wait_and_shutdown(self) -> bool:
        """
        Wait for a shutdown signal and then perform shutdown (synchronous)
        
        Returns:
            True if shutdown completed successfully, False if timeout occurred
        """
        self.wait()
        return self.shutdown()

    async def wait_and_shutdown_async(self) -> bool:
        """
        Wait for a shutdown signal and then perform shutdown (asynchronous)
        
        Returns:
            True if shutdown completed successfully, False if timeout occurred
        """
        await self.wait_async()
        return await self.shutdown_async()
