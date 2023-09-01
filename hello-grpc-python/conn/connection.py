# encoding: utf-8
import logging
import os
import sys

import grpc

cert = "/var/hello_grpc/client_certs/cert.pem"
certKey = "/var/hello_grpc/client_certs/private.key"
certChain = "/var/hello_grpc/client_certs/full_chain.pem"
rootCert = "/var/hello_grpc/client_certs/myssl_root.cer"
serverName = "hello.grpc.io"

logger = logging.getLogger('grpc-connection')
logger.setLevel(logging.INFO)
console = logging.StreamHandler()
console.setLevel(logging.INFO)
formatter = logging.Formatter('%(asctime)s [%(levelname)s] - %(message)s')
console.setFormatter(formatter)
logger.addHandler(console)


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
        credentials = grpc.ssl_channel_credentials(certificate_chain, private_key, certificate_chain)
        options = (('grpc.ssl_target_name_override', serverName), ('grpc.default_authority', serverName))
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
