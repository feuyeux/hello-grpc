# encoding: utf-8
"""
Logging configuration for standardized logging setup.

Provides utilities to initialize logging with standard format:
[TIMESTAMP] [LEVEL] [COMPONENT] MESSAGE [CONTEXT]

Uses Python's standard logging module with dual output (console and file).
"""

import os
import sys
import logging
from datetime import datetime
from pathlib import Path


class StandardFormatter(logging.Formatter):
    """
    Custom formatter that implements the standard log format.
    Format: [TIMESTAMP] [LEVEL] [COMPONENT] MESSAGE [CONTEXT]
    """

    def __init__(self, component):
        """
        Initialize the formatter with component name.
        
        Args:
            component (str): The component name (e.g., "client", "server")
        """
        super().__init__()
        self.component = component

    def format(self, record):
        """
        Format the log record with standard format.
        
        Args:
            record (logging.LogRecord): The log record to format
            
        Returns:
            str: Formatted log message
        """
        # Format timestamp
        timestamp = datetime.fromtimestamp(record.created).strftime('%Y-%m-%d %H:%M:%S.%f')[:-3]
        
        # Get level name
        level = record.levelname
        
        # Get message
        message = record.getMessage()
        
        # Build context from extra fields
        context = ""
        if hasattr(record, 'context') and record.context:
            context_parts = [f"{k}={v}" for k, v in record.context.items()]
            context = " [" + ", ".join(context_parts) + "]"
        
        # Build log line
        log_line = f"[{timestamp}] [{level}] [{self.component}] {message}{context}"
        
        # Add exception info if present
        if record.exc_info:
            log_line += "\n" + self.formatException(record.exc_info)
        
        return log_line


class LoggingConfig:
    """
    Logging configuration helper for standardized logging setup.
    """

    DEFAULT_LOG_DIR = "logs"
    DEFAULT_LEVEL = logging.INFO

    @staticmethod
    def initialize_logging(component, log_dir=None, enable_file=True):
        """
        Initialize logging for a component with dual output (console and file).
        
        Args:
            component (str): The component name (e.g., "client", "server")
            log_dir (str): The directory for log files (default: "logs")
            enable_file (bool): Whether to enable file logging (default: True)
            
        Returns:
            logging.Logger: Logger instance for the component
        """
        if log_dir is None:
            log_dir = LoggingConfig.DEFAULT_LOG_DIR

        # Create log directory
        Path(log_dir).mkdir(parents=True, exist_ok=True)

        # Get log level
        level = LoggingConfig.get_log_level()

        # Create logger
        logger = logging.getLogger(component)
        logger.setLevel(level)
        logger.handlers.clear()  # Clear any existing handlers

        # Create formatter
        formatter = StandardFormatter(component)

        # Create console handler
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setLevel(level)
        console_handler.setFormatter(formatter)
        logger.addHandler(console_handler)

        # Create file handler if enabled
        if enable_file:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            log_file_name = f"{component}_{timestamp}.log"
            log_file_path = Path(log_dir) / log_file_name

            file_handler = logging.FileHandler(log_file_path, mode='a', encoding='utf-8')
            file_handler.setLevel(level)
            file_handler.setFormatter(formatter)
            logger.addHandler(file_handler)

            logger.info(f"Logging initialized for component: {component}")
            logger.info(f"Log file: {log_file_path}")
        else:
            logger.info(f"Logging initialized for component: {component} (console only)")

        return logger

    @staticmethod
    def get_log_level():
        """
        Get log level from environment variable or default to INFO.
        
        Returns:
            int: The log level constant
        """
        level_str = os.getenv("LOG_LEVEL", "INFO").upper()
        
        level_map = {
            "DEBUG": logging.DEBUG,
            "INFO": logging.INFO,
            "WARN": logging.WARNING,
            "WARNING": logging.WARNING,
            "ERROR": logging.ERROR,
            "FATAL": logging.CRITICAL,
            "CRITICAL": logging.CRITICAL,
        }
        
        return level_map.get(level_str, logging.INFO)


def initialize_logging(component, log_dir=None, enable_file=True):
    """
    Convenience function to initialize logging.
    
    Args:
        component (str): The component name (e.g., "client", "server")
        log_dir (str): The directory for log files (default: "logs")
        enable_file (bool): Whether to enable file logging (default: True)
        
    Returns:
        logging.Logger: Logger instance for the component
    """
    return LoggingConfig.initialize_logging(component, log_dir, enable_file)
