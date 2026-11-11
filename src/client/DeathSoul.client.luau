-- Dying knocks your soul out of your body. The camera is shoved out the way the shot was going, floats up and
-- back and turns to look at the body it left, the picture drains to grey, and YOU DIED comes up. It lasts until
-- you respawn. (River's idea, 2026-11-10.)
-- The server says where each death was and who did it (the DeathBurst remote, also used for the coin burst);
-- the push runs from the killer through you. With no killer known (a fall, a reset) it goes straight back.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local Palette = require(Guns:WaitForChild("Palette"))
local TypeLabel = require(script.Parent.TypeLabel)

local PUSH = 15 -- studs the soul is knocked back
local LIFT = 5 -- and up
local PUSH_EASE = 2.6 -- how fast it gets there: quick at first, then drifting
local TURN_EASE = 2.2 -- how fast it turns to look back at the body
local FOLLOW_EASE = 4 -- how fast the look follows the body as it falls. The body moves in jolts; the look mustn't
local TEXT_HEIGHT = 0.075 -- of the screen's height
local TEXT_TRACKING = 0.12 -- of the text's size
local DRIFT = 0.6 -- studs a second it keeps floating up afterwards
local SOUL_FOV = 82
local FOV_EASE = 3
local GREY_SECONDS = 0.7
local TEXT_DELAY = 0.45
local TEXT_FADE = 0.6
local NEAR_BODY = 6 -- a reported death this close to you is yours
local RECENT = 1 -- seconds a reported death stays worth matching
local STEP_NAME = "DeckDeathSoul"

local player = Players.LocalPlayer
local deathRemote = ReplicatedStorage:WaitForChild("GunRemotes"):WaitForChild("DeathBurst") :: RemoteEvent

type Soul = {
	startedAt: number,
	from: CFrame,
	body: BasePart,
	lookAt: Vector3, -- the eased point on the body the soul looks at
	push: Vector3, -- where it ends up, from where it started
	character: Model,
}

local soul: Soul? = nil
local lastDeath: { at: Vector3, killer: Player?, time: number }? = nil
local grey: ColorCorrectionEffect? = nil
local gui: ScreenGui? = nil

-- The way the shot was going: from the killer through the body, flat. Straight back if nobody is known.
local function pushDirection(body: BasePart, look: Vector3): Vector3
	local death = lastDeath
	if death and os.clock() - death.time < RECENT and (death.at - body.Position).Magnitude < NEAR_BODY then
		local killerRoot = death.killer and death.killer.Character and death.killer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if killerRoot and death.killer ~= player then
			local away = body.Position - killerRoot.Position
			local flat = Vector3.new(away.X, 0, away.Z)
			if flat.Magnitude > 0.5 then
				return flat.Unit
			end
		end
	end
	local back = Vector3.new(-look.X, 0, -look.Z)
	return if back.Magnitude > 0.01 then back.Unit else Vector3.zAxis
end

-- How far the soul can go that way before a wall or the roof.
local function clearPush(from: Vector3, direction: Vector3, character: Model): Vector3
	local goal = direction * PUSH + Vector3.yAxis * LIFT
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, workspace.CurrentCamera }
	local hit = workspace:Raycast(from, goal, params)
	if hit then
		local reach = math.max((hit.Position - from).Magnitude - 1.5, 0)
		return goal.Unit * reach
	end
	return goal
end

local function showText()
	local screen = Instance.new("ScreenGui")
	screen.Name = "DeathSoul"
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 50
	-- The game's own monospace, bold (the LabelBold sheet), faded in as one group.
	local group = Instance.new("CanvasGroup")
	group.BackgroundTransparency = 1
	group.Size = UDim2.fromScale(1, 1)
	group.GroupTransparency = 1
	group.Parent = screen
	local view = workspace.CurrentCamera.ViewportSize
	local size = view.Y * TEXT_HEIGHT
	local label = TypeLabel.new(group, {
		style = "LabelLarge", -- LabelBold drawn for big text, so it stays sharp at this size
		size = size,
		tracking = size * TEXT_TRACKING,
		color = Palette.Bone,
		shadow = false,
		position = UDim2.fromOffset(0, 0),
	})
	label:set("YOU DIED")
	label:setPosition(UDim2.fromOffset((view.X - label:width()) / 2, view.Y * 0.46))
	local line = Instance.new("Frame")
	line.BorderSizePixel = 0
	line.BackgroundColor3 = Palette.Bone
	line.BackgroundTransparency = 0.3
	line.AnchorPoint = Vector2.new(0.5, 0)
	line.Position = UDim2.fromScale(0.5, 0.5)
	line.Size = UDim2.new(0, 0, 0, 2)
	line.Parent = group
	screen.Parent = player:WaitForChild("PlayerGui")
	gui = screen
	task.delay(TEXT_DELAY, function()
		if gui == screen then
			local info = TweenInfo.new(TEXT_FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			TweenService:Create(group, info, { GroupTransparency = 0 }):Play()
			TweenService:Create(line, info, { Size = UDim2.new(0, label:width(), 0, 2) }):Play()
		end
	end)
end

local function finish()
	RunService:UnbindFromRenderStep(STEP_NAME)
	soul = nil
	if grey then
		grey:Destroy()
		grey = nil
	end
	if gui then
		gui:Destroy()
		gui = nil
	end
	local camera = workspace.CurrentCamera
	if camera.CameraType == Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Custom
	end
end

local function onFrame(dt: number)
	local current = soul
	local camera = workspace.CurrentCamera
	if not current or not current.body.Parent then
		return
	end
	local age = os.clock() - current.startedAt
	local out = 1 - math.exp(-age * PUSH_EASE)
	local position = current.from.Position + current.push * out + Vector3.yAxis * DRIFT * age
	-- It starts looking where you were looking and comes round to the body.
	current.lookAt = current.lookAt:Lerp(current.body.Position, 1 - math.exp(-dt * FOLLOW_EASE))
	local toBody = CFrame.lookAt(position, current.lookAt)
	local turn = 1 - math.exp(-age * TURN_EASE)
	camera.CFrame = CFrame.new(position) * current.from.Rotation:Lerp(toBody.Rotation, turn)
	camera.FieldOfView += (SOUL_FOV - camera.FieldOfView) * (1 - math.exp(-dt * FOV_EASE))
	-- First person hides your own body; the soul should see it.
	for _, part in current.character:GetDescendants() do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = 0
		end
	end
end

local function begin(character: Model)
	if soul then
		return
	end
	local camera = workspace.CurrentCamera
	local body = (character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head")) :: BasePart?
	if not body then
		return
	end
	local from = camera.CFrame
	local direction = pushDirection(body, from.LookVector)
	soul = {
		startedAt = os.clock(),
		from = from,
		body = body,
		lookAt = body.Position,
		push = clearPush(from.Position, direction, character),
		character = character,
	}
	camera.CameraType = Enum.CameraType.Scriptable

	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = "DeathGrey"
	effect.Parent = camera
	grey = effect
	TweenService:Create(effect, TweenInfo.new(GREY_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Saturation = -1,
		Contrast = 0.12,
		Brightness = -0.06,
	}):Play()
	showText()
	RunService:BindToRenderStep(STEP_NAME, Enum.RenderPriority.Last.Value, onFrame)
end

local function onCharacter(character: Model)
	finish() -- back in a body
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		humanoid.Died:Once(function()
			if player.Character == character then
				begin(character)
			end
		end)
	end
end

-- The report can land just before or just after the death itself. If it's after, the push is turned to match.
deathRemote.OnClientEvent:Connect(function(at: Vector3, killer: Player?)
	lastDeath = { at = at, killer = killer, time = os.clock() }
	local current = soul
	if current and os.clock() - current.startedAt < 0.3 and current.body.Parent then
		current.push = clearPush(current.from.Position, pushDirection(current.body, current.from.LookVector), current.character)
	end
end)

player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end
