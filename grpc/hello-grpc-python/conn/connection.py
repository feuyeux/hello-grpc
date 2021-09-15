# encoding: utf-8
import logging
import os

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


def build_channel(address):
    secure = os.getenv("GRPC_HELLO_SECURE")

    if secure == "Y":
        with open(certKey, 'rb') as f:
            private_key = f.read()
        with open(certChain, 'rb') as f:
            certificate_chain = f.read()
        with open(rootCert, 'rb') as f:
            root_certificates = f.read()
        credentials = grpc.ssl_channel_credentials(root_certificates, private_key, certificate_chain)
        options = (('grpc.ssl_target_name_override', serverName),)
        logger.info("Connect With TLS")
        return grpc.secure_channel(address, credentials, options)
    else:
        logger.info("Connect With InSecure")
        return grpc.insecure_channel(address)
