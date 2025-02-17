import unittest
from app import add_numbers

class TestAddNumbers(unittest.TestCase):
    def test_positive_numbers(self):
        self.assertEqual(add_numbers(3, 5), 8)

    def test_negative_numbers(self):
        self.assertEqual(add_numbers(-3, -5), -8)

    def test_mixed_numbers(self):
        self.assertEqual(add_numbers(3, -5), -2)

if __name__ == "__main__":
    unittest.main()
