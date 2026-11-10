-- Made-up code and system output for the Outpost's monitors. CodeLines.new(seed) gives a stream: call
-- CodeLines.next(stream) for each new line. The same seed always gives the same lines.
local CodeLines = {}

local WORDS = { "node", "relay", "proto", "deck", "split", "carrier", "packet", "frame", "signal", "layer", "host", "shell", "trace", "echo", "sync", "buffer", "kernel", "daemon", "socket", "vector" }
local VERBS = { "connect", "open", "route", "fetch", "probe", "mount", "bind", "listen", "decode", "flush", "spawn", "handshake" }
local STATUS = { "OK", "OK", "OK", "ACK", "WAIT", "RETRY", "LOST", "NULL", "DONE" }
local HEX = "0123456789ABCDEF"

export type Stream = { state: number, indent: number }

function CodeLines.new(seed: number): Stream
	return { state = (math.floor(math.abs(seed)) % 2147483646) + 1, indent = 0 }
end

-- A small generator of its own, so lines don't depend on anything outside the stream.
local function roll(stream: Stream, n: number): number
	stream.state = (stream.state * 48271) % 2147483647
	return stream.state % n + 1
end

local function pick(stream: Stream, list: { string }): string
	return list[roll(stream, #list)]
end

local function hex(stream: Stream, length: number): string
	local out = table.create(length)
	for i = 1, length do
		local at = roll(stream, 16)
		out[i] = string.sub(HEX, at, at)
	end
	return table.concat(out)
end

local SHAPES: { (Stream) -> string } = {
	function(s)
		return `{pick(s, VERBS)}("{pick(s, WORDS)}://{pick(s, WORDS)}/{roll(s, 999)}")`
	end,
	function(s)
		return `local {pick(s, WORDS)}_{roll(s, 64)} = {pick(s, WORDS)}.{pick(s, VERBS)}(0x{hex(s, 4)})`
	end,
	function(s)
		return `[{string.format("%04d", roll(s, 9999))}] {pick(s, WORDS)} .... {pick(s, STATUS)}`
	end,
	function(s)
		return `0x{hex(s, 8)}  {hex(s, 2)} {hex(s, 2)} {hex(s, 2)} {hex(s, 2)}  {hex(s, 2)} {hex(s, 2)}`
	end,
	function(s)
		s.indent = math.min(s.indent + 1, 3)
		return `if {pick(s, WORDS)}.{pick(s, WORDS)} ~= nil then`
	end,
	function(s)
		s.indent = math.max(s.indent - 1, 0)
		return "end"
	end,
	function(s)
		return `> {pick(s, VERBS)} {pick(s, WORDS)} --{pick(s, WORDS)}`
	end,
	function(s)
		return `{pick(s, WORDS)}[{roll(s, 256) - 1}] = {pick(s, WORDS)}:{pick(s, VERBS)}()`
	end,
}

function CodeLines.next(stream: Stream): string
	local before = stream.indent
	local line = SHAPES[roll(stream, #SHAPES)](stream)
	-- "end" sits at the level it closes; everything else at the level it was written at.
	local indent = math.min(before, stream.indent)
	return string.rep("  ", indent) .. line
end

return CodeLines
