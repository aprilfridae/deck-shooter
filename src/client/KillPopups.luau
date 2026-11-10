-- The lines that pop up beside the crosshair when you get a kill: what you did and what it paid, newest on top,
-- with a total counting up above them. The server decides the lines and the Credits (KillReward); this only draws
-- them. Timings are in KillPopupTiming. See docs/specs/kill-rewards.md.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local Palette = require(Guns:WaitForChild("Palette"))
local Timing = require(Guns:WaitForChild("Hud"):WaitForChild("KillPopupTiming"))
local TypeLabel = require(script.Parent.TypeLabel)

-- In the HUD's own units, from the middle of the screen.
local LEFT = 46 -- where the lines start, right of the crosshair
local TOP = 6 -- the newest line's baseline, below the crosshair's level
local ROW = 19 -- from one line's baseline to the next
local AMOUNT_AT = 190 -- where the amounts start, from LEFT
local LINE_STYLE, LINE_SIZE, LINE_TRACKING = "LabelBold", 12, 2
local TOTAL_STYLE, TOTAL_SIZE, TOTAL_TRACKING = "LabelBold", 18, 2
local TOTAL_RISE = 22 -- the total's baseline, above the newest line's
local SLIDE = 18 -- how fast lines slide down to make room, a second
local NAME_COLOR = Palette.Bone
local AMOUNT_COLOR = Palette.SignalAcid

-- A sound for each kind of line, by its id (kill, headshot, oneShot, longShot, collateral, spree, rampage,
-- unstoppable). None yet: River adds them here.
local SOUNDS: { [string]: () -> () } = {}

local KillPopups = {}

type Shown = { holder: Frame, scale: UIScale, name: any, amount: any, bornAt: number, row: number }

-- The HUD's type has no comma, so amounts are plain digits.
local function withCommas(amount: number): string
	return tostring(math.floor(amount))
end

local function fade(label: any, transparency: number)
	for _, image in label.frame:GetChildren() do
		if image:IsA("ImageLabel") then
			image.ImageTransparency = transparency
		end
	end
end

-- hud is the HUD's scaled frame. Starts listening for rewards.
function KillPopups.start(hud: Frame, rewardRemote: RemoteEvent)
	local shown: { Shown } = {} -- newest first
	local total = TypeLabel.new(hud, {
		style = TOTAL_STYLE,
		size = TOTAL_SIZE,
		tracking = TOTAL_TRACKING,
		color = AMOUNT_COLOR,
		position = UDim2.new(0.5, LEFT, 0.5, TOP - TOTAL_RISE),
	})
	total:setVisible(false)
	local totalFrom, totalTo, totalAt = 0, 0, -math.huge

	local function addLine(line: any, bornAt: number)
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromOffset(0, 0)
		holder.Position = UDim2.new(0.5, LEFT, 0.5, TOP)
		holder.Parent = hud
		local scale = Instance.new("UIScale")
		scale.Parent = holder
		local name = TypeLabel.new(holder, {
			style = LINE_STYLE,
			size = LINE_SIZE,
			tracking = LINE_TRACKING,
			color = NAME_COLOR,
			position = UDim2.fromOffset(0, 0),
		})
		name:set(line.name)
		local amount = TypeLabel.new(holder, {
			style = LINE_STYLE,
			size = LINE_SIZE,
			tracking = LINE_TRACKING,
			color = AMOUNT_COLOR,
			position = UDim2.fromOffset(AMOUNT_AT, 0),
		})
		amount:set(if line.amount then "+" .. withCommas(line.amount) else "")
		fade(name, 1)
		fade(amount, 1)
		table.insert(shown, 1, { holder = holder, scale = scale, name = name, amount = amount, bornAt = bornAt, row = 0 })
		while #shown > Timing.MOST do
			table.remove(shown).holder:Destroy()
		end
		local sound = SOUNDS[line.id]
		if sound then
			task.delay(math.max(bornAt - os.clock(), 0), sound)
		end
	end

	rewardRemote.OnClientEvent:Connect(function(lines: any, paid: number)
		local now = os.clock()
		-- One shot's lines land one after another, the kill first, so the last of them ends up on top.
		for index, line in lines do
			addLine(line, now + (index - 1) * Timing.STAGGER)
		end
		if paid > 0 then
			-- It counts on from whatever it's showing.
			local showing = Timing.total(totalFrom, totalTo, now - totalAt)
			totalFrom, totalTo, totalAt = showing, totalTo + paid, now
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		local row = 0
		for index = #shown, 1, -1 do
			local line = shown[index]
			local size, transparency, alive = Timing.line(now - line.bornAt)
			if not alive then
				line.holder:Destroy()
				table.remove(shown, index)
			else
				line.scale.Scale = size
				fade(line.name, transparency)
				fade(line.amount, transparency)
			end
		end
		-- Newest on top; the rest slide down a row at a time. A line still waiting its turn takes no row.
		for _, line in shown do
			if now >= line.bornAt then
				line.row += (row - line.row) * math.min(dt * SLIDE, 1)
				row += 1
			end
			line.holder.Position = UDim2.new(0.5, LEFT, 0.5, TOP + line.row * ROW)
		end
		local quiet = now - totalAt
		if totalTo > 0 and Timing.cleared(quiet) and #shown == 0 then
			totalFrom, totalTo = 0, 0
		end
		total:setVisible(totalTo > 0)
		if totalTo > 0 then
			total:set("+" .. withCommas(Timing.total(totalFrom, totalTo, quiet)) .. " CR")
		end
	end)
end

return KillPopups
