import unittest
from wasm_limits import cap_memory
HEADER=b'\0asm\x01\0\0\0'
class MemoryLimitsTests(unittest.TestCase):
    def test_add_maximum(self):
        self.assertEqual(cap_memory(HEADER+b'\x05\x03\x01\x00\x2d'),HEADER+b'\x05\x05\x01\x01\x2d\x80\x20')
    def test_preserve_lower_maximum(self):
        module=HEADER+b'\x05\x04\x01\x01\x01\x02'
        self.assertEqual(cap_memory(module),module)
    def test_reject_unsupported(self):
        for module in [b'', HEADER, HEADER+b'\x05\xff', HEADER+b'\x05\x03\x01\x03\x01']:
            with self.assertRaises(ValueError): cap_memory(module)
if __name__=='__main__': unittest.main()
