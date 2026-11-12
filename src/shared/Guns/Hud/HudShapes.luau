-- The HUD's shapes, uploaded as Fridae Studios group assets (docs/specs/hud-redesign.md). Each is white, to be
-- tinted. After re-running tools/make-hud-shapes.py, upload what changed and update its id here.
return {
	Plate = "rbxassetid://72367120969176", -- a solid slanted plate: a menu button
	PlateOutline = "rbxassetid://135702852559546", -- the same plate as an outline
	Stripe = "rbxassetid://80655224744358", -- a bar with three slashes at its left end
	CutFill = "rbxassetid://137499416427828", -- a square with two cut corners, for stretching into a button
	CutOutline = "rbxassetid://73036917067314", -- the same as an outline
	Gun = "rbxassetid://140627369227456", -- the kill feed's pistol, pointing left

	PLATE_RATIO = 512 / 167, -- width over height
	STRIPE_RATIO = 512 / 56,
	GUN_RATIO = 96 / 64,
	CUT_SIZE = 64, -- the cut images' width and height, in pixels
	CUT = 24, -- how much of a corner is cut off, in the image's pixels
	CUT_SLICE = Rect.new(28, 28, 36, 36), -- the part that stretches
}
