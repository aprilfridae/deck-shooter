-- Runs every spec. A spec missing from this list fails the run.
local fs = require("@lune/fs")
local process = require("@lune/process")
local harness = require("./harness")

local listed = {
	tier_spec = true,
	cards_spec = true,
}

require("./tier_spec")
require("./cards_spec")

local missing = 0
for _, name in fs.readDir("tests") do
	local spec = string.match(name, "^(.+_spec)%.luau$")
	if spec and not listed[spec] then
		print(`FAIL {name} is not listed in tests/run.luau`)
		missing += 1
	end
end

process.exit(if harness.report() + missing > 0 then 1 else 0)
