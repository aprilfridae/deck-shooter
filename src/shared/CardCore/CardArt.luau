-- The baked card images, uploaded as Fridae Studios group assets. tools/make-card-art.py makes them.
-- The front of a card is built from white layers the game tints (docs/specs/card-face-redesign.md).
local function asset(id: string): string
	return `rbxassetid://{id}`
end

-- One finished still card per card and look, for the card held in hand.
local BASE = {
	phase_dash = {
		Field = asset("98377684891488"),
		Redline = asset("95148623681949"),
		Prototype = asset("88486664429349"),
		ZeroDay = asset("129006350935492"),
	},
	overclock = {
		Field = asset("70446804548308"),
		Redline = asset("95340812191775"),
		Prototype = asset("77933975819540"),
		ZeroDay = asset("125988144353598"),
	},
	recon_pulse = {
		Field = asset("83219826872120"),
		Redline = asset("101011915765620"),
		Prototype = asset("84624213348642"),
		ZeroDay = asset("114888847138546"),
	},
	aegis_shell = {
		Field = asset("90015035895129"),
		Redline = asset("131782252472518"),
		Prototype = asset("100296531126730"),
		ZeroDay = asset("134403433136594"),
	},
	switchback = {
		Field = asset("109465617456919"),
		Redline = asset("70879687126652"),
		Prototype = asset("105168071182882"),
		ZeroDay = asset("82832317490839"),
	},
	kickplate = {
		Field = asset("74728717931862"),
		Redline = asset("88099656418822"),
		Prototype = asset("81819377730387"),
		ZeroDay = asset("108210190219408"),
	},
	siphon = {
		Field = asset("129309485662686"),
		Redline = asset("78275152786620"),
		Prototype = asset("127327035533667"),
		ZeroDay = asset("132424218329350"),
	},
}

-- The acronym, turned to read up the card.
local MONOGRAM = {
	phase_dash = asset("75765543342830"),
	overclock = asset("135426323179588"),
	recon_pulse = asset("102960075522698"),
	aegis_shell = asset("109767241534070"),
	switchback = asset("106456967351723"),
	kickplate = asset("91932903945243"),
	siphon = asset("110001473432004"),
}

-- The name as printed: capitals, run together, medium weight.
local NAME = {
	phase_dash = asset("104867294488632"),
	overclock = asset("87728281454403"),
	recon_pulse = asset("73592612928824"),
	aegis_shell = asset("89813362094565"),
	switchback = asset("92848347395955"),
	kickplate = asset("91657764191287"),
	siphon = asset("83911214140721"),
}

-- The parts every card shares.
local LAYERS = {
	still = asset("105344650204458"),
	rays = asset("121578859570704"),
	star_big = asset("125540555828233"),
	star_small = asset("113868171029345"),
	barcode = asset("115877115812142"),
	swirl = asset("114652075205867"),
	grid = asset("126856381435181"),
	crosshair = asset("77510673565741"),
	measure = asset("71448120829704"),
}

-- The big number for serials 1 to 10, and a blurred copy of each for its glow.
local LOW = {
	asset("103036589361816"),
	asset("121500204347978"),
	asset("75792115993464"),
	asset("76292367187950"),
	asset("129673606434328"),
	asset("73789747300315"),
	asset("110698277461852"),
	asset("94907042725273"),
	asset("125824588010836"),
	asset("137470292611984"),
}
local LOW_GLOW = {
	asset("104843446333078"),
	asset("85833449633466"),
	asset("78556194408536"),
	asset("70581940263068"),
	asset("82297448433361"),
	asset("98318095757143"),
	asset("71757530278058"),
	asset("136493631670944"),
	asset("138334314574977"),
	asset("76560887863630"),
}

local CardArt = {
	STRIPES = asset("126017007753657"), -- one tile, 28 card units square
	HAND_BACK = asset("119555233781807"), -- the back of the cards held in hand. tools/make-card-back.py makes it.
}

-- The flat image for this card and look, or nil if it has no art yet.
function CardArt.base(cardId: string, look: string): string?
	local looks = BASE[cardId]
	return looks and looks[look]
end

function CardArt.monogram(cardId: string): string?
	return MONOGRAM[cardId]
end

function CardArt.name(cardId: string): string?
	return NAME[cardId]
end

-- A shared layer by name. A wrong name is a mistake in the code, so it errors.
function CardArt.layer(name: string): string
	return LAYERS[name] or error(`no card layer called {name}`)
end

function CardArt.lowSerial(serial: number): string?
	return LOW[serial]
end

function CardArt.lowGlow(serial: number): string?
	return LOW_GLOW[serial]
end

return CardArt
