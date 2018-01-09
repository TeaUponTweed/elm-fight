import unittest

from pushfight import *


class TestPushfight(unittest.TestCase):
    def test_gen_cardinal_dirs(self):
        self.assertEqual(list(gen_cardinal_dirs()), [(-1, 0), (1, 0), (0, -1), (0, 1)])


if __name__ == '__main__':
    unittest.main()
