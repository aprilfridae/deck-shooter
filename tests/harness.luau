-- Small Jest-style test harness for Lune. Jest-Lua only runs inside Roblox.
local harness = {}

local passed, failed = 0, 0
local stack: { string } = {}

local function show(v: any): string
	if type(v) == "string" then
		return string.format("%q", v)
	end
	return tostring(v)
end

local function deepEqual(a: any, b: any): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for k, v in a do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

function harness.describe(name: string, fn: () -> ())
	table.insert(stack, name)
	fn()
	table.remove(stack)
end

function harness.it(name: string, fn: () -> ())
	local ok, err = xpcall(fn, function(e)
		return debug.traceback(tostring(e), 2)
	end)
	if ok then
		passed += 1
	else
		failed += 1
		print(`FAIL {table.concat(stack, " > ")} > {name}\n  {err}`)
	end
end

function harness.expect(actual: any)
	local m = {}
	local function check(cond: boolean, message: string)
		if not cond then
			error(message, 3)
		end
	end
	function m.toBe(expected: any)
		check(actual == expected, `expected {show(expected)}, got {show(actual)}`)
	end
	function m.toEqual(expected: any)
		check(deepEqual(actual, expected), `tables or values differ: got {show(actual)}`)
	end
	function m.toBeCloseTo(expected: number, eps: number?)
		local tolerance = eps or 1e-6
		check(
			type(actual) == "number" and math.abs(actual - expected) <= tolerance,
			`expected about {expected}, got {show(actual)}`
		)
	end
	function m.toBeNil()
		check(actual == nil, `expected nil, got {show(actual)}`)
	end
	function m.toBeTruthy()
		check(not not actual, `expected truthy, got {show(actual)}`)
	end
	function m.toThrow()
		check(not pcall(actual), "expected function to throw")
	end
	return m
end

function harness.report(): number
	print(`{passed} passed, {failed} failed`)
	return failed
end

return harness
