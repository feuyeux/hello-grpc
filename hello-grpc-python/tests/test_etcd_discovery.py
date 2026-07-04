import os
import unittest

from conn.etcd_discovery import (
    is_etcd_discovery,
    get_endpoint,
    b64,
    b64_decode,
    ETCD_KEY,
)


class TestEtcdDiscovery(unittest.TestCase):
    def setUp(self):
        os.environ.pop("GRPC_HELLO_DISCOVERY", None)
        os.environ.pop("GRPC_HELLO_DISCOVERY_ENDPOINT", None)

    def test_is_etcd_discovery_default(self):
        self.assertFalse(is_etcd_discovery())

    def test_is_etcd_discovery_true(self):
        os.environ["GRPC_HELLO_DISCOVERY"] = "etcd"
        self.assertTrue(is_etcd_discovery())

    def test_is_etcd_discovery_other(self):
        os.environ["GRPC_HELLO_DISCOVERY"] = "dns"
        self.assertFalse(is_etcd_discovery())

    def test_get_endpoint_default(self):
        self.assertEqual(get_endpoint(), "http://127.0.0.1:2379")

    def test_get_endpoint_custom(self):
        os.environ["GRPC_HELLO_DISCOVERY_ENDPOINT"] = "http://etcd:2379"
        self.assertEqual(get_endpoint(), "http://etcd:2379")

    def test_get_endpoint_prepends_scheme(self):
        os.environ["GRPC_HELLO_DISCOVERY_ENDPOINT"] = "etcd:2379"
        self.assertEqual(get_endpoint(), "http://etcd:2379")

    def test_b64_round_trip(self):
        original = "localhost:50051"
        encoded = b64(original)
        self.assertEqual(b64_decode(encoded), original)

    def test_etcd_key(self):
        self.assertEqual(ETCD_KEY, "/etcd/hello-grpc")


if __name__ == "__main__":
    unittest.main()
