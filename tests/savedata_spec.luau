local harness = require("./harness")
local Deck = require("../src/shared/CardCore/Deck")
local Inventory = require("../src/shared/CardCore/Inventory")
local SaveData = require("../src/shared/CardCore/SaveData")

local describe, it, expect = harness.describe, harness.it, harness.expect

local function withStack(key: string, n: number)
	local raw = SaveData.new()
	raw.stacks[key] = n
	return raw
end

describe("SaveData.load", function()
	it("takes a removed card out of the deck and refills it", function()
		local raw = SaveData.new()
		raw.stacks["arc_mine:Field:Base"] = 3
		raw.deck[1] = { cardId = "arc_mine", tier = "Field" }
		local loaded = SaveData.load(raw)
		for _, slot in loaded.deck do
			expect(slot.cardId == "arc_mine").toBe(false)
		end
		expect(#loaded.deck).toBe(3)
	end)

	it("returns a new save for nil or a non-table", function()
		for _, raw in { false, 42, "save" } do
			expect(SaveData.load(raw)).toEqual(SaveData.new())
		end
		expect(SaveData.load(nil)).toEqual(SaveData.new())
	end)

	it("round-trips a valid save unchanged", function()
		local raw = SaveData.new()
		raw.credits = 123
		raw.creditRemainder = 0.25
		raw.catalysts = 2
		raw.gunLevels = { 3, 1 }
		Inventory.add(raw, "aegis_shell", "BlackSite", "Chromatic", 2)
		expect(SaveData.load(raw)).toEqual(raw)
	end)

	it("fills fields missing from an older save", function()
		local loaded = SaveData.load({ version = 5, credits = 5 })
		expect(loaded.credits).toBe(5)
		expect(loaded.catalysts).toBe(0)
		expect(#loaded.deck).toBe(3)
	end)

	it("gives a version 3 save empty packs and no rebirths", function()
		local old = SaveData.load({ version = 5, credits = 5 })
		expect(old.credits).toBe(5)
		expect(old.packs.Field).toBe(0)
		expect(old.rebirths).toBe(0)
		expect(old.openAllCredits).toBe(0)
		expect(#old.receipts).toBe(0)
	end)

	it("keeps good pack data and drops bad values", function()
		local loaded = SaveData.load({
			version = 5,
			rebirths = 2,
			openAllCredits = 1,
			receipts = { "a", 5 },
			packs = { Field = 3, BlackSite = -1, Prototype = 1.5, ZeroDay = "x", Nonsense = 9 },
		})
		expect(loaded.packs.Field).toBe(3)
		expect(loaded.packs.BlackSite).toBe(0)
		expect(loaded.packs.Prototype).toBe(0)
		expect(loaded.packs.ZeroDay).toBe(0)
		expect(loaded.packs.Nonsense).toBe(nil)
		expect(loaded.rebirths).toBe(2)
		expect(loaded.openAllCredits).toBe(1)
		expect(#loaded.receipts).toBe(1)
		expect(SaveData.load({ version = 5, rebirths = 1.5 }).rebirths).toBe(0)
	end)

	it("is on version 6", function()
		expect(SaveData.CURRENT_VERSION).toBe(6)
	end)

	it("gives a version 2 save default settings", function()
		local old = SaveData.load({ version = 5, credits = 5 })
		expect(old.credits).toBe(5)
		expect(old.settings.fieldOfView).toBe(80)
	end)

	it("survives a corrupt settings field", function()
		local odd = SaveData.load({ version = 5, settings = "broken", credits = 7 })
		expect(odd.credits).toBe(7)
		expect(odd.settings.music).toBe(1)
	end)

	-- Review Focus 5
	it("refuses a save from a newer build", function()
		local loaded, code = SaveData.load({ version = 99 })
		expect(loaded).toBeNil()
		expect(code).toBe("NewerVersion")
	end)

	it("drops stacks with 0, negative, NaN or fractional counts", function()
		for _, n in { 0, -1, 0 / 0, 1.5, math.huge } do
			local loaded = SaveData.load(withStack("aegis_shell:Field:Base", n))
			expect(loaded.stacks["aegis_shell:Field:Base"]).toBeNil()
		end
	end)

	it("drops malformed stack keys", function()
		local raw = SaveData.new()
		raw.stacks["no_colons"] = 1
		raw.stacks["aegis_shell:Mythic:Base"] = 1
		raw.stacks["aegis_shell:Field:Shiny"] = 1
		raw.stacks[7] = 1
		local loaded = SaveData.load(raw)
		expect(loaded.stacks["no_colons"]).toBeNil()
		expect(loaded.stacks["aegis_shell:Mythic:Base"]).toBeNil()
		expect(loaded.stacks["aegis_shell:Field:Shiny"]).toBeNil()
		expect(loaded.stacks[7]).toBeNil()
	end)

	it("keeps stacks for unknown card ids, so a removed card can return", function()
		local loaded = SaveData.load(withStack("retired_card:Field:Base", 2))
		expect(loaded.stacks["retired_card:Field:Base"]).toBe(2)
	end)

	it("resets negative or NaN credits and catalysts to 0", function()
		local raw = SaveData.new()
		raw.credits = -5
		raw.creditRemainder = 0 / 0
		raw.catalysts = -1
		local loaded = SaveData.load(raw)
		expect(loaded.credits).toBe(0)
		expect(loaded.creditRemainder).toBe(0)
		expect(loaded.catalysts).toBe(0)
	end)

	it("drops absurdly large stack counts", function()
		local loaded = SaveData.load(withStack("aegis_shell:Prototype:ZeroDay", 1.7e308))
		expect(loaded.stacks["aegis_shell:Prototype:ZeroDay"]).toBeNil()
		local also = SaveData.load(withStack("aegis_shell:Prototype:ZeroDay", 1e7))
		expect(also.stacks["aegis_shell:Prototype:ZeroDay"]).toBeNil()
	end)

	it("keeps large but believable values", function()
		local raw = withStack("aegis_shell:Field:Base", 1000000)
		raw.credits = 2 ^ 53
		local loaded = SaveData.load(raw)
		expect(loaded.stacks["aegis_shell:Field:Base"]).toBe(1000000)
		expect(loaded.credits).toBe(2 ^ 53)
	end)

	it("resets absurdly large credits, catalysts and gun levels", function()
		local raw = SaveData.new()
		raw.credits = 1e300
		raw.catalysts = 1e300
		raw.gunLevels = { 1e300, 2 }
		local loaded = SaveData.load(raw)
		expect(loaded.credits).toBe(0)
		expect(loaded.catalysts).toBe(0)
		expect(loaded.gunLevels).toEqual({ 0, 2 })
	end)

	it("resets bad gun levels", function()
		local raw = SaveData.new()
		raw.gunLevels = { -1, "x" }
		expect(SaveData.load(raw).gunLevels).toEqual({ 0, 0 })
	end)

	it("moves a slot to the highest owned tier of that card", function()
		local raw = SaveData.new()
		raw.stacks["phase_dash:Field:Base"] = nil
		raw.stacks["phase_dash:BlackSite:Base"] = 1
		raw.stacks["phase_dash:Prototype:Chromatic"] = 1
		local loaded = SaveData.load(raw)
		expect(loaded.deck[1]).toEqual({ cardId = "phase_dash", tier = "Prototype" })
	end)

	it("replaces a lost card with another owned card", function()
		local raw = SaveData.new()
		raw.stacks["phase_dash:Field:Base"] = nil
		raw.stacks["aegis_shell:BlackSite:Base"] = 1
		local loaded = SaveData.load(raw)
		expect(loaded.deck[1]).toEqual({ cardId = "aegis_shell", tier = "BlackSite" })
	end)

	it("grants a starter copy when nothing else is owned", function()
		local raw = SaveData.new()
		raw.stacks = {}
		local loaded = SaveData.load(raw)
		expect(loaded.deck).toEqual(SaveData.new().deck)
		expect(Inventory.count(loaded, "phase_dash", "Field")).toBe(1)
	end)

	it("always returns a deck that passes Deck.check", function()
		local badDecks: { any } = {
			{},
			"deck",
			{ { cardId = "nope", tier = "Field" } },
			{ { cardId = 1, tier = {} }, 5, "x" },
			{
				{ cardId = "overclock", tier = "Field" },
				{ cardId = "overclock", tier = "Field" },
				{ cardId = "overclock", tier = "Field" },
			},
			{
				{ cardId = "phase_dash", tier = "Field" },
				{ cardId = "overclock", tier = "Field" },
				{ cardId = "siphon", tier = "Field" },
				{ cardId = "aegis_shell", tier = "Field" },
			},
		}
		for _, deck in badDecks do
			local raw = SaveData.new()
			raw.deck = deck
			local loaded = SaveData.load(raw)
			expect((Deck.check(loaded, loaded.deck))).toBe(true)
		end
	end)

	it("does not grant extra copies to a save with a valid deck", function()
		local raw = SaveData.new()
		local loaded = SaveData.load(raw)
		expect(Inventory.count(loaded, "overclock", "Field")).toBe(1)
	end)
end)

describe("SaveData serials and the fresh start", function()
	local Inventory = require("../src/shared/CardCore/Inventory")
	local Config = require("../src/shared/CardCore/Config")
	local KEY = Inventory.key("aegis_shell", "Prototype", "Base")

	local function withRuns(serials: any): any
		return SaveData.load({ version = 5, stacks = { [KEY] = 5 }, serials = serials })
	end

	it("starts a new save with unnumbered starter cards", function()
		local data = SaveData.new()
		for _, cardId in Config.StarterDeck do
			local key = Inventory.key(cardId, "Field", "Base")
			expect(data.stacks[key]).toBe(1)
			expect(data.serials[key].plain).toBe(1)
			expect(Inventory.waiting(data, key)).toBe(0)
		end
	end)

	it("resets a save from before serials, keeping only what isn't earned", function()
		local settings = SaveData.new().settings
		local name, value
		for key, current in settings :: any do
			if type(current) == "boolean" then
				name, value = key, not current
				break
			end
		end
		local oldSettings = table.clone(settings :: any)
		if name then
			oldSettings[name] = value
		end
		local otherClass, otherRifle
		for class in Config.Classes do
			if class ~= Config.DefaultClass then
				otherClass = class
			end
		end
		for rifle in Config.Rifles do
			if rifle ~= Config.DefaultRifle then
				otherRifle = rifle
			end
		end
		local old = {
			version = 4,
			credits = 5000,
			rebirths = 3,
			catalysts = 2,
			gunLevels = { 3, 1 },
			stacks = { [KEY] = 40 },
			packs = {},
			class = otherClass,
			rifle = otherRifle,
			commentsOff = true,
			settings = oldSettings,
			receipts = { "a", "b" },
			openAllCredits = 2,
		}
		for pack in SaveData.new().packs do
			old.packs[pack] = 7
		end
		local data = SaveData.load(old)
		expect(data.version).toBe(6)
		expect(data.credits).toBe(0)
		expect(data.rebirths).toBe(0)
		expect(data.catalysts).toBe(0)
		expect(data.gunLevels).toEqual({ 0, 0 })
		expect(data.stacks[KEY]).toBe(nil)
		for _, count in data.packs do
			expect(count).toBe(0)
		end
		expect(data.stacks).toEqual(SaveData.new().stacks)
		expect(data.deck).toEqual(SaveData.new().deck)
		expect(data.class).toBe(otherClass or Config.DefaultClass)
		expect(data.rifle).toBe(otherRifle or Config.DefaultRifle)
		expect(data.commentsOff).toBe(true)
		if name then
			expect((data.settings :: any)[name]).toBe(value)
		end
		expect(data.receipts).toEqual({ "a", "b" })
		expect(data.openAllCredits).toBe(2)
		-- Once reset it is a version 5 save, and loading it again changes nothing.
		data.credits = 12
		expect(SaveData.load(data).credits).toBe(12)
	end)

	it("resets a save with no version at all", function()
		expect(SaveData.load({ credits = 900 }).credits).toBe(0)
	end)

	it("keeps a version 5 save's cards and serials", function()
		local data = withRuns({ [KEY] = { runs = { 3, 4, 9, 9 }, plain = 1 } })
		expect(data.stacks[KEY]).toBe(5)
		expect(data.serials[KEY].runs).toEqual({ 3, 4, 9, 9 })
		expect(data.serials[KEY].plain).toBe(1)
		expect(Inventory.waiting(data, KEY)).toBe(1)
	end)

	it("drops damaged runs and leaves the copies waiting", function()
		local damaged: { any } = {
			{ runs = { 3, 1 }, plain = 0 },
			{ runs = { 1, 3, 2, 4 }, plain = 0 },
			{ runs = { 1, 9 }, plain = 0 },
			{ runs = { 1, "x" }, plain = 0 },
			{ runs = { 1 }, plain = 0 },
			{ runs = { 0, 2 }, plain = 0 },
			{ runs = { 1.5, 2 }, plain = 0 },
			{ runs = "no", plain = 0 },
			{ runs = {}, plain = -1 },
			{ runs = {}, plain = 9 },
			{ runs = { 1, 4 }, plain = 2 },
			"nonsense",
		}
		for _, entry in damaged do
			local data = withRuns({ [KEY] = entry })
			expect(data.stacks[KEY]).toBe(5)
			expect(data.serials[KEY]).toBe(nil)
			expect(Inventory.waiting(data, KEY)).toBe(5)
		end
		expect(withRuns("nonsense").stacks[KEY]).toBe(5)
	end)

	it("drops serials for a stack the save doesn't hold", function()
		local other = Inventory.key("overclock", "Prototype", "Base")
		local data = withRuns({ [other] = { runs = { 1, 2 }, plain = 0 } })
		expect(data.serials[other]).toBe(nil)
	end)
end)

describe("SaveData market entries", function()
	local Inventory = require("../src/shared/CardCore/Inventory")
	local Config = require("../src/shared/CardCore/Config")
	local KEY = Inventory.key("aegis_shell", "Prototype", "Base")
	local GOOD = { cardId = "aegis_shell", tier = "Prototype", variant = "Base", serial = 4, startBid = 10, buyNow = 50, endsAt = 1000, live = true }

	local function load(market: any): any
		return SaveData.load({ version = 6, credits = 40, market = market })
	end

	it("starts with nothing in the market", function()
		expect(SaveData.new().market).toEqual({ listed = {}, bids = {}, settled = {} })
	end)

	it("gives a version 5 save an empty market and keeps the rest", function()
		local data = SaveData.load({ version = 5, credits = 40, stacks = { [KEY] = 2 }, serials = { [KEY] = { runs = { 3, 4 }, plain = 0 } } })
		expect(data.version).toBe(6)
		expect(data.credits).toBe(40)
		expect(data.serials[KEY].runs).toEqual({ 3, 4 })
		expect(data.market).toEqual({ listed = {}, bids = {}, settled = {} })
	end)

	it("keeps well-formed entries", function()
		local data = load({ listed = { a = GOOD }, bids = { b = { amount = 25, endsAt = 900 } }, settled = { c = true } })
		expect(data.market.listed.a).toEqual(GOOD)
		expect(data.market.bids.b).toEqual({ amount = 25, endsAt = 900 })
		expect(data.market.settled.c).toBe(true)
	end)

	it("keeps a listing with no Buy Now, and marks one with no live flag as not live", function()
		local plain = table.clone(GOOD)
		plain.buyNow = nil
		plain.live = nil :: any
		local data = load({ listed = { a = plain } })
		expect(data.market.listed.a.buyNow).toBe(nil)
		expect(data.market.listed.a.live).toBe(false)
	end)

	it("drops damaged listings", function()
		local changes: { { any } } = {
			{ "cardId", 5 },
			{ "tier", "Mythic" },
			{ "variant", "Shiny" },
			{ "serial", 0 },
			{ "serial", 1.5 },
			{ "startBid", 0 },
			{ "startBid", Config.MaxCredits * 2 },
			{ "buyNow", 10 },
			{ "buyNow", "lots" },
			{ "endsAt", "soon" },
		}
		for _, change in changes do
			local bad = table.clone(GOOD);
			(bad :: any)[change[1]] = change[2]
			expect(load({ listed = { a = bad } }).market.listed.a).toBe(nil)
		end
		expect(load({ listed = { a = "junk", [7] = GOOD } }).market.listed).toEqual({})
	end)

	it("drops damaged bids and settled marks", function()
		for _, amount in { 0, -5, 2.5, Config.MaxCredits * 2, "ten" } :: { any } do
			expect(load({ bids = { b = { amount = amount, endsAt = 900 } } }).market.bids.b).toBe(nil)
		end
		expect(load({ bids = { b = { amount = 5 } } }).market.bids.b).toBe(nil)
		expect(load({ bids = { b = 5 } }).market.bids.b).toBe(nil)
		expect(load({ settled = { c = "yes", d = true } }).market.settled).toEqual({ d = true })
		expect(load("junk").market).toEqual({ listed = {}, bids = {}, settled = {} })
	end)

	it("keeps every entry past the limits, because they hold real cards and Credits", function()
		local listed, bids = {}, {}
		for index = 1, 30 do
			listed[`l{index}`] = GOOD
			bids[`b{index}`] = { amount = 1, endsAt = 900 }
		end
		local data = load({ listed = listed, bids = bids })
		local count = 0
		for _ in data.market.listed do
			count += 1
		end
		for _ in data.market.bids do
			count += 1
		end
		expect(count).toBe(60)
	end)
end)
