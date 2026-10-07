export type DecompressResult =
	{
		success: true,
		value: string,
	}
	| {
		success: false,
		error: string,
	}

type BitReader = {
	source: string,
	offset: number,
	limit: number,
	bitBuffer: number,
	bitCount: number,
}

type HuffmanTree = {
	codesByLength: { { [number]: number } },
	maxLength: number,
}

const BITS_PER_BYTE = 8
const BYTE_MASK = 0xFF
const UINT16_MASK = 0xFFFF
const UINT32_MASK = 0xFFFFFFFF

const CRC32_POLYNOMIAL = 0xEDB88320

const DEFLATE_STORED_BLOCK_TYPE = 0
const DEFLATE_FIXED_BLOCK_TYPE = 1
const DEFLATE_DYNAMIC_BLOCK_TYPE = 2
const DEFLATE_END_OF_BLOCK_SYMBOL = 256
const DEFLATE_FIRST_LENGTH_SYMBOL = 257
const DEFLATE_LAST_LENGTH_SYMBOL = 285
const DEFLATE_LAST_DISTANCE_SYMBOL = 29
const DEFLATE_LAST_LITERAL_CODE_LENGTH_SYMBOL = 15

const DEFLATE_REPEAT_PREVIOUS_SYMBOL = 16
const DEFLATE_REPEAT_ZERO_SHORT_SYMBOL = 17
const DEFLATE_REPEAT_ZERO_LONG_SYMBOL = 18
const DEFLATE_REPEAT_PREVIOUS_BITS = 2
const DEFLATE_REPEAT_ZERO_SHORT_BITS = 3
const DEFLATE_REPEAT_ZERO_LONG_BITS = 7
const DEFLATE_REPEAT_PREVIOUS_BASE = 3
const DEFLATE_REPEAT_ZERO_SHORT_BASE = 3
const DEFLATE_REPEAT_ZERO_LONG_BASE = 11

const DEFLATE_DYNAMIC_LITERAL_COUNT_BITS = 5
const DEFLATE_DYNAMIC_DISTANCE_COUNT_BITS = 5
const DEFLATE_DYNAMIC_CODE_LENGTH_COUNT_BITS = 4
const DEFLATE_DYNAMIC_LITERAL_COUNT_BASE = 257
const DEFLATE_DYNAMIC_DISTANCE_COUNT_BASE = 1
const DEFLATE_DYNAMIC_CODE_LENGTH_COUNT_BASE = 4
const DEFLATE_CODE_LENGTH_ALPHABET_SIZE = 19
const DEFLATE_CODE_LENGTH_BITS = 3

const DEFLATE_FIXED_LITERAL_LAST_SYMBOL = 287
const DEFLATE_FIXED_DISTANCE_LAST_SYMBOL = 31
const DEFLATE_FIXED_LITERAL_FIRST_BAND_END = 143
const DEFLATE_FIXED_LITERAL_SECOND_BAND_END = 255
const DEFLATE_FIXED_LITERAL_THIRD_BAND_END = 279
const DEFLATE_FIXED_LITERAL_FIRST_BAND_BITS = 8
const DEFLATE_FIXED_LITERAL_SECOND_BAND_BITS = 9
const DEFLATE_FIXED_LITERAL_THIRD_BAND_BITS = 7
const DEFLATE_FIXED_LITERAL_FOURTH_BAND_BITS = 8
const DEFLATE_FIXED_DISTANCE_BITS = 5

const GZIP_HEADER_SIZE = 10
const GZIP_TRAILER_SIZE = 8
const GZIP_MINIMUM_SIZE = GZIP_HEADER_SIZE + GZIP_TRAILER_SIZE
const GZIP_MAGIC_FIRST_BYTE = 0x1F
const GZIP_MAGIC_SECOND_BYTE = 0x8B
const GZIP_DEFLATE_COMPRESSION_METHOD = 8
const GZIP_RESERVED_FLAGS_MASK = 0xE0
const GZIP_EXTRA_FLAG = 0x04
const GZIP_NAME_FLAG = 0x08
const GZIP_COMMENT_FLAG = 0x10
const GZIP_HEADER_CRC_FLAG = 0x02
const GZIP_EXTRA_LENGTH_SIZE = 2
const GZIP_HEADER_CRC_SIZE = 2

const MAX_OUTPUT_SIZE = 256 * 1024 * 1024

const LENGTH_BASES = {
	3,
	4,
	5,
	6,
	7,
	8,
	9,
	10,
	11,
	13,
	15,
	17,
	19,
	23,
	27,
	31,
	35,
	43,
	51,
	59,
	67,
	83,
	99,
	115,
	131,
	163,
	195,
	227,
	258,
}

const LENGTH_EXTRA_BITS = {
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	1,
	1,
	1,
	1,
	2,
	2,
	2,
	2,
	3,
	3,
	3,
	3,
	4,
	4,
	4,
	4,
	5,
	5,
	5,
	5,
	0,
}

const DISTANCE_BASES = {
	1,
	2,
	3,
	4,
	5,
	7,
	9,
	13,
	17,
	25,
	33,
	49,
	65,
	97,
	129,
	193,
	257,
	385,
	513,
	769,
	1025,
	1537,
	2049,
	3073,
	4097,
	6145,
	8193,
	12289,
	16385,
	24577,
}

const DISTANCE_EXTRA_BITS = {
	0,
	0,
	0,
	0,
	1,
	1,
	2,
	2,
	3,
	3,
	4,
	4,
	5,
	5,
	6,
	6,
	7,
	7,
	8,
	8,
	9,
	9,
	10,
	10,
	11,
	11,
	12,
	12,
	13,
	13,
}

const CODE_LENGTH_ORDER = {
	16,
	17,
	18,
	0,
	8,
	7,
	9,
	6,
	10,
	5,
	11,
	4,
	12,
	3,
	13,
	2,
	14,
	1,
	15,
}

const CRC32_TABLE = {}

for value = 0, BYTE_MASK do
	local checksum = value

	for _ = 1, BITS_PER_BYTE do
		checksum = if bit32.band(checksum, 1) == 1
			then bit32.bxor(bit32.rshift(checksum, 1), CRC32_POLYNOMIAL)
			else bit32.rshift(checksum, 1)
	end

	CRC32_TABLE[value + 1] = checksum
end

const gzip = {}

const function readLittleEndian16(source: string, offset: number): number
	const firstByte, secondByte = source:byte(offset, offset + 1)

	if not firstByte or not secondByte then
		error("Unexpected end of gzip data")
	end

	return firstByte + secondByte * 0x100
end

const function readLittleEndian32(source: string, offset: number): number
	const firstByte, secondByte, thirdByte, fourthByte = source:byte(offset, offset + 3)

	if not firstByte or not secondByte or not thirdByte or not fourthByte then
		error("Unexpected end of gzip data")
	end

	return firstByte + secondByte * 0x100 + thirdByte * 0x10000 + fourthByte * 0x1000000
end

const function readBits(reader: BitReader, count: number): number
	while reader.bitCount < count do
		if reader.offset > reader.limit then
			error("Unexpected end of DEFLATE data")
		end

		const nextByte = string.byte(reader.source, reader.offset)

		if not nextByte then
			error("Unexpected end of DEFLATE data")
		end

		reader.bitBuffer += nextByte * (2 ^ reader.bitCount)
		reader.bitCount += BITS_PER_BYTE
		reader.offset += 1
	end

	const divisor = 2 ^ count
	const value = reader.bitBuffer % divisor

	reader.bitBuffer = math.floor(reader.bitBuffer / divisor)
	reader.bitCount -= count

	return value
end

const function alignToByte(reader: BitReader)
	reader.bitBuffer = 0
	reader.bitCount = 0
end

const function reverseBits(value: number, count: number): number
	local reversed = 0

	for _ = 1, count do
		reversed = bit32.bor(bit32.lshift(reversed, 1), bit32.band(value, 1))
		value = bit32.rshift(value, 1)
	end

	return reversed
end

const function buildHuffmanTree(lengths: { number }): HuffmanTree
	const countsByLength: { [number]: number } = {}
	local maxLength = 0

	for _, length in lengths do
		if length > 0 then
			countsByLength[length] = (countsByLength[length] or 0) + 1
			maxLength = math.max(maxLength, length)
		end
	end

	const nextCodeByLength: { [number]: number } = {}
	local nextCode = 0

	for length = 1, maxLength do
		nextCode = (nextCode + (countsByLength[length - 1] or 0)) * 2
		if nextCode + (countsByLength[length] or 0) > 2 ^ length then
			error("Oversubscribed DEFLATE Huffman tree")
		end
		nextCodeByLength[length] = nextCode
	end

	const codesByLength: { { [number]: number } } = {}

	for length = 1, maxLength do
		codesByLength[length] = {}
	end

	for index, length in lengths do
		if length == 0 then
			continue
		end

		const canonicalCode = nextCodeByLength[length]

		nextCodeByLength[length] += 1
		codesByLength[length][reverseBits(canonicalCode, length)] = index - 1
	end

	return {
		codesByLength = codesByLength,
		maxLength = maxLength,
	}
end

const function decodeSymbol(reader: BitReader, tree: HuffmanTree): number
	local code = 0

	for length = 1, tree.maxLength do
		code = bit32.bor(code, bit32.lshift(readBits(reader, 1), length - 1))

		const symbol = tree.codesByLength[length][code]

		if symbol then
			return symbol
		end
	end

	error("Invalid DEFLATE Huffman code")
end

const function buildFixedTrees(): (HuffmanTree, HuffmanTree)
	const literalLengths = {}

	for symbol = 0, DEFLATE_FIXED_LITERAL_LAST_SYMBOL do
		literalLengths[symbol + 1] = if symbol <= DEFLATE_FIXED_LITERAL_FIRST_BAND_END
			then DEFLATE_FIXED_LITERAL_FIRST_BAND_BITS
			elseif symbol <= DEFLATE_FIXED_LITERAL_SECOND_BAND_END then DEFLATE_FIXED_LITERAL_SECOND_BAND_BITS
			elseif symbol <= DEFLATE_FIXED_LITERAL_THIRD_BAND_END then DEFLATE_FIXED_LITERAL_THIRD_BAND_BITS
			else DEFLATE_FIXED_LITERAL_FOURTH_BAND_BITS
	end

	const distanceLengths = {}

	for symbol = 0, DEFLATE_FIXED_DISTANCE_LAST_SYMBOL do
		distanceLengths[symbol + 1] = DEFLATE_FIXED_DISTANCE_BITS
	end

	return buildHuffmanTree(literalLengths), buildHuffmanTree(distanceLengths)
end

const FIXED_LITERAL_TREE, FIXED_DISTANCE_TREE = buildFixedTrees()

const function buildDynamicTrees(reader: BitReader): (HuffmanTree, HuffmanTree)
	const literalCount = readBits(reader, DEFLATE_DYNAMIC_LITERAL_COUNT_BITS) + DEFLATE_DYNAMIC_LITERAL_COUNT_BASE
	const distanceCount = readBits(reader, DEFLATE_DYNAMIC_DISTANCE_COUNT_BITS) + DEFLATE_DYNAMIC_DISTANCE_COUNT_BASE
	const codeLengthCount = readBits(reader, DEFLATE_DYNAMIC_CODE_LENGTH_COUNT_BITS)
		+ DEFLATE_DYNAMIC_CODE_LENGTH_COUNT_BASE
	const codeLengthLengths = table.create(DEFLATE_CODE_LENGTH_ALPHABET_SIZE, 0)

	for index = 1, codeLengthCount do
		codeLengthLengths[CODE_LENGTH_ORDER[index] + 1] = readBits(reader, DEFLATE_CODE_LENGTH_BITS)
	end

	const codeLengthTree = buildHuffmanTree(codeLengthLengths)
	const lengths: { number } = {}
	const totalLengthCount = literalCount + distanceCount

	while #lengths < totalLengthCount do
		const symbol = decodeSymbol(reader, codeLengthTree)

		if symbol <= DEFLATE_LAST_LITERAL_CODE_LENGTH_SYMBOL then
			table.insert(lengths, symbol)
		elseif symbol == DEFLATE_REPEAT_PREVIOUS_SYMBOL then
			const previousLength = lengths[#lengths]

			if previousLength == nil then
				error("DEFLATE repeat code has no previous length")
			end

			const repeatCount = readBits(reader, DEFLATE_REPEAT_PREVIOUS_BITS) + DEFLATE_REPEAT_PREVIOUS_BASE

			for _ = 1, repeatCount do
				table.insert(lengths, previousLength)
			end
		elseif symbol == DEFLATE_REPEAT_ZERO_SHORT_SYMBOL then
			const repeatCount = readBits(reader, DEFLATE_REPEAT_ZERO_SHORT_BITS) + DEFLATE_REPEAT_ZERO_SHORT_BASE

			for _ = 1, repeatCount do
				table.insert(lengths, 0)
			end
		elseif symbol == DEFLATE_REPEAT_ZERO_LONG_SYMBOL then
			const repeatCount = readBits(reader, DEFLATE_REPEAT_ZERO_LONG_BITS) + DEFLATE_REPEAT_ZERO_LONG_BASE

			for _ = 1, repeatCount do
				table.insert(lengths, 0)
			end
		else
			error("Invalid DEFLATE code-length symbol")
		end

		if #lengths > totalLengthCount then
			error("DEFLATE code lengths exceed the declared count")
		end
	end

	const literalLengths: { number } = {}
	const distanceLengths: { number } = {}

	for index = 1, literalCount do
		literalLengths[index] = lengths[index]
	end

	for index = 1, distanceCount do
		distanceLengths[index] = lengths[literalCount + index]
	end

	if literalLengths[DEFLATE_END_OF_BLOCK_SYMBOL + 1] == 0 then
		error("DEFLATE literal tree does not contain an end-of-block code")
	end

	return buildHuffmanTree(literalLengths), buildHuffmanTree(distanceLengths)
end

const function decodeStoredBlock(reader: BitReader, output: buffer, outputOffset: number): number
	alignToByte(reader)

	if reader.offset + 3 > reader.limit then
		error("Unexpected end of stored DEFLATE block")
	end

	const length = readLittleEndian16(reader.source, reader.offset)
	const complement = readLittleEndian16(reader.source, reader.offset + 2)

	reader.offset += 4

	if bit32.band(bit32.bnot(length), UINT16_MASK) ~= complement then
		error("Invalid stored DEFLATE block length")
	end

	if reader.offset + length - 1 > reader.limit then
		error("Stored DEFLATE block exceeds the input")
	end

	if outputOffset + length > buffer.len(output) then
		error("DEFLATE output exceeds the gzip size")
	end

	buffer.writestring(output, outputOffset, reader.source:sub(reader.offset, reader.offset + length - 1))
	reader.offset += length

	return outputOffset + length
end

const function decodeCompressedBlock(
	reader: BitReader,
	output: buffer,
	outputOffset: number,
	literalTree: HuffmanTree,
	distanceTree: HuffmanTree
): number
	while true do
		const symbol = decodeSymbol(reader, literalTree)

		if symbol < DEFLATE_END_OF_BLOCK_SYMBOL then
			if outputOffset >= buffer.len(output) then
				error("DEFLATE output exceeds the gzip size")
			end

			buffer.writeu8(output, outputOffset, symbol)
			outputOffset += 1
			continue
		end

		if symbol == DEFLATE_END_OF_BLOCK_SYMBOL then
			return outputOffset
		end

		if symbol < DEFLATE_FIRST_LENGTH_SYMBOL or symbol > DEFLATE_LAST_LENGTH_SYMBOL then
			error("Invalid DEFLATE length symbol")
		end

		const lengthIndex = symbol - DEFLATE_END_OF_BLOCK_SYMBOL
		const length = LENGTH_BASES[lengthIndex] + readBits(reader, LENGTH_EXTRA_BITS[lengthIndex])
		const distanceSymbol = decodeSymbol(reader, distanceTree)

		if distanceSymbol > DEFLATE_LAST_DISTANCE_SYMBOL then
			error("Invalid DEFLATE distance symbol")
		end

		const distanceIndex = distanceSymbol + 1
		const distance = DISTANCE_BASES[distanceIndex] + readBits(reader, DISTANCE_EXTRA_BITS[distanceIndex])

		if distance > outputOffset then
			error("DEFLATE distance exceeds the available output")
		end

		if outputOffset + length > buffer.len(output) then
			error("DEFLATE output exceeds the gzip size")
		end

		for _ = 1, length do
			const value = buffer.readu8(output, outputOffset - distance)

			buffer.writeu8(output, outputOffset, value)
			outputOffset += 1
		end
	end
end

const function inflate(source: string, startOffset: number, endOffset: number, outputSize: number): buffer
	const reader: BitReader = {
		source = source,
		offset = startOffset,
		limit = endOffset,
		bitBuffer = 0,
		bitCount = 0,
	}
	const output = buffer.create(outputSize)
	local outputOffset = 0
	local isFinalBlock = false

	while not isFinalBlock do
		isFinalBlock = readBits(reader, 1) == 1

		const blockType = readBits(reader, 2)

		if blockType == DEFLATE_STORED_BLOCK_TYPE then
			outputOffset = decodeStoredBlock(reader, output, outputOffset)
		elseif blockType == DEFLATE_FIXED_BLOCK_TYPE then
			outputOffset = decodeCompressedBlock(reader, output, outputOffset, FIXED_LITERAL_TREE, FIXED_DISTANCE_TREE)
		elseif blockType == DEFLATE_DYNAMIC_BLOCK_TYPE then
			const literalTree, distanceTree = buildDynamicTrees(reader)

			outputOffset = decodeCompressedBlock(reader, output, outputOffset, literalTree, distanceTree)
		else
			error("Reserved DEFLATE block type")
		end
	end

	if reader.offset ~= endOffset + 1 then
		error("Unexpected data after the final DEFLATE block")
	end

	if outputOffset ~= outputSize then
		error(`Gzip size mismatch: expected {outputSize}, decoded {outputOffset}`)
	end

	return output
end

const function calculateCrc32(data: buffer): number
	local checksum = UINT32_MASK

	for offset = 0, buffer.len(data) - 1 do
		const tableIndex = bit32.band(bit32.bxor(checksum, buffer.readu8(data, offset)), BYTE_MASK) + 1

		checksum = bit32.bxor(bit32.rshift(checksum, BITS_PER_BYTE), CRC32_TABLE[tableIndex])
	end

	return bit32.bxor(checksum, UINT32_MASK)
end

const function skipNullTerminatedField(source: string, offset: number, limit: number): number
	const terminator = source:find("\0", offset, true)

	if not terminator or terminator > limit then
		error("Unterminated gzip header field")
	end

	return terminator + 1
end

const function decompress(source: string): string
	if #source < GZIP_MINIMUM_SIZE then
		error("Gzip data is too short")
	end

	const firstMagicByte, secondMagicByte, compressionMethod, flags = source:byte(1, 4)

	if firstMagicByte ~= GZIP_MAGIC_FIRST_BYTE or secondMagicByte ~= GZIP_MAGIC_SECOND_BYTE then
		error("Invalid gzip header")
	end

	if compressionMethod ~= GZIP_DEFLATE_COMPRESSION_METHOD then
		error("Unsupported gzip compression method")
	end

	if bit32.band(flags, GZIP_RESERVED_FLAGS_MASK) ~= 0 then
		error("Gzip header uses reserved flags")
	end

	const trailerOffset = #source - GZIP_TRAILER_SIZE + 1
	local offset = GZIP_HEADER_SIZE + 1

	if bit32.band(flags, GZIP_EXTRA_FLAG) ~= 0 then
		const extraLength = readLittleEndian16(source, offset)

		offset += GZIP_EXTRA_LENGTH_SIZE + extraLength
	end

	if bit32.band(flags, GZIP_NAME_FLAG) ~= 0 then
		offset = skipNullTerminatedField(source, offset, trailerOffset - 1)
	end

	if bit32.band(flags, GZIP_COMMENT_FLAG) ~= 0 then
		offset = skipNullTerminatedField(source, offset, trailerOffset - 1)
	end

	if bit32.band(flags, GZIP_HEADER_CRC_FLAG) ~= 0 then
		offset += GZIP_HEADER_CRC_SIZE
	end

	if offset > trailerOffset then
		error("Gzip header overlaps the trailer")
	end

	const expectedChecksum = readLittleEndian32(source, trailerOffset)
	const outputSize = readLittleEndian32(source, trailerOffset + 4)

	if outputSize > MAX_OUTPUT_SIZE then
		error(`Gzip output exceeds the {MAX_OUTPUT_SIZE}-byte safety limit`)
	end

	const output = inflate(source, offset, trailerOffset - 1, outputSize)
	const actualChecksum = calculateCrc32(output)

	if actualChecksum ~= expectedChecksum then
		error("Gzip checksum mismatch")
	end

	return buffer.tostring(output)
end

function gzip.isContent(source: string): boolean
	return source:byte(1) == GZIP_MAGIC_FIRST_BYTE and source:byte(2) == GZIP_MAGIC_SECOND_BYTE
end

function gzip.decompress(source: string): DecompressResult
	const success, result = pcall(decompress, source)

	if not success then
		return {
			success = false,
			error = tostring(result),
		}
	end

	return {
		success = true,
		value = result,
	}
end

return gzip
