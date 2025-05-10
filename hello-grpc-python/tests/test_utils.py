import unittest
import grpc

from conn.utils import random_ids, get_version


class TestUtils(unittest.TestCase):
    def test_random_ids(self):
        ids = random_ids(5, 3)
        print(ids)
    
    def test_get_version(self):
        """Test that the get_version function returns the correct format with actual gRPC version"""
        version = get_version()
        
        # 打印 get_version() 的返回值
        print(f"get_version() result: {version}")
        
        # Check format
        self.assertTrue(version.startswith("grpc.version="))
        
        # Check that version matches actual grpc.__version__
        self.assertEqual(version, f"grpc.version={grpc.__version__}")
        
        # Check that it's not empty
        self.assertGreater(len(version), 13)  # "grpc.version=" is 13 chars


if __name__ == '__main__':
    unittest.main()
