# luau-gzip

A standalone Luau gzip decompressor, extracted from Etherseal tooling.
No Roblox services, native extensions, or third-party runtime dependencies.

## API

```luau
const gzip = require("./src")
const result = gzip.decompress(compressedBytes)
if result.success then
    print(result.value)
else
    warn(result.error)
end
```

`decompress(source: string)` returns `{ success: true, value: string }` or
`{ success: false, error: string }`. It checks the payload CRC32 and decoded
size and rejects declared output larger than 256 MiB before allocation.
Malformed data is reported through the failure result.

`isContent(source: string): boolean` checks the first two gzip magic bytes.
It identifies a potential gzip stream; it does not validate the stream.

## Supported format

Single gzip members containing stored, fixed-Huffman, or dynamic-Huffman
DEFLATE blocks. Optional extra, filename, and comment fields are accepted.
The optional header CRC16 field is skipped without verification.
Concatenated gzip members are unsupported. Compression is not provided.

## Development

Tools are pinned in `rokit.toml`.

```sh
lute run scripts/check
```

Fixtures were generated independently with Python zlib. The fixture generator
is included for reproducibility; running tests does not require Python.

This repository is private and has no license granting redistribution rights.
