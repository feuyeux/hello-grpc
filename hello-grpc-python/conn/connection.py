# encoding: utf-8
import logging
import os
import sys
from logging.handlers import RotatingFileHandler
import platform
import pathlib
import grpc


def get_cert_base_path():
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
certKey = os.path.join(cert_base_path, "private.key")
certChain = os.path.join(cert_base_path, "full_chain.pem")
rootCert = os.path.join(cert_base_path, "myssl_root.cer")

serverName = "hello.grpc.io"

# Ensure log directory exists
os.makedirs("log", exist_ok=True)

# Create logger
logger = logging.getLogger('grpc-connection')
logger.setLevel(logging.INFO)

# Console handler
console = logging.StreamHandler(sys.stdout)
console.setLevel(logging.INFO)
console_formatter = logging.Formatter(
    '%(asctime)s %(message)s', '%H:%M:%S')
console.setFormatter(console_formatter)

# File handler
file_handler = RotatingFileHandler(
    'log/hello-grpc.log', maxBytes=19500*1024, backupCount=5)
file_handler.setLevel(logging.INFO)
file_formatter = logging.Formatter(
    '%(asctime)s [%(threadName)s] %(levelname)-5s %(name)s - %(message)s')
file_handler.setFormatter(file_formatter)

# Add handlers
logger.addHandler(console)
logger.addHandler(file_handler)

# Log certificate paths for debugging
logger.info(
    f"Using certificate paths: cert={cert}, certKey={certKey}, certChain={certChain}, rootCert={rootCert}")


def build_channel():
    backend = os.getenv("GRPC_HELLO_BACKEND")
    if backend:
        connect_to = backend
    else:
        connect_to = grpc_server()
    back_port = os.getenv("GRPC_HELLO_BACKEND_PORT")
    if back_port:
        port = back_port
    else:
        server_port = os.getenv("GRPC_SERVER_PORT")
        if server_port:
            port = server_port
        else:
            port = "9996"
    address = connect_to + ":" + port

    secure = os.getenv("GRPC_HELLO_SECURE")
    python_version = sys.version_info
    if secure == "Y":
        with open(certKey, 'rb') as f:
            private_key = f.read()
        with open(certChain, 'rb') as f:
            certificate_chain = f.read()
        with open(rootCert, 'rb') as f:
            root_certificates = f.read()
        credentials = grpc.ssl_channel_credentials(
            certificate_chain, private_key, certificate_chain)
        options = (('grpc.ssl_target_name_override', serverName),
                   ('grpc.default_authority', serverName))
        logger.info("Connect With TLS(:%s) (version:%s.%s.%s)", port, python_version[0], python_version[1],
                    python_version[2])
        return grpc.secure_channel(address, credentials, options)
    else:
        logger.info("Connect with InSecure(:%s) (version:%s.%s.%s)", port, python_version[0], python_version[1],
                    python_version[2])
        return grpc.insecure_channel(address)


def grpc_server():
    server = os.getenv("GRPC_SERVER")
    if server:
        return server
    else:
        return "localhost"
