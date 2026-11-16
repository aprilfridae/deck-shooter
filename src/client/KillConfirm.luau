-- What the killer feels on a kill: a punch. The picture kicks up in contrast and colour for an instant, and the
-- edges of the screen flash Signal Acid, the colour of the coins on their way in. Each kill in a life makes it
-- bigger, up to a cap, and raises the kill sound a semitone. Dying or respawning starts the count again. Numbers
-- are in KillFx. Hud calls kill(). (It also snapped the view in a few degrees until River had that taken out,
-- 2026-11-15.)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local Palette = require(Guns:WaitForChild("Palette"))
local KillFx = require(Guns:WaitForChild("KillFx"))

local EDGE_COLOR = Palette.SignalAcid
local EDGE_DEPTH = 0.16 -- of the screen, how far in from each edge the flash reaches
local EDGE_PEAK = 0.45 -- how solid the flash is at the edge on a first kill
local EDGE_TOP = 0.9 -- and at most, however long the streak
local HEADSHOT_EDGE = 1.7 -- a headshot's flash is this much stronger
local CONTRAST = 0.3 -- the picture's kick at the peak of a first kill
local SATURATION = 0.35
local BRIGHTNESS = 0.05

local KillConfirm = {}

local player = Players.LocalPlayer
local streak = 0
local punchAt = -math.huge
local punchSize = 0
local edgeSize = 0
local headshotAt = -math.huge
local clock = 0 -- runs slow with workspace's KillFxSpeed attribute, as KillDerez's does

local gui = Instance.new("ScreenGui")
gui.Name = "KillConfirm"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = -1 -- under the HUD
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Four glows, one on each edge, solid at the edge and clear by EDGE_DEPTH in. rotation turns the gradient so it
-- runs from that edge inward.
local edges: { UIGradient } = {}
for _, edge in {
	{ size = UDim2.fromScale(1, EDGE_DEPTH), position = UDim2.fromScale(0, 0), rotation = 90 },
	{ size = UDim2.fromScale(1, EDGE_DEPTH), position = UDim2.fromScale(0, 1 - EDGE_DEPTH), rotation = -90 },
	{ size = UDim2.fromScale(EDGE_DEPTH * 0.6, 1), position = UDim2.fromScale(0, 0), rotation = 0 },
	{ size = UDim2.fromScale(EDGE_DEPTH * 0.6, 1), position = UDim2.fromScale(1 - EDGE_DEPTH * 0.6, 0), rotation = 180 },
} do
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = EDGE_COLOR
	frame.Size = edge.size
	frame.Position = edge.position
	frame.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = edge.rotation
	gradient.Parent = frame
	table.insert(edges, gradient)
end

local function setEdges(solid: number)
	local sequence = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1 - solid),
		NumberSequenceKeypoint.new(0.35, 1 - solid * 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	for _, gradient in edges do
		gradient.Transparency = sequence
	end
end

local tint: ColorCorrectionEffect? = nil

local function stop()
	gui.Enabled = false
	if tint then
		tint:Destroy()
		tint = nil
	end
end

-- Call on each kill you make. Returns how fast to play the kill sound.
function KillConfirm.kill(headshot: boolean): number
	streak += 1
	local scale = KillFx.streakScale(streak)
	punchAt = clock
	if headshot then
		headshotAt = clock
	end
	punchSize = scale
	edgeSize = math.min(EDGE_PEAK * scale * (if headshot then HEADSHOT_EDGE else 1), EDGE_TOP)
	if not tint or not tint.Parent then
		local effect = Instance.new("ColorCorrectionEffect")
		effect.Name = "KillPunch"
		effect.Parent = workspace.CurrentCamera
		tint = effect
	end
	gui.Enabled = true
	return KillFx.killPitch(streak)
end

-- Kills so far this life.
function KillConfirm.streak(): number
	return streak
end

RunService.RenderStepped:Connect(function(dt)
	local speed = workspace:GetAttribute("KillFxSpeed")
	clock += dt * (if type(speed) == "number" and speed > 0 then speed else 1)
	if not gui.Enabled then
		return
	end
	local punch = KillFx.punch(clock - punchAt)
	if punch <= 0 and clock - punchAt > KillFx.PUNCH_ATTACK then
		stop()
		return
	end
	-- The edges hang on a little longer than the rest.
	setEdges(edgeSize * math.sqrt(punch))
	local effect = tint
	if effect then
		-- A headshot opens on a moment of hard contrast, nearly black and white.
		local contrast, saturation = KillFx.impact(clock - headshotAt)
		effect.Contrast = contrast or CONTRAST * punchSize * punch
		effect.Saturation = saturation or SATURATION * punchSize * punch
		effect.Brightness = BRIGHTNESS * punchSize * punch
	end
end)

local function onCharacter(character: Model)
	streak = 0
	stop()
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		humanoid.Died:Once(function()
			streak = 0
		end)
	end
end

player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end

return KillConfirm
