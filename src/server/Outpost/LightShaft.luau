-- Lays out the soft columns that make a round shaft of light. A Beam is flat, so a shaft
-- looks round from every side only as a bundle of them, fading toward the rim.
local RINGS = {
	{ share = 0, count = 1, width = 0.8, transparency = 0.93 },
	{ share = 0.35, count = 6, width = 0.6, transparency = 0.94 },
	{ share = 0.7, count = 10, width = 0.6, transparency = 0.96 },
}

export type Column = { x: number, z: number, width: number, transparency: number }

local LightShaft = {}

function LightShaft.columns(radius: number): { Column }
	local columns: { Column } = {}
	for _, ring in RINGS do
		for index = 1, ring.count do
			local angle = (index - 1) / ring.count * math.pi * 2
			table.insert(columns, {
				x = math.cos(angle) * ring.share * radius,
				z = math.sin(angle) * ring.share * radius,
				width = ring.width * radius,
				transparency = ring.transparency,
			})
		end
	end
	return columns
end

return LightShaft
