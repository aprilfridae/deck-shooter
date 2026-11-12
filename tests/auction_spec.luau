local harness = require("./harness")
local Auction = require("../src/shared/CardCore/Auction")
local Config = require("../src/shared/CardCore/Config")
local Inventory = require("../src/shared/CardCore/Inventory")
local SaveData = require("../src/shared/CardCore/SaveData")

local describe, it, expect = harness.describe, harness.it, harness.expect

local KEY = Inventory.key("aegis_shell", "Prototype", "Base")
local NOW = 1000000
local SELLER, ALICE, BOB = 1, 2, 3

-- A save holding aegis_shell Prototype serials 3 to 5 and this many Credits.
local function save(credits: number?): any
	local data = SaveData.new()
	data.credits = credits or 0
	Inventory.add(data, "aegis_shell", "Prototype", "Base", 3)
	Inventory.number(data, KEY, 3, 5)
	return data
end

local function request(changes: any?): any
	local req = { cardId = "aegis_shell", tier = "Prototype", variant = "Base", serial = 4, startBid = 100, hours = 6, buyNow = 500 }
	for field, value in changes or {} do
		req[field] = if value == "none" then nil else value
	end
	return req
end

-- A seller's save with serial 4 listed, and its record.
local function listing(changes: any?): (any, any)
	local seller = save()
	local listed = Auction.list(seller, "a1", request(changes), NOW)
	return seller, Auction.record("a1", SELLER, "Seller", listed)
end

-- Places a bid the way the server does: hold, then the record takes it.
local function bid(data: any, userId: number, record: any, amount: number, now: number): any
	Auction.hold(data, record.id, Auction.price(record, amount), record.endsAt)
	return Auction.accept(record, userId, "Bidder", amount, now) or record
end

local function copies(serial: number, saves: { any }): number
	local total = 0
	for _, data in saves do
		local found = data.serials[KEY]
		for index = 1, if found then #found.runs else 0, 2 do
			if serial >= found.runs[index] and serial <= found.runs[index + 1] then
				total += 1
			end
		end
		for _, listed in data.market.listed do
			if listed.serial == serial then
				total += 1
			end
		end
	end
	return total
end

local function credits(saves: { any }): number
	local total = 0
	for _, data in saves do
		total += data.credits
		for _, held in data.market.bids do
			total += held.amount
		end
	end
	return total
end

describe("Auction listing", function()
	it("allows a numbered card with sensible prices", function()
		expect((Auction.canList(save(), request()))).toBe(true)
		expect((Auction.canList(save(), request({ buyNow = "none" })))).toBe(true)
	end)

	it("refuses requests that aren't the right shape", function()
		local _, code = Auction.canList(save(), "junk")
		expect(code).toBe("BadRequest")
		for _, change in { { cardId = "no_such_card" }, { tier = "Mythic" }, { variant = "Shiny" } } :: { any } do
			_, code = Auction.canList(save(), request(change))
			expect(code).toBe("BadRequest")
		end
		for _, field in { "serial", "startBid", "hours", "buyNow" } do
			for _, value in { 1.5, -3, 0 / 0, math.huge, "ten" } :: { any } do
				_, code = Auction.canList(save(), request({ [field] = value }))
				expect(code).toBe("BadRequest")
			end
		end
	end)

	it("refuses a length that isn't 1, 6 or 24 hours", function()
		local _, code = Auction.canList(save(), request({ hours = 2 }))
		expect(code).toBe("BadLength")
		for _, hours in Auction.LENGTHS do
			expect((Auction.canList(save(), request({ hours = hours })))).toBe(true)
		end
	end)

	it("refuses bad prices", function()
		for _, change in { { startBid = 0 }, { startBid = Config.MaxCredits + 2, buyNow = "none" }, { buyNow = 100 }, { buyNow = 50 }, { buyNow = Config.MaxCredits + 2 } } :: { any } do
			local _, code = Auction.canList(save(), request(change))
			expect(code).toBe("BadPrice")
		end
	end)

	it("refuses a card the player doesn't hold, a starter card and one waiting for its serial", function()
		local _, code = Auction.canList(save(), request({ serial = 9 }))
		expect(code).toBe("NotOwned")
		_, code = Auction.canList(save(), request({ cardId = "phase_dash", tier = "Field", serial = 1 }))
		expect(code).toBe("NotOwned")
		local data = save()
		Inventory.add(data, "overclock", "Prototype", "Base", 1)
		_, code = Auction.canList(data, request({ cardId = "overclock", serial = 1 }))
		expect(code).toBe("NotOwned")
	end)

	it("refuses the last copy of a card in the deck", function()
		local data = SaveData.new()
		Inventory.add(data, "aegis_shell", "Prototype", "Base", 1)
		Inventory.number(data, KEY, 4, 4)
		data.deck[1] = { cardId = "aegis_shell", tier = "Prototype" }
		local _, code = Auction.canList(data, request())
		expect(code).toBe("InDeck")
		Inventory.add(data, "aegis_shell", "Prototype", "ZeroDay", 1)
		expect((Auction.canList(data, request()))).toBe(true)
	end)

	it("refuses an eleventh listing", function()
		local data = save()
		for index = 1, 10 do
			data.market.listed[`x{index}`] = {}
		end
		local _, code = Auction.canList(data, request())
		expect(code).toBe("TooManyListings")
	end)

	it("moves the card out of the collection into the save's listed entry", function()
		local data = save()
		local listed = Auction.list(data, "a1", request(), NOW)
		expect(data.serials[KEY].runs).toEqual({ 3, 3, 5, 5 })
		expect(data.stacks[KEY]).toBe(2)
		expect(listed.serial).toBe(4)
		expect(listed.live).toBe(false)
		expect(listed.endsAt).toBe(NOW + 6 * 3600)
		expect(data.market.listed.a1).toBe(listed)
	end)
end)

describe("Auction bidding", function()
	it("sets the least next bid", function()
		local _, record = listing()
		expect(Auction.minBid(record)).toBe(100)
		record.bid = 100
		expect(Auction.minBid(record)).toBe(105)
		record.bid = 10
		expect(Auction.minBid(record)).toBe(11)
		record.bid = 1
		expect(Auction.minBid(record)).toBe(2)
	end)

	it("refuses bids for each reason", function()
		local _, record = listing()
		local rich = save(1000)
		local function code(data: any, userId: number, from: any, amount: any, now: number): string?
			local _, why = Auction.canBid(data, userId, from, amount, now)
			return why
		end
		expect((Auction.canBid(rich, ALICE, record, 100, NOW))).toBe(true)
		expect(code(rich, ALICE, "junk", 100, NOW)).toBe("BadRequest")
		for _, amount in { 1.5, -3, 0 / 0, math.huge, "ten" } :: { any } do
			expect(code(rich, ALICE, record, amount, NOW)).toBe("BadRequest")
		end
		expect(code(rich, ALICE, record, 100, record.endsAt)).toBe("Ended")
		expect(code(rich, SELLER, record, 100, NOW)).toBe("OwnListing")
		expect(code(rich, ALICE, record, 99, NOW)).toBe("TooLow")
		expect(code(save(50), ALICE, record, 100, NOW)).toBe("NotEnoughCredits")
		local taken = Auction.accept(record, ALICE, "Alice", 100, NOW) :: any
		expect(code(rich, ALICE, taken, 200, NOW)).toBe("AlreadyHighest")
		expect(code(rich, BOB, taken, 104, NOW)).toBe("TooLow")
		local busy = save(1000)
		for index = 1, 20 do
			busy.market.bids[`x{index}`] = { amount = 1, endsAt = 0 }
		end
		expect(code(busy, BOB, record, 100, NOW)).toBe("TooManyBids")
		local cancelled = Auction.cancel(record, SELLER, NOW) :: any
		expect(code(rich, ALICE, cancelled, 100, NOW)).toBe("Ended")
	end)

	it("refuses a price past the Credit limit when there is no Buy Now to cap it", function()
		local _, record = listing({ buyNow = "none" })
		local _, code = Auction.canBid(save(Config.MaxCredits), ALICE, record, Config.MaxCredits + 2, NOW)
		expect(code).toBe("BadPrice")
	end)

	it("charges Buy Now, not the bid, and ends the auction at once", function()
		local _, record = listing()
		expect(Auction.price(record, 9000)).toBe(500)
		expect(Auction.price(record, 499)).toBe(499)
		local taken = Auction.accept(record, ALICE, "Alice", 9000, NOW) :: any
		expect(taken.bid).toBe(500)
		expect(taken.endsAt).toBe(NOW)
		expect(taken.bidder).toBe(ALICE)
		-- Affording Buy Now is enough, however large the bid typed.
		expect((Auction.canBid(save(500), ALICE, record, 9000, NOW))).toBe(true)
	end)

	it("pushes the end back for a late bid only", function()
		local _, record = listing({ buyNow = "none" })
		local late = record.endsAt - 30
		expect((Auction.accept(record, ALICE, "Alice", 100, late) :: any).endsAt).toBe(late + 120)
		expect((Auction.accept(record, ALICE, "Alice", 100, record.endsAt - 3600) :: any).endsAt).toBe(record.endsAt)
	end)

	it("takes a bid without changing the record it was given", function()
		local _, record = listing()
		local before = table.clone(record)
		local taken = Auction.accept(record, ALICE, "Alice", 100, NOW) :: any
		expect(record).toEqual(before)
		expect(taken.bid).toBe(100)
		expect(Auction.accept(taken, BOB, "Bob", 104, NOW)).toBe(nil)
		expect(Auction.accept(taken, ALICE, "Alice", 300, NOW)).toBe(nil)
		expect(Auction.accept(record, SELLER, "Seller", 100, NOW)).toBe(nil)
		expect(Auction.accept(record, ALICE, "Alice", 100, record.endsAt)).toBe(nil)
		expect(Auction.accept(record, ALICE, "Alice", 0 / 0, NOW)).toBe(nil)
	end)

	it("sets aside exactly the price, counting an older bid on the same auction", function()
		local data = save(1000)
		Auction.hold(data, "a1", 300, 5)
		expect(data.credits).toBe(700)
		expect(data.market.bids.a1.amount).toBe(300)
		Auction.hold(data, "a1", 450, 9)
		expect(data.credits).toBe(550)
		expect(data.market.bids.a1).toEqual({ amount = 450, endsAt = 9 })
	end)

	it("lets only the seller cancel, and only before a bid or the end", function()
		local _, record = listing()
		expect(Auction.cancel(record, ALICE, NOW)).toBe(nil)
		expect(Auction.cancel(record, SELLER, record.endsAt)).toBe(nil)
		expect((Auction.cancel(record, SELLER, NOW) :: any).cancelled).toBe(true)
		expect(record.cancelled).toBe(nil)
		local taken = Auction.accept(record, ALICE, "Alice", 100, NOW) :: any
		expect(Auction.cancel(taken, SELLER, NOW)).toBe(nil)
	end)
end)

describe("Auction settling", function()
	it("gives the winner the card and the seller the Credits, once each", function()
		local seller, record = listing({ buyNow = "none" })
		local alice = SaveData.new()
		alice.credits = 1000
		record = bid(alice, ALICE, record, 250, NOW)
		local everyone = { seller, alice }
		expect(copies(4, everyone)).toBe(1)
		local total = credits(everyone)
		local after = record.endsAt + 1

		expect(Auction.settle(alice, ALICE, "a1", record, NOW)).toBe("Wait")
		expect(Auction.settle(seller, SELLER, "a1", record, NOW)).toBe("Wait")
		expect(seller.market.listed.a1.live).toBe(true)

		expect(Auction.settle(alice, ALICE, "a1", record, after)).toBe("Collected")
		expect(alice.credits).toBe(750)
		expect(alice.market.settled.a1).toBe(true)
		expect(alice.serials[KEY].runs).toEqual({ 4, 4 })
		expect(Auction.settle(alice, ALICE, "a1", record, after)).toBe("None")

		expect(Auction.settle(seller, SELLER, "a1", record, after)).toBe("Paid")
		expect(seller.credits).toBe(250)
		expect(Auction.settle(seller, SELLER, "a1", record, after)).toBe("None")
		expect(credits(everyone)).toBe(total)
		expect(copies(4, everyone)).toBe(1)
	end)

	it("moves exactly one copy from the seller to a winner who didn't hold that serial", function()
		local seller, record = listing({ buyNow = "none" })
		local bob = SaveData.new()
		bob.credits = 1000
		record = bid(bob, BOB, record, 100, NOW)
		local everyone = { seller, bob }
		expect(copies(4, everyone)).toBe(1)
		local after = record.endsAt + 1
		expect(Auction.settle(bob, BOB, "a1", record, after)).toBe("Collected")
		expect(Auction.settle(seller, SELLER, "a1", record, after)).toBe("Paid")
		expect(copies(4, everyone)).toBe(1)
		expect(bob.serials[KEY].runs).toEqual({ 4, 4 })
		expect(seller.serials[KEY].runs).toEqual({ 3, 3, 5, 5 })
		expect(credits(everyone)).toBe(1000)
	end)

	it("never collects twice, even from a save that lost its note", function()
		local _, record = listing({ buyNow = "none" })
		local bob = SaveData.new()
		bob.credits = 500
		record = bid(bob, BOB, record, 100, NOW)
		local after = record.endsAt + 1
		-- The save is as it was before collecting, but the record already says the winner is done.
		local done = Auction.finish(record, "winner")
		expect(Auction.settle(bob, BOB, "a1", done, after)).toBe("Done")
		expect(bob.stacks[KEY]).toBe(nil)
		expect(bob.market.bids.a1).toBe(nil)
		-- And the other way: the note is there, the record isn't marked yet.
		local carol = SaveData.new()
		carol.market.settled.a1 = true
		carol.market.bids.a1 = { amount = 100, endsAt = record.endsAt }
		expect(Auction.settle(carol, BOB, "a1", record, after)).toBe("Done")
		expect(carol.stacks[KEY]).toBe(nil)
	end)

	it("never pays the seller twice", function()
		local seller, record = listing({ buyNow = "none" })
		local bob = SaveData.new()
		bob.credits = 500
		record = bid(bob, BOB, record, 100, NOW)
		local stale = Auction.finish(record, "seller")
		expect(Auction.settle(seller, SELLER, "a1", stale, record.endsAt + 1)).toBe("Done")
		expect(seller.credits).toBe(0)
		expect(seller.market.listed.a1).toBe(nil)
	end)

	it("returns an unsold card with its serial", function()
		local seller, record = listing()
		expect(Auction.settle(seller, SELLER, "a1", record, record.endsAt)).toBe("Returned")
		expect(seller.serials[KEY].runs).toEqual({ 3, 5 })
		expect(seller.market.listed.a1).toBe(nil)
		expect(Auction.settle(seller, SELLER, "a1", record, record.endsAt)).toBe("None")
		expect(copies(4, { seller })).toBe(1)
	end)

	it("returns a cancelled card", function()
		local seller, record = listing()
		local cancelled = Auction.cancel(record, SELLER, NOW)
		expect(Auction.settle(seller, SELLER, "a1", cancelled, NOW)).toBe("Returned")
		expect(seller.serials[KEY].runs).toEqual({ 3, 5 })
	end)

	it("refunds a bidder who was outbid", function()
		local _, record = listing({ buyNow = "none" })
		local alice, bob = save(1000), save(1000)
		record = bid(alice, ALICE, record, 100, NOW)
		record = bid(bob, BOB, record, 200, NOW)
		expect(Auction.settle(alice, ALICE, "a1", record, NOW)).toBe("Refunded")
		expect(alice.credits).toBe(1000)
		expect(Auction.settle(alice, ALICE, "a1", record, NOW)).toBe("None")
		expect(Auction.settle(bob, BOB, "a1", record, NOW)).toBe("Wait")
		expect(bob.credits).toBe(800)
	end)

	it("finishes a listing whose server died before its record was made", function()
		local seller = save()
		Auction.list(seller, "a1", request(), NOW)
		local before = copies(4, { seller })
		expect(Auction.settle(seller, SELLER, "a1", nil, NOW)).toBe("Publish")
		expect(seller.market.listed.a1.serial).toBe(4)
		expect(copies(4, { seller })).toBe(before)
		-- Once confirmed live, a record that vanishes sends the card home.
		seller.market.listed.a1.live = true
		expect(Auction.settle(seller, SELLER, "a1", nil, NOW)).toBe("Returned")
		expect(seller.serials[KEY].runs).toEqual({ 3, 5 })
	end)

	it("refunds a bid whose server died before the record took it", function()
		local _, record = listing({ buyNow = "none" })
		local alice, bob = save(1000), save(1000)
		record = bid(alice, ALICE, record, 100, NOW)
		Auction.hold(bob, "a1", 200, record.endsAt) -- held, but the record never heard
		expect(Auction.settle(bob, BOB, "a1", record, NOW)).toBe("Refunded")
		expect(bob.credits).toBe(1000)
		-- A record that is gone altogether refunds too.
		expect(Auction.settle(alice, ALICE, "a1", nil, NOW)).toBe("Refunded")
		expect(alice.credits).toBe(1000)
	end)

	it("gives back the extra when the save held more than the record took", function()
		local _, record = listing({ buyNow = "none" })
		local alice = save(1000)
		record = Auction.accept(record, ALICE, "Alice", 100, NOW) :: any
		Auction.hold(alice, "a1", 300, record.endsAt)
		expect(Auction.settle(alice, ALICE, "a1", record, NOW)).toBe("Wait")
		expect(alice.credits).toBe(900)
		expect(alice.market.bids.a1.amount).toBe(100)
	end)

	it("settles each side whenever it comes back, in either order", function()
		for _, sellerFirst in { true, false } do
			local seller, record = listing({ buyNow = "none" })
			local bob = SaveData.new()
			bob.credits = 500
			record = bid(bob, BOB, record, 100, NOW)
			local muchLater = record.endsAt + 90 * 24 * 3600
			local first, second = if sellerFirst then "seller" else "winner", if sellerFirst then "winner" else "seller"
			local function settle(side: string, at: number): string
				return if side == "seller" then Auction.settle(seller, SELLER, "a1", record, at) else Auction.settle(bob, BOB, "a1", record, at)
			end
			expect(settle(first, record.endsAt)).toBe(if sellerFirst then "Paid" else "Collected")
			local marked, delete = Auction.finish(record, first :: any)
			expect(delete).toBe(false)
			record = marked
			expect(settle(second, muchLater)).toBe(if sellerFirst then "Collected" else "Paid")
			_, delete = Auction.finish(record, second :: any)
			expect(delete).toBe(true)
			expect(copies(4, { seller, bob })).toBe(1)
			expect(credits({ seller, bob })).toBe(500)
		end
	end)

	it("deletes an unsold auction's record once the seller has the card back", function()
		local _, record = listing()
		local _, delete = Auction.finish(record, "seller")
		expect(delete).toBe(true)
		_, delete = Auction.finish(Auction.cancel(record, SELLER, NOW) :: any, "seller")
		expect(delete).toBe(true)
	end)

	it("clears a save's note once the record is marked", function()
		local data = SaveData.new()
		data.market.settled.a1 = true
		Auction.cleared(data, "a1")
		expect(data.market.settled.a1).toBe(nil)
	end)

	it("does nothing for a save with no part in the auction", function()
		local _, record = listing()
		expect(Auction.settle(SaveData.new(), BOB, "a1", record, NOW)).toBe("None")
	end)
end)
