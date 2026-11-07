-- The Loadout page: the player's Deck Power Rating, three card slots, and class and rifle.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CardCore = ReplicatedStorage:WaitForChild("CardCore")
local CardIndex = require(CardCore:WaitForChild("CardIndex"))
local Cards = require(CardCore:WaitForChild("Cards"))
local Deck = require(CardCore:WaitForChild("Deck"))
local Guns = ReplicatedStorage:WaitForChild("Guns")
local GunConfig = require(Guns:WaitForChild("GunConfig"))
local Palette = require(Guns:WaitForChild("Palette"))
local CardData = require(script.Parent.CardData)
local PanelKit = require(script.Parent.PanelKit)

local TIER_NAMES = { Field = "FIELD", BlackSite = "BLACK SITE", Prototype = "PROTOTYPE" }
local CLASS_NAMES = { Assault = "ASSAULT", Rusher = "RUSHER", Marksman = "MARKSMAN", Breacher = "BREACHER" }

local SLOTS_LINE = 0.128
local SLOT_TOP = 0.14
local SLOT_WIDTH = 0.107 -- a playing card's shape, with SLOT_HEIGHT
local SLOT_HEIGHT = 0.15
local SLOT_GAP = 0.01
local SLOT_MARGIN = 0.01 -- inside a card, on all four sides
local SLOT_NUMBER = 0.02
local POWER_SIZE = 0.034
local LOWER_LINE = 0.31
local LOWER_TOP = 0.322
local PICK_HEIGHT = 0.026
local PICK_GAP = 0.004
local CLASS_GAP = 0.008
local RIFLE_LINE = 0.375
local RIFLE_TOP = 0.387
local GUNS_LINE = 0.375
local NEXT_RESPAWN = "NEXT RESPAWN"

local LoadoutPanel = {}

local function gunName(id: string): string
	return string.upper(GunConfig.guns[id].name)
end

local draw: (Frame, number?) -> ()

local function slotCell(content: Frame, snapshot: any, index: number, chosen: number?)
	local entry = snapshot.deck[index]
	local width = SLOT_WIDTH
	local x = PanelKit.MARGIN + (index - 1) * (width + SLOT_GAP)
	local cell = PanelKit.button(content, "", x, SLOT_TOP, width, SLOT_HEIGHT, { active = index == chosen, quiet = true })
	local numberLine = SLOT_MARGIN + SLOT_NUMBER * PanelKit.CAP_HEIGHT
	local tierLine = SLOT_HEIGHT - SLOT_MARGIN
	PanelKit.cardLabel(cell, "Title", SLOT_NUMBER, SLOT_MARGIN, numberLine):set(tostring(index))
	PanelKit.cardLabel(cell, "LabelBold", PanelKit.SMALL_SIZE, SLOT_MARGIN, tierLine - 0.015)
		:set(string.upper(Cards.byId[entry.cardId].name))
	PanelKit.cardLabel(cell, "Label", PanelKit.SMALL_SIZE, SLOT_MARGIN, tierLine):set(TIER_NAMES[entry.tier])
	cell.Activated:Connect(function()
		draw(content, if index == chosen then nil else index)
	end)
end

local function picker(content: Frame, snapshot: any, slot: number)
	local MARGIN, RIGHT = PanelKit.MARGIN, PanelKit.RIGHT
	PanelKit.heading(content, `CHOOSE FOR SLOT {slot}`, LOWER_LINE)
	local width = (RIGHT - MARGIN - PICK_GAP) / 2
	for index, card in CardIndex.owned(snapshot.stacks) do
		local row = math.floor((index - 1) / 2)
		local x = MARGIN + (index - 1) % 2 * (width + PICK_GAP)
		local top = LOWER_TOP + row * (PICK_HEIGHT + PICK_GAP)
		local swapped = Deck.swap(snapshot.deck, slot, card.cardId, card.tier)
		local name = `{string.upper(card.name)} {TIER_NAMES[card.tier]}`
		local button = PanelKit.button(content, name, x, top, width, PICK_HEIGHT, {
			disabled = swapped == nil,
			size = PanelKit.SMALL_SIZE,
		})
		button.Activated:Connect(function()
			if swapped then
				task.spawn(function()
					CardData.setDeck(swapped)
					if content.Parent then
						draw(content, nil)
					end
				end)
			end
		end)
	end
end

local function sendLoadout(content: Frame, snapshot: any, class: string, rifle: string)
	snapshot.class, snapshot.rifle = class, rifle
	ReplicatedStorage:WaitForChild("GunRemotes"):WaitForChild("SetLoadout"):FireServer({ class = class, rifle = rifle })
	draw(content, nil)
end

local function loadoutRows(content: Frame, snapshot: any)
	local MARGIN, RIGHT = PanelKit.MARGIN, PanelKit.RIGHT
	PanelKit.heading(content, "CLASS", LOWER_LINE)
	local count = #GunConfig.classOrder
	local width = (RIGHT - MARGIN - CLASS_GAP * (count - 1)) / count
	for index, class in GunConfig.classOrder do
		local x = MARGIN + (index - 1) * (width + CLASS_GAP)
		local button = PanelKit.button(content, CLASS_NAMES[class], x, LOWER_TOP, width, PICK_HEIGHT, {
			active = class == snapshot.class,
			size = PanelKit.SMALL_SIZE,
		})
		button.Activated:Connect(function()
			sendLoadout(content, snapshot, class, snapshot.rifle)
		end)
	end

	local kit = GunConfig.classes[snapshot.class]
	if #kit.primaries > 1 then
		PanelKit.heading(content, "RIFLE", RIFLE_LINE)
		for index, rifle in kit.primaries do
			local x = MARGIN + (index - 1) * (width + CLASS_GAP)
			local button = PanelKit.button(content, gunName(rifle), x, RIFLE_TOP, width, PICK_HEIGHT, {
				active = rifle == snapshot.rifle,
				size = PanelKit.SMALL_SIZE,
			})
			button.Activated:Connect(function()
				sendLoadout(content, snapshot, snapshot.class, rifle)
			end)
		end
	end

	local primary = if #kit.primaries > 1 then snapshot.rifle else kit.primaries[1]
	PanelKit.heading(content, "GUNS", GUNS_LINE)
	PanelKit.line(content, `{gunName(primary)} + {gunName(kit.sidearm)}`, RIGHT, GUNS_LINE, true)
end

local function waiting(snapshot: any): boolean
	local player = Players.LocalPlayer
	return CardData.deckWaiting()
		or player:GetAttribute("Class") ~= snapshot.class
		or player:GetAttribute("Rifle") ~= snapshot.rifle
end

draw = function(content: Frame, chosen: number?)
	local MARGIN, RIGHT = PanelKit.MARGIN, PanelKit.RIGHT
	content:ClearAllChildren()
	PanelKit.title(content, "LOAD OUT")
	local snapshot = CardData.get()
	if not snapshot then
		PanelKit.line(content, "LOADING", MARGIN, SLOT_TOP + 0.02)
		local arrived
		arrived = CardData.changed:Connect(function()
			arrived:Disconnect()
			if content.Parent then
				draw(content, nil)
			end
		end)
		return
	end

	local blockLeft = MARGIN + Deck.SIZE * (SLOT_WIDTH + SLOT_GAP)
	local block = PanelKit.block(content, blockLeft, SLOT_TOP, RIGHT - blockLeft, SLOT_HEIGHT, PanelKit.NAVY)
	PanelKit.label(block, "LabelBold", PanelKit.SMALL_SIZE, 0.008, 0.02, nil, Palette.Bone):set("DECK")
	PanelKit.label(block, "LabelBold", PanelKit.SMALL_SIZE, 0.008, 0.034, nil, Palette.Bone):set("POWER")
	PanelKit.label(block, "Title", POWER_SIZE, 0.008, SLOT_HEIGHT - 0.01, nil, Palette.Bone):set(tostring(snapshot.dpr))

	PanelKit.heading(content, "CARDS", SLOTS_LINE)
	local note = PanelKit.label(content, "LabelBold", PanelKit.HEADING_SIZE, RIGHT, SLOTS_LINE, true)
	note:set(if waiting(snapshot) then NEXT_RESPAWN else "")
	local connection
	connection = CardData.changed:Connect(function()
		if not content.Parent or not note.frame.Parent then
			connection:Disconnect()
			return
		end
		local latest = CardData.get()
		note:set(if latest and waiting(latest) then NEXT_RESPAWN else "")
	end)

	for index = 1, Deck.SIZE do
		slotCell(content, snapshot, index, chosen)
	end
	if chosen then
		picker(content, snapshot, chosen)
	else
		loadoutRows(content, snapshot)
	end
end

function LoadoutPanel.fill(content: Frame)
	draw(content, nil)
end

return LoadoutPanel
