-- The look shared by the first-person arms and the player's body.
local Palette = require(script.Parent.Palette)

return {
	skin = Palette.DeepNavy,
	material = Enum.Material.SmoothPlastic,
	glow = Palette.DataCyan,
	glowFill = 0.82, -- how see-through the glow is over the body itself
	glowEdge = 0.3, -- and the outline
	depthMode = Enum.HighlightDepthMode.Occluded,
}
