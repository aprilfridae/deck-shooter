-- The look shared by the first-person arms and the player's body.
local Palette = require(script.Parent.Palette)

return {
	skin = Palette.DeepNavy,
	material = Enum.Material.SmoothPlastic,
	-- The outline: Deep Navy (#29324F) brightened about two and a half times, so it shows against the navy bodies
	-- and dark walls. It was Data Cyan.
	glow = Color3.fromRGB(104, 127, 201),
	glowFill = 1, -- how see-through the glow is over the body itself: there is none, only the outline (it was 0.82)
	glowEdge = 0.1, -- and the outline
	depthMode = Enum.HighlightDepthMode.Occluded,
}
