-- The baked card images, uploaded as Fridae Studios group assets. tools/make-card-art.py makes them.
local function asset(id: string): string
	return `rbxassetid://{id}`
end

local BASE = {
	phase_dash = {
		Field = asset("135799689929575"),
		Redline = asset("115323146187126"),
		Prototype = asset("112048701660746"),
		ZeroDay = asset("79522833843252"),
	},
	overclock = {
		Field = asset("130884474614135"),
		Redline = asset("138853290782969"),
		Prototype = asset("112015614808231"),
		ZeroDay = asset("111185498272979"),
	},
	recon_pulse = {
		Field = asset("129588910168237"),
		Redline = asset("72137361297964"),
		Prototype = asset("117730099136065"),
		ZeroDay = asset("122239713548340"),
	},
	aegis_shell = {
		Field = asset("87678255133610"),
		Redline = asset("90952423217373"),
		Prototype = asset("98703814643550"),
		ZeroDay = asset("124785000734405"),
	},
}

local OUTLINE = {
	phase_dash = asset("106694986813790"),
	overclock = asset("85588231199300"),
	recon_pulse = asset("115303810288633"),
	aegis_shell = asset("102822154802573"),
}

local CardArt = {
	STRIPES = asset("126017007753657"), -- one tile, 28 card units square
	HAND_BACK = asset("122178725578514"), -- the back of the cards held in hand. tools/make-card-back.py makes it.
}

-- The image for this card and look, or nil if it has no art yet.
function CardArt.base(cardId: string, look: string): string?
	local looks = BASE[cardId]
	return looks and looks[look]
end

-- The outline of the card's monogram, or nil if it has no art yet.
function CardArt.outline(cardId: string): string?
	return OUTLINE[cardId]
end

return CardArt
