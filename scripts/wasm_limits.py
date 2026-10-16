"""Set a WebAssembly 1.0 defined memory maximum; preserve other sections verbatim."""
def read_leb(data, offset):
    value = 0
    for shift in range(0,35,7):
        if offset >= len(data): raise ValueError('Truncated LEB128')
        byte = data[offset]; offset += 1; value |= (byte & 127) << shift
        if byte < 128 and value <= 0xffffffff: return value, offset
    raise ValueError('Invalid u32 LEB128')

def leb(value):
    result = bytearray()
    while True:
        byte = value & 127; value >>= 7
        result.append(byte | (128 if value else 0))
        if not value: return bytes(result)

def cap_memory(data, pages=4096):
    if data[:8] != b'\0asm\x01\0\0\0': raise ValueError('Unsupported WebAssembly header')
    output = bytearray(data[:8]); offset = 8; found = False
    while offset < len(data):
        start = offset; section = data[offset]; size, offset = read_leb(data,offset+1)
        end = offset + size
        if end > len(data): raise ValueError('Truncated WebAssembly section')
        if section == 5:
            if found: raise ValueError('Duplicate memory section')
            found = True
            count, cursor = read_leb(data,offset)
            flags, cursor = read_leb(data,cursor)
            minimum, cursor = read_leb(data,cursor)
            if count != 1 or flags not in (0,1): raise ValueError('Unsupported memory layout')
            maximum = pages
            if flags == 1:
                old_maximum,cursor = read_leb(data,cursor); maximum = min(maximum,old_maximum)
            if cursor != end or minimum > maximum: raise ValueError('Invalid memory limits')
            payload = leb(1)+leb(1)+leb(minimum)+leb(maximum)
            output.extend(bytes([5])+leb(len(payload))+payload)
        else: output.extend(data[start:end])
        offset = end
    if not found: raise ValueError('Defined memory missing')
    return bytes(output)
