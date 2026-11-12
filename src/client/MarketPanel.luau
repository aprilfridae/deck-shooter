-- The MARKET page of the Outpost menu (docs/specs/market-screen.md): a wall of the cards for sale, a box to bid
-- from, selling, and your own auctions. River's brief, 2026-11-11: "a grid of all the cards with their art, not
-- so much text". The words and the search and sort rules are in CardCore.Market; the auction rules are the server's.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CardCore = ReplicatedStorage:WaitForChild("CardCore")
local Cards = require(CardCore:WaitForChild("Cards"))
local CardLook = require(CardCore:WaitForChild("CardLook"))
local Inventory = require(CardCore:WaitForChild("Inventory"))
local Market = require(CardCore:WaitForChild("Market"))
local Palette = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("Palette"))
local CardData = require(script.Parent.CardData)
local CardFace = require(script.Parent.CardFace)
local MenuPanel = require(script.Parent.MenuPanel)
local PanelKit = require(script.Parent.PanelKit)

local player = Players.LocalPlayer
local MARGIN, RIGHT = PanelKit.MARGIN, PanelKit.RIGHT
local INK, PAPER = PanelKit.INK, PanelKit.PAPER

local TABS = { "BROWSE", "SELL", "MINE" }
local SORTS = { { "soon", "ENDING SOON" }, { "serial", "SERIAL" }, { "rarity", "RARITY" } }
local LENGTHS = { 1, 6, 24 }
local REFRESH = 10 -- seconds between fetches of the list
local MAX_SHOWN = 40 -- cards drawn at once: each is a live card face, and hundreds would crawl
local COLUMNS = 5
local GAP = 0.006
local CELL = (RIGHT - MARGIN - GAP * (COLUMNS - 1)) / COLUMNS
local CARD_HEIGHT = CELL * 1.6
local ROW = CARD_HEIGHT + 0.036
local TAB_TOP = 0.006
local BAR_TOP = 0.04
local BAR_HEIGHT = 0.022
local GRID_TOP = 0.072
local BOX_WIDTH, BOX_HEIGHT = 0.36, 0.2
local BOX_CARD = 0.1
local CORNER = 0.0056
local FONT = Enum.Font.Gotham -- typed text: the game's fonts are image sheets and can't be typed into
local TEXT_SIZE = 0.0125

local state = {
	page = nil :: Frame?,
	tab = "BROWSE",
	search = "",
	sort = "soon",
	listings = {} :: { any },
	fetched = false,
	serverNow = 0,
	at = 0,
	shown = "", -- the list as last fetched, so an unchanged one isn't redrawn
	redrawGrid = nil :: (() -> ())?, -- redraws only BROWSE's cards, leaving the search box alone
	creditsLabel = nil :: any?,
	selling = nil :: any?, -- the card chosen on SELL
	hours = 6,
}
local timers: { { label: any, endsAt: number } } = {}
local changed: RBXScriptConnection? = nil

local MarketPanel = {}

local function unit(): number
	return MenuPanel.unit()
end

local function nameOf(cardId: string): string
	local card = Cards.byId[cardId]
	return if card then card.name else cardId
end

-- The server's clock, carried forward from the last answer.
local function serverNow(): number
	return state.serverNow + (os.clock() - state.at)
end

local function sync(reply: any)
	if type(reply.now) == "number" then
		state.serverNow, state.at = reply.now, os.clock()
	end
end

local function round(gui: GuiObject)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, CORNER * unit())
	corner.Parent = gui
end

local function button(parent: Instance, text: string, x: number, top: number, width: number, height: number, options: any?): TextButton
	local choice = options or {}
	choice.rounded = true
	return PanelKit.button(parent, text, x, top, width, height, choice)
end

local function textBox(parent: Instance, x: number, top: number, width: number, placeholder: string, text: string): TextBox
	local u = unit()
	local box = Instance.new("TextBox")
	box.BackgroundColor3 = PAPER
	box.BorderSizePixel = 0
	box.ClearTextOnFocus = false
	box.Font = FONT
	box.PlaceholderColor3 = INK:Lerp(PAPER, 0.5)
	box.PlaceholderText = placeholder
	box.Position = UDim2.fromOffset(x * u, top * u)
	box.Size = UDim2.fromOffset(width * u, BAR_HEIGHT * u)
	box.Text = text
	box.TextColor3 = INK
	box.TextSize = TEXT_SIZE * u
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.Parent = parent
	round(box)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 0.005 * u)
	pad.Parent = box
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = INK
	stroke.Parent = box
	return box
end

local function frame(parent: Instance, top: number): Frame
	local made = Instance.new("Frame")
	made.BackgroundTransparency = 1
	made.Position = UDim2.fromOffset(0, top * unit())
	made.Size = UDim2.new(1, 0, 1, -top * unit())
	made.Parent = parent
	return made
end

local function scroller(parent: Instance, top: number, rows: number): ScrollingFrame
	local u = unit()
	local grid = Instance.new("ScrollingFrame")
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.CanvasSize = UDim2.fromOffset(0, rows * ROW * u)
	grid.Position = UDim2.fromOffset(0, top * u)
	grid.ScrollBarImageColor3 = INK
	grid.ScrollBarThickness = 3
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.Size = UDim2.new(1, 0, 1, -top * u)
	grid.Parent = parent
	return grid
end

local function timeLabel(parent: Instance, x: number, line: number, endsAt: number)
	local label = PanelKit.label(parent, "Label", PanelKit.SMALL_SIZE, x, line, true)
	local text, urgent = Market.timeLeft(endsAt - serverNow())
	label:set(text)
	label:setColor(if urgent then Palette.HazardRed else INK)
	table.insert(timers, { label = label, endsAt = endsAt })
end

-- One card in a grid, with up to two lines under it. `options` are CardFace's.
local function cell(grid: Instance, index: number, top: number, options: any, lines: any, onClick: (() -> ())?)
	local u = unit()
	local column, row = (index - 1) % COLUMNS, (index - 1) // COLUMNS
	local x = MARGIN + column * (CELL + GAP)
	local y = top + row * ROW
	options.width = CELL * u
	options.position = UDim2.fromOffset(x * u, y * u)
	local face = CardFace.new(grid, options)
	if lines.bold then
		local stroke = Instance.new("UIStroke")
		stroke.Color = INK
		stroke.Thickness = 3
		stroke.Parent = face
	end
	if lines.price then
		PanelKit.label(grid, "LabelBold", PanelKit.LABEL_SIZE, x, y + CARD_HEIGHT + 0.014):set(lines.price)
	end
	if lines.endsAt then
		timeLabel(grid, x + CELL, y + CARD_HEIGHT + 0.014, lines.endsAt)
	end
	if lines.sub then
		PanelKit.label(grid, "Label", PanelKit.SMALL_SIZE * 0.85, x, y + CARD_HEIGHT + 0.027):set(lines.sub)
	end
	if onClick then
		local hit = PanelKit.hitBox(grid, x, y, CELL, CARD_HEIGHT)
		hit.ZIndex = 6 -- above the card's shine
		hit.Activated:Connect(onClick)
	end
end

local function message(parent: Instance, text: string, line: number)
	PanelKit.label(parent, "Label", PanelKit.LABEL_SIZE, MARGIN, line):set(text)
end

local draw: () -> ()

local function fetch()
	local page, tab = state.page, state.tab
	local reply = CardData.ask("BrowseAuctions")
	-- The answer can arrive after the player has gone elsewhere: then there is nothing to draw into.
	if state.page ~= page or not page or not page.Parent then
		return
	end
	local first = not state.fetched
	state.fetched = true
	local parts = {}
	if reply.ok then
		sync(reply)
		local listings = {}
		for _, entry in reply.auctions do
			local listing = Market.unpack(entry)
			if listing then
				table.insert(listings, listing)
				table.insert(parts, `{listing.id}:{listing.price}:{listing.endsAt}`)
			end
		end
		state.listings = listings
	end
	-- Redraw only when something for sale changed, and never under an open bid box.
	local now = table.concat(parts, "|")
	if (now == state.shown and not first) or state.tab ~= tab or page:FindFirstChild("BidBox") then
		state.shown = now
		return
	end
	state.shown = now
	if tab == "BROWSE" and state.redrawGrid then
		state.redrawGrid()
	elseif tab == "MINE" then
		draw()
	end
end

-- The bid box, over the page.
local function bidBox(listing: any)
	local page = state.page
	if not page then
		return
	end
	local u = unit()
	local old = page:FindFirstChild("BidBox")
	if old then
		old:Destroy()
	end
	local scrim = Instance.new("TextButton")
	scrim.Name = "BidBox"
	scrim.Text = ""
	scrim.AutoButtonColor = false
	scrim.BackgroundColor3 = INK
	scrim.BackgroundTransparency = 0.5
	scrim.BorderSizePixel = 0
	scrim.Size = UDim2.fromScale(1, 1)
	scrim.ZIndex = 20
	scrim.Parent = page
	local box = Instance.new("TextButton") -- a button so clicks on it don't fall through to the scrim
	box.Text = ""
	box.AutoButtonColor = false
	box.BackgroundColor3 = PAPER
	box.BorderSizePixel = 0
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.45)
	box.Size = UDim2.fromOffset(BOX_WIDTH * u, BOX_HEIGHT * u)
	box.ZIndex = 21
	box.Parent = scrim
	round(box)
	local function close()
		scrim:Destroy()
	end
	scrim.Activated:Connect(close)

	CardFace.new(box, {
		cardId = listing.cardId,
		tier = listing.tier,
		variant = listing.variant,
		serial = listing.serial,
		width = BOX_CARD * u,
		position = UDim2.fromOffset(0.015 * u, 0.02 * u),
	})

	local left = BOX_CARD + 0.03
	local body: Frame? = nil
	local sending = false

	-- Draws the right-hand side from what is known: first the grid's entry, then the server's real answer.
	local function fill(known: any, info: any?, note: string?)
		if body then
			body:Destroy()
		end
		local made = Instance.new("Frame")
		made.BackgroundTransparency = 1
		made.Size = UDim2.fromScale(1, 1)
		made.ZIndex = 22
		made.Parent = box
		body = made

		local mine = (info and info.seller == player.UserId) or (CardData.get() and CardData.get().market.listed[known.id] ~= nil)
		local over = (info and info.closed) or known.endsAt - serverNow() <= 0
		PanelKit.label(made, "LabelBold", 0.02, left, 0.04):set(Market.credits(known.price))
		PanelKit.label(made, "Label", PanelKit.SMALL_SIZE, left, 0.054):set(if known.hasBid then "CURRENT BID" else "STARTING BID")
		timeLabel(made, BOX_WIDTH - 0.015, 0.04, known.endsAt)
		if info and info.sellerName then
			PanelKit.label(made, "Label", PanelKit.SMALL_SIZE, left, 0.068):set(`SOLD BY {string.upper(info.sellerName)}`)
		end
		local line = PanelKit.label(made, "Label", PanelKit.SMALL_SIZE, left, 0.165)
		line:set(note or "")

		if over then
			line:set(Market.refusal("Ended"))
			return
		elseif mine then
			PanelKit.label(made, "LabelBold", PanelKit.LABEL_SIZE, left, 0.095):set("YOUR LISTING")
			if not known.hasBid then
				button(made, "CANCEL", left, 0.11, 0.08, 0.024).Activated:Connect(function()
					if sending then
						return
					end
					sending = true
					line:set("...")
					local reply = CardData.ask("CancelListing", known.id)
					if not scrim.Parent then
						return
					end
					if reply.ok then
						close()
						task.spawn(fetch)
					else
						sending = false
						line:set(Market.refusal(reply.code))
					end
				end)
			end
			return
		end

		local least = if info then info.min else if known.hasBid then nil else known.price
		local entry = textBox(made, left, 0.082, 0.1, "YOUR BID", if least then tostring(least) else "")
		entry.ZIndex = 23
		local function send(amount: number)
			if sending then
				return
			end
			sending = true
			line:set("...")
			local reply = CardData.ask("PlaceBid", { id = known.id, amount = amount })
			if not scrim.Parent then
				return
			end
			if reply.ok then
				close()
				task.spawn(fetch)
				return
			end
			sending = false
			if reply.min then
				entry.Text = tostring(reply.min)
			end
			line:set(Market.refusal(reply.code, reply.min))
		end
		button(made, "BID", left + 0.108, 0.082, 0.06, BAR_HEIGHT).Activated:Connect(function()
			local amount = Market.parseAmount(entry.Text)
			if not amount or amount < 1 then
				line:set("ENTER A WHOLE NUMBER")
				return
			end
			send(amount)
		end)
		if known.buyNow then
			local buyNow = known.buyNow
			button(made, `BUY NOW {Market.credits(buyNow)}`, left, 0.114, 0.168, BAR_HEIGHT).Activated:Connect(function()
				send(buyNow)
			end)
		end
	end

	fill(listing, nil, nil)
	task.spawn(function()
		local reply = CardData.ask("AuctionInfo", listing.id)
		if not scrim.Parent or sending then
			return
		end
		if reply.ok then
			sync(reply)
			local real = Market.unpack(reply.auction) or listing
			fill(real, reply, nil)
		elseif reply.code == "Gone" then
			local ended = table.clone(listing)
			ended.endsAt = 0
			fill(ended, nil, nil)
		end
	end)
end

local function drawBrowse(body: Frame)
	local u = unit()
	local search = textBox(body, MARGIN, BAR_TOP, 0.2, "SEARCH", state.search)
	local sortWidth = 0.07
	local x = RIGHT - #SORTS * sortWidth - (#SORTS - 1) * 0.004
	for index, sort in SORTS do
		button(body, sort[2], x + (index - 1) * (sortWidth + 0.004), BAR_TOP, sortWidth, BAR_HEIGHT, { active = state.sort == sort[1], size = PanelKit.SMALL_SIZE }).Activated:Connect(function()
			state.sort = sort[1]
			draw()
		end)
	end

	local holder = frame(body, GRID_TOP)
	local function grid()
		holder:ClearAllChildren()
		table.clear(timers)
		local list = Market.visible(state.listings, state.search, state.sort, nameOf)
		if #list == 0 then
			local words = if not state.fetched then "LOADING" elseif #state.listings == 0 then "NOTHING FOR SALE YET" else "NO CARDS MATCH"
			message(holder, words, 0.02)
			return
		end
		local shown = math.min(#list, MAX_SHOWN)
		local top = 0
		if #list > shown then
			message(holder, `SHOWING {shown} OF {#list}. SEARCH TO NARROW IT DOWN.`, 0.012)
			top = 0.02
		end
		local scroll = scroller(holder, 0, math.ceil(shown / COLUMNS))
		scroll.CanvasSize = UDim2.fromOffset(0, (top + math.ceil(shown / COLUMNS) * ROW) * u)
		local snapshot = CardData.get()
		for index = 1, shown do
			local listing = list[index]
			local held = snapshot and snapshot.market.bids[listing.id]
			local winning = held ~= nil and listing.hasBid and held.amount == listing.price
			cell(scroll, index, top, { cardId = listing.cardId, tier = listing.tier, variant = listing.variant, serial = listing.serial }, {
				price = Market.credits(listing.price),
				endsAt = listing.endsAt,
				sub = if winning then "YOU ARE WINNING" elseif listing.buyNow then `BUY NOW {Market.credits(listing.buyNow)}` else nil,
				bold = winning,
			}, function()
				bidBox(listing)
			end)
		end
	end
	grid()
	state.redrawGrid = grid
	search:GetPropertyChangedSignal("Text"):Connect(function()
		state.search = search.Text
		grid()
	end)
end

-- The numbered stacks a player could sell from, lowest serial first.
local function sellable(snapshot: any): { any }
	local found = {}
	for key, serial in snapshot.lowest do
		local cardId, tier, variant = Inventory.parse(key)
		if cardId and Cards.byId[cardId] then
			table.insert(found, { cardId = cardId, tier = tier, variant = variant, serial = serial, copies = snapshot.stacks[key] or 1 })
		end
	end
	table.sort(found, function(a, b)
		if a.serial ~= b.serial then
			return a.serial < b.serial
		end
		return Inventory.key(a.cardId, a.tier, a.variant) < Inventory.key(b.cardId, b.tier, b.variant)
	end)
	return found
end

local function drawSellForm(body: Frame, card: any)
	local u = unit()
	CardFace.new(body, {
		cardId = card.cardId,
		tier = card.tier,
		variant = card.variant,
		serial = card.serial,
		width = BOX_CARD * u,
		position = UDim2.fromOffset(MARGIN * u, BAR_TOP * u),
	})
	button(body, "CHANGE CARD", MARGIN, BAR_TOP + BOX_CARD * 1.6 + 0.008, BOX_CARD, BAR_HEIGHT, { size = PanelKit.SMALL_SIZE }).Activated:Connect(function()
		state.selling = nil
		draw()
	end)

	local left = MARGIN + BOX_CARD + 0.025
	PanelKit.label(body, "Label", PanelKit.SMALL_SIZE, left, BAR_TOP + 0.008):set("STARTING BID")
	local start = textBox(body, left, BAR_TOP + 0.012, 0.1, "100", "")
	PanelKit.label(body, "Label", PanelKit.SMALL_SIZE, left, BAR_TOP + 0.052):set("BUY NOW (OPTIONAL)")
	local buyNow = textBox(body, left, BAR_TOP + 0.056, 0.1, "NONE", "")
	PanelKit.label(body, "Label", PanelKit.SMALL_SIZE, left, BAR_TOP + 0.096):set("LENGTH")
	local lengths = frame(body, 0)
	local function drawLengths()
		lengths:ClearAllChildren()
		for index, hours in LENGTHS do
			button(lengths, `{hours}H`, left + (index - 1) * 0.044, BAR_TOP + 0.1, 0.04, BAR_HEIGHT, { active = state.hours == hours }).Activated:Connect(function()
				state.hours = hours
				drawLengths()
			end)
		end
	end
	drawLengths()
	PanelKit.label(body, "Label", PanelKit.SMALL_SIZE, left, BAR_TOP + 0.142):set("YOU GET THE FULL PRICE. THE CARD LEAVES YOUR")
	PanelKit.label(body, "Label", PanelKit.SMALL_SIZE, left, BAR_TOP + 0.154):set("COLLECTION UNTIL IT SELLS OR COMES BACK.")
	local line = PanelKit.label(body, "Label", PanelKit.SMALL_SIZE, left, BAR_TOP + 0.205)
	local sending = false
	button(body, "LIST FOR AUCTION", left, BAR_TOP + 0.165, 0.13, 0.026).Activated:Connect(function()
		if sending then
			return
		end
		local startBid = Market.parseAmount(start.Text)
		local buyText = string.gsub(buyNow.Text, "%s", "")
		local buy = if buyText == "" then nil else Market.parseAmount(buyNow.Text)
		if not startBid or startBid < 1 or (buyText ~= "" and not buy) then
			line:set("ENTER A WHOLE NUMBER")
			return
		end
		sending = true
		line:set("...")
		local page = state.page
		local reply = CardData.ask("ListCard", {
			cardId = card.cardId,
			tier = card.tier,
			variant = card.variant,
			serial = card.serial,
			startBid = startBid,
			hours = state.hours,
			buyNow = buy,
		})
		if state.page ~= page or not body.Parent then
			return
		end
		if reply.ok then
			state.selling = nil
			state.tab = "MINE"
			draw()
			task.spawn(fetch)
		else
			sending = false
			line:set(Market.refusal(reply.code))
		end
	end)
end

local function drawSell(body: Frame)
	local snapshot = CardData.get()
	if state.selling then
		drawSellForm(body, state.selling)
		return
	end
	local stacks = if snapshot then sellable(snapshot) else {}
	if #stacks == 0 then
		message(body, "YOU HAVE NO NUMBERED CARDS TO SELL", BAR_TOP + 0.02)
		return
	end
	message(body, "PICK A CARD TO SELL", BAR_TOP + 0.012)
	local shown = math.min(#stacks, MAX_SHOWN)
	local scroll = scroller(body, BAR_TOP + 0.024, math.ceil(shown / COLUMNS))
	local picking = false
	for index = 1, shown do
		local stack = stacks[index]
		cell(scroll, index, 0, { cardId = stack.cardId, tier = stack.tier, variant = stack.variant, serial = stack.serial }, {
			sub = if stack.copies > 1 then `{stack.copies} COPIES` else nil,
		}, function()
			if picking then
				return
			end
			if stack.copies <= 1 then
				state.selling = stack
				draw()
				return
			end
			-- Several copies: ask which serials there are, and let the player choose one.
			picking = true
			local page = state.page
			local reply = CardData.ask("MySerials", { cardId = stack.cardId, tier = stack.tier, variant = stack.variant })
			if state.page ~= page or not body.Parent then
				return
			end
			picking = false
			local serials = if reply.ok then reply.serials else { stack.serial }
			if #serials <= 1 then
				state.selling = stack
				draw()
				return
			end
			body:ClearAllChildren()
			message(body, `WHICH {string.upper(nameOf(stack.cardId))}?`, BAR_TOP + 0.012)
			local perRow, width = 8, 0.05
			for place, serial in serials do
				local column, row = (place - 1) % perRow, (place - 1) // perRow
				local text = if CardLook.isLowSerial(serial) then CardLook.lowSerialText(serial) else CardLook.faceSerial(serial)
				button(body, text, MARGIN + column * (width + 0.004), BAR_TOP + 0.024 + row * (BAR_HEIGHT + 0.004), width, BAR_HEIGHT).Activated:Connect(function()
					local chosen = table.clone(stack)
					chosen.serial = serial
					state.selling = chosen
					draw()
				end)
			end
		end)
	end
end

local function drawMine(body: Frame)
	local snapshot = CardData.get()
	local market = snapshot and snapshot.market
	if not market or (next(market.listed) == nil and next(market.bids) == nil) then
		message(body, "YOU HAVE NOTHING IN THE MARKET", BAR_TOP + 0.02)
		return
	end
	local byId = {}
	for _, listing in state.listings do
		byId[listing.id] = listing
	end
	local scroll = scroller(body, BAR_TOP, 4)
	local top = 0.014
	local function section(title: string, ids: { string }, each: (string) -> (any?, any))
		if #ids == 0 then
			return
		end
		table.sort(ids)
		PanelKit.label(scroll, "LabelBold", PanelKit.HEADING_SIZE, MARGIN, top):set(title)
		top += 0.008
		local drawn = 0
		for _, id in ids do
			local card, lines = each(id)
			if card then
				drawn += 1
				cell(scroll, drawn, top, card, lines, function()
					bidBox(byId[id] or {
						id = id,
						cardId = card.cardId,
						tier = card.tier,
						variant = card.variant,
						serial = card.serial,
						price = lines.amount,
						endsAt = lines.endsAt,
						hasBid = false,
					})
				end)
			end
		end
		top += math.ceil(drawn / COLUMNS) * ROW + 0.014
	end

	local listed, bids = {}, {}
	for id in market.listed do
		table.insert(listed, id)
	end
	for id in market.bids do
		table.insert(bids, id)
	end
	section("YOUR LISTINGS", listed, function(id: string)
		local mine = market.listed[id]
		local live = byId[id]
		local price = if live and live.hasBid then Market.credits(live.price) else "NO BIDS"
		return { cardId = mine.cardId, tier = mine.tier, variant = mine.variant, serial = mine.serial },
			{ price = price, endsAt = if live then live.endsAt else mine.endsAt, amount = mine.startBid }
	end)
	section("YOUR BIDS", bids, function(id: string)
		local held = market.bids[id]
		local live = byId[id]
		if not live then
			return nil, {} -- past the list's ceiling, or just ended: it settles on its own
		end
		local winning = live.price == held.amount
		return { cardId = live.cardId, tier = live.tier, variant = live.variant, serial = live.serial },
			{ price = Market.credits(held.amount), endsAt = live.endsAt, sub = if winning then "WINNING" else "OUTBID", bold = winning, amount = held.amount }
	end)
	scroll.CanvasSize = UDim2.fromOffset(0, top * unit())
end

draw = function()
	local page = state.page
	if not page or not page.Parent then
		return
	end
	page:ClearAllChildren()
	table.clear(timers)
	state.redrawGrid = nil
	state.creditsLabel = nil
	local snapshot = CardData.get()
	local mine = 0
	if snapshot then
		for _ in snapshot.market.listed do
			mine += 1
		end
		for _ in snapshot.market.bids do
			mine += 1
		end
	end
	local x = MARGIN
	for _, tab in TABS do
		local text = if tab == "MINE" and mine > 0 then `MINE · {mine}` else tab
		local width = if tab == "MINE" then 0.07 else 0.06
		button(page, text, x, TAB_TOP, width, BAR_HEIGHT, { active = state.tab == tab }).Activated:Connect(function()
			state.tab = tab
			draw()
		end)
		x += width + 0.004
	end
	if snapshot then
		local credits = PanelKit.label(page, "LabelBold", PanelKit.LABEL_SIZE, RIGHT, TAB_TOP + 0.016, true)
		credits:set(`CREDITS {Market.credits(math.floor(snapshot.credits))}`)
		state.creditsLabel = credits
	end
	PanelKit.rule(page, MARGIN, 0.034, RIGHT - MARGIN)

	local body = frame(page, 0)
	if state.tab == "BROWSE" then
		drawBrowse(body)
	elseif state.tab == "SELL" then
		drawSell(body)
	else
		drawMine(body)
	end
end

function MarketPanel.stop()
	state.page = nil
	if changed then
		changed:Disconnect()
		changed = nil
	end
	table.clear(timers)
end

function MarketPanel.fill(page: Frame)
	MarketPanel.stop()
	state.page = page
	state.selling = nil
	draw()

	-- Your own listings, bids and Credits change under you: outbid, sold, paid.
	local last: string? = nil
	changed = CardData.changed:Connect(function()
		local snapshot = CardData.get()
		if not snapshot or state.page ~= page then
			return
		end
		-- Credits tick up every second from income: only the number changes for that, never the page.
		if state.creditsLabel then
			state.creditsLabel:set(`CREDITS {Market.credits(math.floor(snapshot.credits))}`)
		end
		local parts = {}
		for id in snapshot.market.listed do
			table.insert(parts, id)
		end
		for id, held in snapshot.market.bids do
			table.insert(parts, id .. held.amount)
		end
		table.sort(parts)
		local now = table.concat(parts, "|")
		local moved = now ~= last
		last = now
		-- What you have in the market changed. SELL is left alone: it may be half filled in.
		if moved and state.tab ~= "SELL" and not page:FindFirstChild("BidBox") then
			draw()
		end
	end)

	task.spawn(function()
		while state.page == page and page.Parent do
			fetch()
			local waited = 0
			while waited < REFRESH and state.page == page and page.Parent do
				task.wait(1)
				waited += 1
				for _, timer in timers do
					local text, urgent = Market.timeLeft(timer.endsAt - serverNow())
					timer.label:set(text)
					timer.label:setColor(if urgent then Palette.HazardRed else INK)
				end
			end
		end
	end)
end

return MarketPanel
