-- The kill feed, top right (docs/specs/hud-redesign.md): every kill on the server as "killer (gun) victim", like
-- Counter-Strike's. The server sends the names; the list's rules are in Guns.Hud.KillFeed. This only draws it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local Palette = require(Guns:WaitForChild("Palette"))
local Hud = Guns:WaitForChild("Hud")
local HudShapes = require(Hud:WaitForChild("HudShapes"))
local HudText = require(Hud:WaitForChild("HudText"))
local KillFeed = require(Hud:WaitForChild("KillFeed"))
local TypeLabel = require(script.Parent.TypeLabel)

-- In the HUD's own units, on a 720-tall screen.
local MARGIN = 32 -- from the screen's right edge, as the rest of the HUD
local TOP = 28
local ROW = 24 -- from one line's top to the next
local HEIGHT = 20
local WIDTH = 520 -- room for two full names
local PAD = 8 -- inside a line's strip, left and right
local TEXT_SIZE = 12
local TRACKING = 2
local ICON_HEIGHT = 12
local ICON_WIDTH = ICON_HEIGHT * HudShapes.GUN_RATIO
local ICON_GAP = 8 -- between the gun and each name
local ICON_IMAGE = Vector2.new(96, 64) -- the gun image's size in pixels, for mirroring it
local GREY = Color3.fromRGB(170, 176, 182)
local STRIP_FADE = 0.5 -- how see-through the strip behind your own lines is

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "KillFeed"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 3 -- above the HUD and the radio, under the Outpost's menu pages
gui.Parent = player:WaitForChild("PlayerGui")

local root = Instance.new("Frame")
root.BackgroundTransparency = 1
root.Parent = gui
local scale = Instance.new("UIScale")
scale.Parent = root
local function fit()
	local size = HudText.scale(gui.AbsoluteSize.Y)
	scale.Scale = size
	root.Size = UDim2.fromScale(1 / size, 1 / size)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
fit()

local list: { KillFeed.Entry } = {}
local rows: { [KillFeed.Entry]: CanvasGroup } = {}

local function build(entry: KillFeed.Entry): CanvasGroup
	local color = if entry.mine then Palette.Bone else GREY
	local row = Instance.new("CanvasGroup")
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(1, 0)
	row.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	row.Parent = root

	local function name(text: string, right: number): any
		local label = TypeLabel.new(row, {
			style = "LabelBold",
			size = TEXT_SIZE,
			tracking = TRACKING,
			color = color,
			right = true,
			shadow = not entry.mine, -- the strip does the same job
			position = UDim2.new(1, -right, 0, (HEIGHT + TEXT_SIZE) / 2),
		})
		label:set(text)
		return label
	end
	local victim = name(entry.victim, PAD)
	local iconRight = PAD + victim:width() + ICON_GAP
	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	icon.Image = HudShapes.Gun
	icon.ImageColor3 = color
	-- The image points left. Drawn right to left, it points at the victim.
	icon.ImageRectOffset = Vector2.new(ICON_IMAGE.X, 0)
	icon.ImageRectSize = Vector2.new(-ICON_IMAGE.X, ICON_IMAGE.Y)
	icon.AnchorPoint = Vector2.new(1, 0.5)
	icon.Position = UDim2.new(1, -iconRight, 0.5, 0)
	icon.Size = UDim2.fromOffset(ICON_WIDTH, ICON_HEIGHT)
	icon.ZIndex = 2
	icon.Parent = row
	local killer = name(entry.killer, iconRight + ICON_WIDTH + ICON_GAP)

	if entry.mine then
		local strip = Instance.new("Frame")
		strip.BackgroundColor3 = Palette.DeepNavy
		strip.BackgroundTransparency = STRIP_FADE
		strip.BorderSizePixel = 0
		strip.AnchorPoint = Vector2.new(1, 0)
		strip.Position = UDim2.fromScale(1, 0)
		strip.Size = UDim2.new(0, iconRight + ICON_WIDTH + ICON_GAP + killer:width() + PAD, 1, 0)
		strip.ZIndex = 0
		strip.Parent = row
	end
	return row
end

-- Puts each line in its place, oldest at the top, and clears away the rows of lines that have gone.
local function arrange()
	local live = {}
	for index, entry in list do
		live[entry] = true
		local row = rows[entry]
		if not row then
			row = build(entry)
			rows[entry] = row
		end
		row.Position = UDim2.new(1, -MARGIN + PAD, 0, TOP + (index - 1) * ROW)
	end
	for entry, row in rows do
		if not live[entry] then
			row:Destroy()
			rows[entry] = nil
		end
	end
end

local remote = ReplicatedStorage:WaitForChild("GunRemotes"):WaitForChild("KillFeed") :: RemoteEvent
remote.OnClientEvent:Connect(function(killerId: any, killerName: any, victimId: any, victimName: any)
	local killer, victim = KillFeed.clean(killerName), KillFeed.clean(victimName)
	if not killer or not victim then
		return
	end
	local mine = killerId == player.UserId or victimId == player.UserId
	KillFeed.push(list, { killer = killer, victim = victim, mine = mine }, os.clock())
	arrange()
end)

RunService.RenderStepped:Connect(function()
	if #list == 0 then
		return
	end
	local now = os.clock()
	if KillFeed.prune(list, now) then
		arrange()
	end
	for _, entry in list do
		rows[entry].GroupTransparency = KillFeed.fade(entry, now)
	end
end)
