-- Runs every spec. A spec missing from this list fails the run.
local fs = require("@lune/fs")
local process = require("@lune/process")
local harness = require("./harness")

local listed = {
	tier_spec = true,
	cards_spec = true,
	inventory_spec = true,
	variant_spec = true,
	deck_spec = true,
	fusion_spec = true,
	dpr_spec = true,
	income_spec = true,
	savedata_spec = true,
	requests_spec = true,
	movestate_spec = true,
	speedlimit_spec = true,
	climb_spec = true,
	damage_spec = true,
	weapon_spec = true,
	shots_spec = true,
	spread_spec = true,
	loadout_spec = true,
	recoil_spec = true,
	armpose_spec = true,
	armclip_spec = true,
	tracer_spec = true,
	hitmarker_spec = true,
	gunview_calls_spec = true,
	ability_spec = true,
	cardhand_spec = true,
	glyphdata_spec = true,
	typelayout_spec = true,
	menustate_spec = true,
	musicbars_spec = true,
	lightshaft_spec = true,
	gable_spec = true,
	bodypose_spec = true,
	hudtext_spec = true,
	zones_spec = true,
}

require("./tier_spec")
require("./cards_spec")
require("./inventory_spec")
require("./variant_spec")
require("./deck_spec")
require("./fusion_spec")
require("./dpr_spec")
require("./income_spec")
require("./savedata_spec")
require("./requests_spec")
require("./movestate_spec")
require("./speedlimit_spec")
require("./climb_spec")
require("./damage_spec")
require("./weapon_spec")
require("./shots_spec")
require("./spread_spec")
require("./loadout_spec")
require("./recoil_spec")
require("./armpose_spec")
require("./armclip_spec")
require("./tracer_spec")
require("./hitmarker_spec")
require("./gunview_calls_spec")
require("./ability_spec")
require("./cardhand_spec")
require("./glyphdata_spec")
require("./typelayout_spec")
require("./menustate_spec")
require("./musicbars_spec")
require("./lightshaft_spec")
require("./gable_spec")
require("./bodypose_spec")
require("./hudtext_spec")
require("./zones_spec")

local missing = 0
for _, name in fs.readDir("tests") do
	local spec = string.match(name, "^(.+_spec)%.luau$")
	if spec and not listed[spec] then
		print(`FAIL {name} is not listed in tests/run.luau`)
		missing += 1
	end
end

process.exit(if harness.report() + missing > 0 then 1 else 0)
