const fs = require("@std/fs")
const json = require("@std/json")
const gzip = require("../src")

const GZIP_MAGIC_FIRST_BYTE = 31
const GZIP_MAGIC_SECOND_BYTE = 139
const FIXTURE_ROOT = "tests/fixtures"
const cases = assert(json.asArray(json.deserialize(fs.readFileToString(`{FIXTURE_ROOT}/cases.json`))))
local passedCount = 0

for _, value in cases do
	const case = assert(json.asObject(value))
	const name = case.name
	const valid = case.valid
	assert(type(name) == "string" and type(valid) == "boolean")

	const compressed = fs.readFileToString(`{FIXTURE_ROOT}/{name}.gz`)
	const result = gzip.decompress(compressed)
	assert(
		result.success == valid,
		`Unexpected outcome for {name}: {if result.success then "accepted" else result.error}`
	)

	if result.success then
		const expected = fs.readFileToString(`{FIXTURE_ROOT}/{name}.expected`)
		assert(result.value == expected, `Decoded bytes differ for {name}`)
		assert(gzip.isContent(compressed), `Missing gzip magic for {name}`)
	else
		assert(result.error ~= "", `Missing error for {name}`)
	end
	passedCount += 1
end

assert(not gzip.isContent(""))
assert(not gzip.isContent("x"))
assert(not gzip.isContent("plain text"))
assert(gzip.isContent(string.char(GZIP_MAGIC_FIRST_BYTE, GZIP_MAGIC_SECOND_BYTE)))
print(`Passed {passedCount} gzip fixtures and 4 detection checks`)
