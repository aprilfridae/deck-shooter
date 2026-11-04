local harness = require("./harness")
local Config = require("../src/shared/CardCore/Config")
local Dpr = require("../src/shared/CardCore/Dpr")
local GunConfig = require("../src/shared/Guns/GunConfig")
local Requests = require("../src/shared/CardCore/Requests")
local SaveData = require("../src/shared/CardCore/SaveData")

local describe, it, expect = harness.describe, harness.it, harness.expect

describe("Loadout saves", function()
	it("starts new saves at version 2 as Assault with the M4", function()
		local data = SaveData.new()
		expect(data.version).toBe(2)
		expect(data.class).toBe("Assault")
		expect(data.rifle).toBe("M4")
	end)

	it("migrates a version 1 save to Assault with the M4", function()
		local loaded = SaveData.load({ version = 1, credits = 5 })
		expect(loaded.version).toBe(2)
		expect(loaded.class).toBe("Assault")
		expect(loaded.rifle).toBe("M4")
		expect(loaded.credits).toBe(5)
	end)

	it("keeps a saved class and rifle", function()
		local raw = SaveData.new()
		raw.class = "Assault"
		raw.rifle = "AK47"
		expect(SaveData.load(raw).rifle).toBe("AK47")
		raw.class = "Marksman"
		expect(SaveData.load(raw).class).toBe("Marksman")
	end)

	it("repairs an unknown class or rifle to the default", function()
		local raw = SaveData.new()
		raw.class = "Wizard"
		raw.rifle = "Sniper"
		local loaded = SaveData.load(raw)
		expect(loaded.class).toBe("Assault")
		expect(loaded.rifle).toBe("M4")
	end)

	it("repairs a class that is not a string", function()
		local raw: any = SaveData.new()
		raw.class = { "Assault" }
		raw.rifle = 7
		local loaded = SaveData.load(raw)
		expect(loaded.class).toBe("Assault")
		expect(loaded.rifle).toBe("M4")
	end)

	it("keeps the rifle choice on another class", function()
		local raw = SaveData.new()
		raw.class = "Rusher"
		raw.rifle = "AK47"
		local loaded = SaveData.load(raw)
		expect(loaded.class).toBe("Rusher")
		expect(loaded.rifle).toBe("AK47")
	end)

	it("lists the same classes and rifles as the gun data", function()
		local classes = {}
		for class in GunConfig.classes do
			classes[class] = true
		end
		expect(Config.Classes).toEqual(classes)
		local rifles = {}
		for _, id in GunConfig.classes.Assault.primaries do
			rifles[id] = true
		end
		expect(Config.Rifles).toEqual(rifles)
	end)

	it("parses a good loadout and rejects anything else", function()
		expect(Requests.parseLoadout({ class = "Rusher", rifle = "AK47" })).toEqual({ class = "Rusher", rifle = "AK47" })
		expect(Requests.parseLoadout({ class = "Wizard", rifle = "M4" })).toBeNil()
		expect(Requests.parseLoadout({ class = "Rusher", rifle = "SMG" })).toBeNil()
		expect(Requests.parseLoadout({ class = {}, rifle = 1 })).toBeNil()
		expect(Requests.parseLoadout("Rusher")).toBeNil()
	end)

	it("does not raise Deck Power Rating", function()
		local data = SaveData.new()
		local before = Dpr.compute(data.deck, data.gunLevels)
		data.class = "Marksman"
		data.rifle = "AK47"
		expect(Dpr.compute(data.deck, data.gunLevels)).toBe(before)
	end)
end)
