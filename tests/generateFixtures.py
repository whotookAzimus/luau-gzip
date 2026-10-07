from pathlib import Path
import zlib, struct, random, json

GZIP_HEADER_SIZE = 10
GZIP_TRAILER_SIZE = 8
GZIP_SIZE_FIELD_SIZE = 4
GZIP_FLAGS_OFFSET = 3
GZIP_MAGIC = bytes([31, 139])
GZIP_DEFLATE_METHOD = 8
GZIP_EXTRA_FLAG = 4
GZIP_NAME_FLAG = 8
GZIP_COMMENT_FLAG = 16
GZIP_HEADER_CRC_FLAG = 2
GZIP_RESERVED_FLAGS = 224
GZIP_WINDOW_BITS = 31
DEFLATE_WINDOW_BITS = -15
DEFLATE_BLOCK_TYPE_SHIFT = 1
DEFLATE_BLOCK_TYPE_MASK = 3
DEFLATE_STORED_BLOCK = 0
DEFLATE_FIXED_BLOCK = 1
DEFLATE_DYNAMIC_BLOCK = 2
DEFLATE_RESERVED_FINAL_BLOCK = 7
UINT16_MASK = 65535
MAX_OUTPUT_SIZE = 256 * 1024 * 1024

root = Path(__file__).parent / "fixtures"
root.mkdir(exist_ok=True)
cases = []
def member(data, level=6, strategy=zlib.Z_DEFAULT_STRATEGY):
    encoder = zlib.compressobj(level, zlib.DEFLATED, DEFLATE_WINDOW_BITS, strategy=strategy)
    compressed = encoder.compress(data) + encoder.flush()
    return GZIP_MAGIC + bytes([GZIP_DEFLATE_METHOD, 0]) + bytes(GZIP_HEADER_SIZE - 4) + compressed + struct.pack("<II", zlib.crc32(data), len(data))
def add(name, content, expected=None):
    (root / (name + ".gz")).write_bytes(content)
    if expected is not None:
        (root / (name + ".expected")).write_bytes(expected)
    cases.append({"name": name, "valid": expected is not None})
data = b"gzip fixture: overlapping matches!\n" * 512
stored = member(data, 0)
fixed = member(data, 6, zlib.Z_FIXED)
dynamic = member(data, 6)
assert ((stored[GZIP_HEADER_SIZE] >> DEFLATE_BLOCK_TYPE_SHIFT) & DEFLATE_BLOCK_TYPE_MASK) == DEFLATE_STORED_BLOCK
assert ((fixed[GZIP_HEADER_SIZE] >> DEFLATE_BLOCK_TYPE_SHIFT) & DEFLATE_BLOCK_TYPE_MASK) == DEFLATE_FIXED_BLOCK
assert ((dynamic[GZIP_HEADER_SIZE] >> DEFLATE_BLOCK_TYPE_SHIFT) & DEFLATE_BLOCK_TYPE_MASK) == DEFLATE_DYNAMIC_BLOCK
for name, stream in [("stored", stored), ("fixed", fixed), ("dynamic", dynamic)]:
    assert zlib.decompress(stream, GZIP_WINDOW_BITS) == data
    add(name, stream, data)
add("empty", member(b""), b"")
add("binary", member(bytes(range(256)) * 4), bytes(range(256)) * 4)
rng = random.Random(42)
randomData = rng.randbytes(8192)
add("random", member(randomData), randomData)
largeData = bytes(range(256)) * 512
add("multi-block", member(largeData, 0), largeData)
optional = bytearray(dynamic[:GZIP_HEADER_SIZE]); optional[GZIP_FLAGS_OFFSET] = GZIP_EXTRA_FLAG | GZIP_NAME_FLAG | GZIP_COMMENT_FLAG
optional = bytes(optional) + struct.pack("<H", 3) + b"abc" + b"fixture.bin\x00" + b"comment\x00" + dynamic[GZIP_HEADER_SIZE:]
assert zlib.decompress(optional, GZIP_WINDOW_BITS) == data
add("optional-fields", optional, data)
headerCrc = bytearray(dynamic[:GZIP_HEADER_SIZE]); headerCrc[GZIP_FLAGS_OFFSET] = GZIP_HEADER_CRC_FLAG
headerCrc = bytes(headerCrc)
headerCrcStream = headerCrc + struct.pack("<H", zlib.crc32(headerCrc) & UINT16_MASK) + dynamic[GZIP_HEADER_SIZE:]
assert zlib.decompress(headerCrcStream, GZIP_WINDOW_BITS) == data
add("header-crc-field", headerCrcStream, data)
add("too-short", GZIP_MAGIC)
add("bad-magic", b"XX" + dynamic[2:])
add("bad-method", dynamic[:2] + b"\x00" + dynamic[3:])
add("reserved-flags", dynamic[:GZIP_FLAGS_OFFSET] + bytes([GZIP_RESERVED_FLAGS]) + dynamic[GZIP_FLAGS_OFFSET + 1:])
add("bad-payload-crc", dynamic[:-GZIP_TRAILER_SIZE] + bytes([dynamic[-GZIP_TRAILER_SIZE] ^ 1]) + dynamic[-GZIP_TRAILER_SIZE + 1:])
add("size-too-small", dynamic[:-GZIP_SIZE_FIELD_SIZE] + struct.pack("<I", len(data) - 1))
add("size-too-large", dynamic[:-GZIP_SIZE_FIELD_SIZE] + struct.pack("<I", len(data) + 1))
add("output-limit", dynamic[:-GZIP_SIZE_FIELD_SIZE] + struct.pack("<I", MAX_OUTPUT_SIZE + 1))
add("truncated-deflate", dynamic[:14] + dynamic[-GZIP_TRAILER_SIZE:])
add("unterminated-name", dynamic[:GZIP_FLAGS_OFFSET] + bytes([GZIP_NAME_FLAG]) + dynamic[GZIP_FLAGS_OFFSET + 1:GZIP_HEADER_SIZE] + b"filename" + dynamic[-GZIP_TRAILER_SIZE:])
add("overlapping-extra", dynamic[:GZIP_FLAGS_OFFSET] + bytes([GZIP_EXTRA_FLAG]) + dynamic[GZIP_FLAGS_OFFSET + 1:GZIP_HEADER_SIZE] + b"\xff\xff" + dynamic[GZIP_HEADER_SIZE:])
add("reserved-block", dynamic[:GZIP_HEADER_SIZE] + bytes([DEFLATE_RESERVED_FINAL_BLOCK]) + dynamic[-GZIP_TRAILER_SIZE:])
badStored = bytearray(stored); badStored[GZIP_HEADER_SIZE + 3] ^= 1
add("bad-stored-length", bytes(badStored))
add("concatenated-members", dynamic + dynamic)
add("trailing-deflate-bytes", dynamic[:-GZIP_TRAILER_SIZE] + b"junk" + dynamic[-GZIP_TRAILER_SIZE:])
oversubscribed = bytes.fromhex("1f8b080000000000000005c0010400000000900100000000000000000000000000000000000000000000000000000000000080010000000000000000")
try:
    zlib.decompress(oversubscribed, GZIP_WINDOW_BITS)
except zlib.error:
    pass
else:
    raise AssertionError("Independent decoder accepted malformed Huffman tree")
add("oversubscribed-tree", oversubscribed)
(root / "cases.json").write_text(json.dumps(cases, indent=2) + "\n")
