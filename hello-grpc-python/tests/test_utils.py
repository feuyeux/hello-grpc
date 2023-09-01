import unittest

from conn.utils import random_ids


class TestUtils(unittest.TestCase):
    def test_random_ids(self):
        ids = random_ids(5, 3)
        print(ids)


if __name__ == '__main__':
    unittest.main()
