const process = require("@std/process")

const checks = {
	{ "stylua", "--check", "src", "tests/run.luau", "loom.config.luau", ".lute/scripts/check.luau" },
	{ "lute", "check", "src/init.luau", "tests/run.luau", ".lute/scripts/check.luau" },
	{ "lute", "run", "tests/run.luau" },
}
local succeeded = true

for _, arguments in checks do
	const result = process.run(arguments, { stdio = "inherit" })
	succeeded = succeeded and result.ok
end

process.exit(if succeeded then 0 else 1)
