-- The match HUD (docs/specs/matches.md): the score and the time left at the top, the countdown and each round's
-- result in the middle, the class pick in the break between rounds, and, once you're dead, a view over a living
-- teammate's shoulder until the round ends. Everything comes from the match's state folder
-- (ReplicatedStorage.Matches.<id>), which the server keeps up to date. Teammates get an outline in the team's
-- colour so they're never mistaken for the other side.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local GunConfig = require(Guns:WaitForChild("GunConfig"))
local Palette = require(Guns:WaitForChild("Palette"))
local Hud = Guns:WaitForChild("Hud")
local HudText = require(Hud:WaitForChild("HudText"))
local MatchText = require(Hud:WaitForChild("MatchText"))
local TypeLabel = require(script.Parent.TypeLabel)

-- In the HUD's own units, on a 720-tall screen.
local TOP = 34 -- the score's baseline
local SCORE_SIZE = 26
local SCORE_GAP = 46 -- from the middle to each team's score
local CLOCK_SIZE = 14
local LINE_SIZE = 10
local LINE_GAP = 20 -- from the score's baseline to the line under it
local BANNER_SIZE = 44
local BANNER_Y = 0.36 -- of the screen's height, the banner's baseline
local PICK_Y = 0.6 -- of the screen's height, the top of the class pick
local PICK_WIDTH = 150
local PICK_HEIGHT = 34
local PICK_GAP = 12
local PICK_TEXT = 13
local WATCH_SIZE = 12
local WATCH_BOTTOM = 70 -- from the screen's bottom
local TRACKING = 2
local GREY = Color3.fromRGB(170, 176, 182)
local TEAM_COLORS = { Color3.fromRGB(18, 196, 190), Color3.fromRGB(255, 132, 28) } -- teal and orange
local SPECTATE_AFTER = 2.5 -- seconds of the death view before the camera moves to a teammate
local FOLLOW_BACK = 9 -- studs behind the watched teammate
local FOLLOW_UP = 4
local FOLLOW_EASE = 8
local STEP_NAME = "DeckMatchSpectate"

local player = Players.LocalPlayer
local states = ReplicatedStorage:WaitForChild("Matches")

local gui = Instance.new("ScreenGui")
gui.Name = "MatchHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 4 -- over the HUD and the kill feed, under the death text and the menu pages
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local root = Instance.new("Frame")
root.BackgroundTransparency = 1
root.Parent = gui
local scale = Instance.new("UIScale")
scale.Parent = root
local function size(): Vector2
	return root.AbsoluteSize / math.max(scale.Scale, 0.01)
end
local function fit()
	local value = HudText.scale(gui.AbsoluteSize.Y)
	scale.Scale = value
	root.Size = UDim2.fromScale(1 / value, 1 / value)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
fit()

local function label(style: string, textSize: number, color: Color3): any
	return TypeLabel.new(root, {
		style = style,
		size = textSize,
		tracking = TRACKING,
		color = color,
		position = UDim2.new(),
	})
end

-- Centres a label on x (a share of the width) with its baseline at y (in HUD units from the top).
local function centre(text: any, value: string, x: number, y: number)
	text:set(value)
	text:setPosition(UDim2.new(x, -text:width() / 2, 0, y))
end

local ours = label("LabelLarge", SCORE_SIZE, Palette.Bone)
local theirs = label("LabelLarge", SCORE_SIZE, Palette.Bone)
local clock = label("LabelBold", CLOCK_SIZE, Palette.Bone)
local line = label("Label", LINE_SIZE, GREY)
local banner = label("LabelLarge", BANNER_SIZE, Palette.Bone)
local watching = label("LabelBold", WATCH_SIZE, Palette.Bone)

-- The class pick: one button for each class, shown in the break between rounds. Modal buttons free the mouse
-- from first person while they're up.
local pick = Instance.new("Frame")
pick.Name = "ClassPick"
pick.BackgroundTransparency = 1
pick.AnchorPoint = Vector2.new(0.5, 0)
pick.Position = UDim2.fromScale(0.5, PICK_Y)
pick.Size = UDim2.fromOffset(#GunConfig.classOrder * (PICK_WIDTH + PICK_GAP) - PICK_GAP, PICK_HEIGHT + 30)
pick.Visible = false
pick.Parent = root
local pickTitle = TypeLabel.new(pick, {
	style = "LabelBold",
	size = LINE_SIZE,
	tracking = TRACKING,
	color = GREY,
	position = UDim2.new(),
})
pickTitle:set("CLASS FOR THE NEXT ROUND")
pickTitle:setPosition(UDim2.new(0.5, -pickTitle:width() / 2, 0, LINE_SIZE))

local chosen: string? = nil
local buttons: { [string]: { button: TextButton, stroke: UIStroke } } = {}
for index, class in GunConfig.classOrder do
	local button = Instance.new("TextButton")
	button.Name = class
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundColor3 = Palette.DeepNavy
	button.BackgroundTransparency = 0.25
	button.BorderSizePixel = 0
	button.Position = UDim2.fromOffset((index - 1) * (PICK_WIDTH + PICK_GAP), 26)
	button.Size = UDim2.fromOffset(PICK_WIDTH, PICK_HEIGHT)
	button.Parent = pick
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Palette.Bone
	stroke.Thickness = 1
	stroke.Transparency = 0.7
	stroke.Parent = button
	local name = TypeLabel.new(button, {
		style = "LabelBold",
		size = PICK_TEXT,
		tracking = TRACKING,
		color = Palette.Bone,
		shadow = false,
		position = UDim2.new(),
	})
	name:set(string.upper(class))
	name:setPosition(UDim2.new(0.5, -name:width() / 2, 0.5, PICK_TEXT / 2))
	button.MouseButton1Click:Connect(function()
		chosen = class
		local remotes = ReplicatedStorage:FindFirstChild("GunRemotes")
		local remote = remotes and remotes:FindFirstChild("SetLoadout")
		if remote then
			(remote :: RemoteEvent):FireServer({ class = class, rifle = player:GetAttribute("Rifle") })
		end
	end)
	buttons[class] = { button = button, stroke = stroke }
end

local function showPick(visible: boolean)
	pick.Visible = visible
	local current = chosen or player:GetAttribute("Class")
	for class, parts in buttons do
		parts.button.Modal = visible
		local on = class == current
		parts.stroke.Transparency = if on then 0 else 0.7
		parts.stroke.Thickness = if on then 2 else 1
	end
end

-- Spectating.
local watched: Player? = nil
local diedAt: number? = nil
local followAt: CFrame? = nil
local bound = false

local function teammates(): { Player }
	local list = {}
	local id, team = player:GetAttribute("MatchId"), player:GetAttribute("MatchTeam")
	for _, other in Players:GetPlayers() do
		if other ~= player and other:GetAttribute("MatchId") == id and other:GetAttribute("MatchTeam") == team then
			table.insert(list, other)
		end
	end
	return list
end

local function aliveRoot(other: Player): BasePart?
	local character = other.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local body = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid and humanoid.Health > 0 and body then
		return body
	end
	return nil
end

-- The next living teammate after the one being watched.
local function nextWatch(): Player?
	local list = teammates()
	local start = if watched then (table.find(list, watched) or 0) else 0
	for step = 1, #list do
		local other = list[(start + step - 1) % #list + 1]
		if aliveRoot(other) then
			return other
		end
	end
	return nil
end

local function stopWatching()
	if bound then
		RunService:UnbindFromRenderStep(STEP_NAME)
		bound = false
	end
	watched = nil
	followAt = nil
	watching:setVisible(false)
	local deathText = player.PlayerGui:FindFirstChild("DeathSoul")
	if deathText and deathText:IsA("ScreenGui") then
		deathText.Enabled = true
	end
end

local function follow(dt: number)
	local body = watched and aliveRoot(watched)
	if not body then
		watched = nextWatch()
		body = watched and aliveRoot(watched)
		if not body then
			return -- nobody left to watch; the round is about to end
		end
	end
	local camera = workspace.CurrentCamera
	local look = body.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
	local eye = body.Position - flat * FOLLOW_BACK + Vector3.yAxis * FOLLOW_UP
	local goal = CFrame.lookAt(eye, body.Position + flat * 12 + Vector3.yAxis * 1.5)
	followAt = if followAt then followAt:Lerp(goal, 1 - math.exp(-dt * FOLLOW_EASE)) else goal
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = followAt :: CFrame
	local name = watched and string.upper(watched.DisplayName) or ""
	centre(watching, `WATCHING {name}   CLICK FOR NEXT`, 0.5, size().Y - WATCH_BOTTOM)
end

local function startWatching()
	watched = nextWatch()
	if not watched then
		return
	end
	-- The death text would sit in the middle of the view.
	local deathText = player.PlayerGui:FindFirstChild("DeathSoul")
	if deathText and deathText:IsA("ScreenGui") then
		deathText.Enabled = false
	end
	watching:setVisible(true)
	-- After the death view's own step, so this one has the last word on the camera.
	RunService:BindToRenderStep(STEP_NAME, Enum.RenderPriority.Last.Value + 5, follow)
	bound = true
end

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and watched and input.UserInputType == Enum.UserInputType.MouseButton1 then
		watched = nextWatch() or watched
		followAt = nil
	end
end)

local function onCharacter(character: Model)
	stopWatching()
	diedAt = nil
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		humanoid.Died:Once(function()
			if player.Character == character then
				diedAt = os.clock()
			end
		end)
	end
end
player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end

-- Teammate outlines.
local outlines: { [Model]: Highlight } = {}
local function outlineTeammates(color: Color3?)
	local keep = {}
	if color then
		for _, other in teammates() do
			local character = other.Character
			if character then
				keep[character] = true
				local outline = outlines[character]
				if not outline or not outline.Parent then
					outline = Instance.new("Highlight")
					outline.Name = "MatchTeammate"
					outline.FillTransparency = 1
					outline.OutlineTransparency = 0.2
					outline.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					outline.Parent = character
					outlines[character] = outline
				end
				outline.OutlineColor = color
			end
		end
	end
	for character, outline in outlines do
		if not keep[character] then
			outline:Destroy()
			outlines[character] = nil
		end
	end
end

local nextOutline = 0
RunService.RenderStepped:Connect(function()
	local id = player:GetAttribute("MatchId")
	local state = id and states:FindFirstChild(tostring(id))
	if not state then
		if gui.Enabled then
			gui.Enabled = false
			showPick(false)
			stopWatching()
			outlineTeammates(nil)
			chosen = nil
		end
		return
	end
	gui.Enabled = true
	local mine = player:GetAttribute("MatchTeam") or 1
	local other = if mine == 1 then 2 else 1
	local phase = state:GetAttribute("Phase")
	local left = (state:GetAttribute("PhaseEnds") or 0) - workspace:GetServerTimeNow()
	local now = {
		phase = phase,
		round = state:GetAttribute("Round") or 0,
		roundWinner = state:GetAttribute("RoundWinner"),
		winner = state:GetAttribute("Winner"),
		mine = mine,
		left = left,
		catalysts = state:GetAttribute("Catalysts"),
	}

	local width = size().X
	local middle = 0.5
	ours:setColor(TEAM_COLORS[mine])
	theirs:setColor(TEAM_COLORS[other])
	ours:set(tostring(state:GetAttribute("Wins" .. mine) or 0))
	ours:setPosition(UDim2.new(middle, -SCORE_GAP - ours:width(), 0, TOP))
	theirs:set(tostring(state:GetAttribute("Wins" .. other) or 0))
	theirs:setPosition(UDim2.new(middle, SCORE_GAP, 0, TOP))
	centre(clock, if phase == "Playing" then MatchText.clock(left) else "", middle, TOP - (SCORE_SIZE - CLOCK_SIZE) / 2)
	centre(line, MatchText.line(now), middle, TOP + LINE_GAP)
	local word = MatchText.banner(now)
	if phase == "Playing" and left > (state:GetAttribute("RoundSeconds") or 90) - 1 then
		word = "FIGHT" -- held a moment after the count ends
	end
	centre(banner, word, middle, size().Y * BANNER_Y)
	if width <= 0 then
		return
	end

	showPick(phase == "Between")
	if phase ~= "Between" then
		chosen = nil
	end

	-- Dead in a live round: the death view first, then a living teammate's.
	if phase == "Playing" and diedAt and not bound and os.clock() - diedAt > SPECTATE_AFTER then
		startWatching()
	elseif phase ~= "Playing" and bound then
		stopWatching()
	end

	-- The death text only while the round is live; after it, the round's result takes the middle.
	local deathText = player.PlayerGui:FindFirstChild("DeathSoul")
	if deathText and deathText:IsA("ScreenGui") then
		deathText.Enabled = phase == "Playing" and not bound
	end

	if os.clock() >= nextOutline then
		nextOutline = os.clock() + 0.5
		outlineTeammates(TEAM_COLORS[mine])
	end
end)
