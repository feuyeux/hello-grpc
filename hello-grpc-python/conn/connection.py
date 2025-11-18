# encoding: utf-8
"""
Connection management for gRPC client.

This module provides functions for:
- Building gRPC channels (secure and insecure)
- Managing TLS certificates
- Configuring logging
"""

import logging
import os
import sys
from logging.handlers import RotatingFileHandler
import platform
import pathlib
import grpc


def get_cert_base_path():
    """
    Get the base path for client certificates.
    
    Uses environment variable CERT_BASE_PATH if set, otherwise
    determines appropriate path based on operating system.
    
    Returns:
        str: Path to certificate directory
    """
    # Check for environment variable override
    base_path = os.getenv("CERT_BASE_PATH")
    if base_path:
        return base_path

    # Use platform-specific paths
    system = platform.system()
    if system == "Windows":
        return "C:\\hello_grpc\\client_certs"
    elif system == "Darwin":  # macOS
        return "/var/hello_grpc/client_certs"
    else:  # Linux or other Unix
        return "/var/hello_grpc/client_certs"


# Build platform-specific certificate paths
cert_base_path = get_cert_base_path()
cert = os.path.join(cert_base_path, "cert.pem")
cert_key = os.path.join(cert_base_path, "private.key")
cert_chain = os.path.join(cert_base_path, "full_chain.pem")
root_cert = os.path.join(cert_base_path, "myssl_root.cer")

server_name = "hello.grpc.io"

# Ensure log directory exists
os.makedirs("log", exist_ok=True)

# Create logger
logger = logging.getLogger('grpc-connection')
logger.setLevel(logging.INFO)

# Console handler
console = logging.StreamHandler(sys.stdout)
console.setLevel(logging.INFO)
console_formatter = logging.Formatter(
    '[%(asctime)s] [%(levelname)s] [%(name)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S')
console.setFormatter(console_formatter)

# File handler
file_handler = RotatingFileHandler(
    'log/hello-grpc.log', maxBytes=19500*1024, backupCount=5)
file_handler.setLevel(logging.INFO)
file_formatter = logging.Formatter(
    '[%(asctime)s] [%(threadName)s] [%(levelname)s] [%(name)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S.%f')
file_handler.setFormatter(file_formatter)

# Add handlers
logger.addHandler(console)
logger.addHandler(file_handler)

# Log certificate paths for debugging
logger.info(
    "Using certificate paths: cert=%s, cert_key=%s, cert_chain=%s, root_cert=%s",
    cert, cert_key, cert_chain, root_cert)


def get_grpc_server():
    """
    Get the gRPC server hostname from environment or use default.
    
    Returns:
        str: Server hostname
    """
    server = os.getenv("GRPC_SERVER")
    if server:
        return server
    else:
        return "localhost"


def build_channel():
    """
    Build a gRPC channel (secure or insecure based on configuration).
    
    The channel configuration is determined by environment variables:
    - GRPC_HELLO_BACKEND: Backend server hostname
    - GRPC_HELLO_BACKEND_PORT: Backend server port
    - GRPC_SERVER_PORT: Server port (default: 9996)
    - GRPC_HELLO_SECURE: Use TLS if set to 'Y'
    
    Returns:
        grpc.Channel: Configured gRPC channel
    """
    # Determine server address
    backend = os.getenv("GRPC_HELLO_BACKEND")
    if backend:
        connect_to = backend
    else:
        connect_to = get_grpc_server()
    
    # Determine port
    back_port = os.getenv("GRPC_HELLO_BACKEND_PORT")
    if back_port:
        port = back_port
    else:
        server_port = os.getenv("GRPC_SERVER_PORT")
        if server_port:
            port = server_port
        else:
            port = "9996"
    
    address = f"{connect_to}:{port}"
    
    # Check if TLS is enabled
    secure = os.getenv("GRPC_HELLO_SECURE")
    python_version = sys.version_info
    
    if secure == "Y":
        # Build secure channel with TLS
        try:
            # Read root certificate for server verification
            with open(root_cert, 'rb') as f:
                root_certificates = f.read()
            
            logger.info("Loaded root certificate from: %s", root_cert)
            logger.info("Using server-only TLS (no client certificate)")
            
            # Create TLS credentials without client certificates
            credentials = grpc.ssl_channel_credentials(
                root_certificates=root_certificates,
                private_key=None,
                certificate_chain=None
            )
            
            options = (
                ('grpc.ssl_target_name_override', server_name),
                ('grpc.default_authority', server_name)
            )
            
            logger.info("TLS connection configured with server name: %s", server_name)
            logger.info("Connect with TLS to %s (Python %s.%s.%s)", 
                       address, python_version[0], python_version[1], python_version[2])
            return grpc.secure_channel(address, credentials, options)
            
        except (FileNotFoundError, PermissionError) as e:
            logger.error("TLS certificate error: %s", e)
            logger.warning("Falling back to insecure connection")
            logger.info("Connect with insecure to %s (Python %s.%s.%s)", 
                       address, python_version[0], python_version[1], python_version[2])
            return grpc.insecure_channel(address)
    else:
        # Build insecure channel
        logger.info("Connect with insecure (:%s) (Python %s.%s.%s)", 
                   port, python_version[0], python_version[1], python_version[2])
        return grpc.insecure_channel(address)
