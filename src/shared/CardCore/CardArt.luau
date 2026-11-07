-- The baked card images, uploaded as Fridae Studios group assets. tools/make-card-art.py makes them.
local function asset(id: string): string
	return `rbxassetid://{id}`
end

local BASE = {
	phase_dash = {
		Field = asset("78472403032292"),
		Redline = asset("77584333850554"),
		Prototype = asset("90103783436516"),
		ZeroDay = asset("112487165085829"),
	},
	overclock = {
		Field = asset("71482834272469"),
		Redline = asset("132890190104317"),
		Prototype = asset("139588939360760"),
		ZeroDay = asset("76955485545576"),
	},
	recon_pulse = {
		Field = asset("118876353214421"),
		Redline = asset("76202261135666"),
		Prototype = asset("107509345501040"),
		ZeroDay = asset("133153687913739"),
	},
	aegis_shell = {
		Field = asset("97953290216118"),
		Redline = asset("136015435171100"),
		Prototype = asset("76108922628178"),
		ZeroDay = asset("97625491389068"),
	},
}

local OUTLINE = {
	phase_dash = asset("90685667021640"),
	overclock = asset("89150489358147"),
	recon_pulse = asset("77524852632325"),
	aegis_shell = asset("124056295303994"),
}

local CardArt = {
	STRIPES = asset("126017007753657"), -- one tile, 28 card units square
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
