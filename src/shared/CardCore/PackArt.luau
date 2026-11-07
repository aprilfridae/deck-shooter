-- The baked pack wrappers, uploaded as Fridae Studios group assets. tools/make-pack-art.py makes them.
local IMAGES = {
	Field = "rbxassetid://82622460960416",
	BlackSite = "rbxassetid://70788501699841",
	Prototype = "rbxassetid://73787478707410",
	ZeroDay = "rbxassetid://139963558811526",
}

local PackArt = {}

-- The wrapper for this pack, or nil if there isn't one.
function PackArt.image(pack: string): string?
	return IMAGES[pack]
end

return PackArt
