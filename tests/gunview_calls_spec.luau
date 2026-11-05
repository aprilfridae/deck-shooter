-- GunView needs Roblox to run, so these only read the source: a call to a function it
-- doesn't have would otherwise show up as an error on every shot in Play.
local fs = require("@lune/fs")
local harness = require("./harness")

local describe, it, expect = harness.describe, harness.it, harness.expect

describe("GunView callers", function()
	it("only call functions GunView has", function()
		local source = fs.readFile("src/client/GunView.luau")
		local missing = {}
		for _, name in fs.readDir("src/client") do
			if name ~= "GunView.luau" then
				local path = "src/client/" .. name
				if fs.isFile(path) then
					for called in string.gmatch(fs.readFile(path), "GunView%.([%w_]+)%(") do
						if not string.find(source, "function GunView." .. called .. "(", 1, true) then
							table.insert(missing, name .. " calls " .. called)
						end
					end
				end
			end
		end
		expect(table.concat(missing, ", ")).toBe("")
	end)
end)
