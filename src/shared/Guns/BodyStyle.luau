-- The look shared by the first-person arms and the player's body.
local Palette = require(script.Parent.Palette)

return {
	skin = Palette.DeepNavy,
	material = Enum.Material.SmoothPlastic,
	glow = Palette.DeepNavy, -- the outline: Deep Navy, #29324F (it was Data Cyan)
	glowFill = 1, -- how see-through the glow is over the body itself: there is none, only the outline (it was 0.82)
	glowEdge = 0.3, -- and the outline
	depthMode = Enum.HighlightDepthMode.Occluded,
}
