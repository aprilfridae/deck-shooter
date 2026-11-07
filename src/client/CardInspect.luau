-- Holds a card up in the 3D world beside the open panel, to spin with the mouse and flip over.
-- It's a real part so it turns in perspective. The part itself is clear and each side is a
-- SurfaceGui, so the card keeps its rounded corners.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local CardSpin = require(Guns:WaitForChild("Hud"):WaitForChild("CardSpin"))
local Palette = require(Guns:WaitForChild("Palette"))
local CardFace = require(script.Parent.CardFace)
local MenuCamera = require(script.Parent.MenuCamera)

local STEP_NAME = "CardInspect"
local ASPECT = 150 / 240
local CANVAS_WIDTH = 750
local CANVAS_HEIGHT = 1200
local DEPTH = 3 -- studs in front of the camera
local THICKNESS = 0.01
local HEIGHT_SHARE = 0.7 -- of the screen's height
local SCREEN_X = 0.25 -- of the screen's width: the middle of the space beside the panel
local SCREEN_Y = 0.5
local DIM_DEPTH = 0.3 -- studs behind the card
local DIM_SIZE = 200
local DIM_CLEAR = 0.35 -- transparency once it's fully dimmed
local DRAG_START = 6 -- pixels the mouse moves before a press counts as a drag
local STILL_TURN = 0.02 -- radians: closer than this, the shine goes back to its timed sweep

local current: any = nil

local function surface(part: BasePart, face: Enum.NormalId, canvas: Vector2): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Adornee = part
	gui.Brightness = 1
	gui.CanvasSize = canvas
	gui.Face = face
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

local function clearPart(name: string): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Parent = Workspace.CurrentCamera
	return part
end

local function clearButton(parent: Instance): TextButton
	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Parent = parent
	return button
end

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

local function destroy(inspect: any)
	RunService:UnbindFromRenderStep(STEP_NAME)
	if inspect.grade then
		inspect.grade.Enabled = true
	end
	for _, connection in inspect.connections do
		connection:Disconnect()
	end
	for _, instance in inspect.instances do
		instance:Destroy()
	end
	if current == inspect then
		current = nil
	end
end

local function step(inspect: any, dt: number)
	inspect.elapsed += dt
	local leaving = 1
	if inspect.closedAt then
		leaving = CardSpin.leave(inspect.elapsed - inspect.closedAt)
		if leaving == 0 then
			destroy(inspect)
			return
		end
	end
	if not inspect.press then
		inspect.yaw = CardSpin.settle(inspect.yaw, inspect.rest, dt)
		inspect.pitch = CardSpin.settle(inspect.pitch, 0, dt)
	end
	local turned = inspect.yaw - inspect.rest + inspect.pitch
	inspect.shine = if inspect.press or math.abs(turned) > STILL_TURN then CardSpin.shine(turned) else nil

	local camera = Workspace.CurrentCamera
	local view = camera.ViewportSize
	local spin, arriving = CardSpin.enter(inspect.elapsed)
	local swayYaw, swayPitch = CardSpin.sway(inspect.elapsed)
	-- The camera's sheared picture is allowed for by asking MenuCamera for the ray.
	local ray = MenuCamera.ray(view.X * SCREEN_X, view.Y * SCREEN_Y)
	local look = camera.CFrame.LookVector
	local function atDepth(depth: number): Vector3
		return ray.Origin + ray.Direction * (depth / ray.Direction:Dot(look))
	end
	local facing = camera.CFrame.Rotation
	local height = HEIGHT_SHARE * 2 * DEPTH * math.tan(math.rad(camera.FieldOfView) / 2) * arriving * leaving
	inspect.part.Size = Vector3.new(height * ASPECT, height, THICKNESS)
	inspect.part.CFrame = CFrame.new(atDepth(DEPTH))
		* facing
		* CFrame.Angles(inspect.pitch + swayPitch, inspect.yaw + spin + swayYaw, 0)
	inspect.dim.CFrame = CFrame.new(atDepth(DEPTH + DIM_DEPTH)) * facing
	-- Drawn over the world, so nothing hides the side turned away. Each is shown only when it faces us.
	local showsFront = inspect.part.CFrame.LookVector:Dot(inspect.part.Position - camera.CFrame.Position) > 0
	inspect.front.Enabled = showsFront
	inspect.back.Enabled = not showsFront
	local arrived = 1 - spin / (2 * math.pi)
	inspect.dimFrame.BackgroundTransparency = 1 - (1 - DIM_CLEAR) * arrived * leaving
end

local function listen(inspect: any, hit: TextButton, outside: TextButton)
	table.insert(
		inspect.connections,
		hit.InputBegan:Connect(function(input)
			if isPress(input) then
				inspect.press = { x = input.Position.X, y = input.Position.Y, dragged = false }
			end
		end)
	)
	table.insert(
		inspect.connections,
		UserInputService.InputChanged:Connect(function(input)
			local press = inspect.press
			if not press or not isMove(input) then
				return
			end
			local dx, dy = input.Position.X - press.x, input.Position.Y - press.y
			if not press.dragged and math.max(math.abs(dx), math.abs(dy)) < DRAG_START then
				return
			end
			press.dragged = true
			press.x, press.y = input.Position.X, input.Position.Y
			inspect.yaw, inspect.pitch = CardSpin.drag(inspect.yaw, inspect.pitch, dx, dy)
		end)
	)
	table.insert(
		inspect.connections,
		UserInputService.InputEnded:Connect(function(input)
			local press = inspect.press
			if not press or not isPress(input) then
				return
			end
			inspect.press = nil
			inspect.rest = if press.dragged then CardSpin.rest(inspect.yaw) else inspect.rest + math.pi
		end)
	)
	table.insert(inspect.connections, outside.Activated:Connect(function()
		if current == inspect and not inspect.closedAt and CardSpin.canClose(inspect.elapsed) then
			inspect.closedAt = inspect.elapsed
		end
	end))
end

-- The pack opening is held up in the same spot, the same way.
local CardInspect = {
	DEPTH = DEPTH,
	SCREEN_X = SCREEN_X,
	SCREEN_Y = SCREEN_Y,
	THICKNESS = THICKNESS,
	DIM_DEPTH = DIM_DEPTH,
	DIM_SIZE = DIM_SIZE,
	DIM_CLEAR = DIM_CLEAR,
	surface = surface,
	clearPart = clearPart,
}

function CardInspect.isOpen(): boolean
	return current ~= nil
end

function CardInspect.close()
	if current and not current.closedAt then
		current.closedAt = current.elapsed
	end
end

-- Takes the card's CardFace options, plus how many copies the player owns.
function CardInspect.open(options: any)
	if current then
		destroy(current)
	end
	local inspect: any = {
		elapsed = 0,
		yaw = 0,
		pitch = 0,
		rest = 0,
		shine = nil,
		press = nil,
		closedAt = nil,
		connections = {},
		instances = {},
	}
	current = inspect

	inspect.part = clearPart("CardInspect")
	inspect.dim = clearPart("CardInspectDim")
	inspect.instances = { inspect.part, inspect.dim }
	inspect.dim.Size = Vector3.new(DIM_SIZE, DIM_SIZE, THICKNESS)

	local canvas = Vector2.new(CANVAS_WIDTH, CANVAS_HEIGHT)
	local front = surface(inspect.part, Enum.NormalId.Back, canvas)
	local back = surface(inspect.part, Enum.NormalId.Front, canvas)
	table.insert(inspect.instances, front)
	table.insert(inspect.instances, back)
	front.AlwaysOnTop = true
	back.AlwaysOnTop = true
	inspect.front, inspect.back = front, back
	local face = table.clone(options)
	face.width = CANVAS_WIDTH
	face.position = nil
	face.shineAt = function(): number?
		return inspect.shine
	end
	CardFace.new(front, face)
	CardFace.back(back, face, options.count)

	local dimGui = surface(inspect.dim, Enum.NormalId.Back, Vector2.new(4, 4))
	table.insert(inspect.instances, dimGui)
	inspect.dimFrame = Instance.new("Frame")
	inspect.dimFrame.BackgroundColor3 = Palette.DeepNavy
	inspect.dimFrame.BackgroundTransparency = 1
	inspect.dimFrame.BorderSizePixel = 0
	inspect.dimFrame.Size = UDim2.fromScale(1, 1)
	inspect.dimFrame.Parent = dimGui

	-- Over the menus, so a click anywhere reaches the card or closes it.
	local input = Instance.new("ScreenGui")
	input.Name = "CardInspectInput"
	input.DisplayOrder = 6
	input.IgnoreGuiInset = true
	input.ResetOnSpawn = false
	input.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	table.insert(inspect.instances, input)
	local outside = clearButton(input)
	outside.Size = UDim2.fromScale(1, 1)
	local hit = clearButton(input)
	hit.AnchorPoint = Vector2.new(0.5, 0.5)
	hit.Position = UDim2.fromScale(SCREEN_X, SCREEN_Y)
	hit.Size = UDim2.fromScale(HEIGHT_SHARE, HEIGHT_SHARE)
	hit.ZIndex = 2
	local constraint = Instance.new("UIAspectRatioConstraint")
	constraint.AspectRatio = ASPECT
	constraint.DominantAxis = Enum.DominantAxis.Height
	constraint.Parent = hit

	-- The Outpost's colour grade tints the world green, card included, so it's off while one is held.
	local grade = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if grade and grade.Enabled then
		grade.Enabled = false
		inspect.grade = grade
	end
	listen(inspect, hit, outside)
	RunService:BindToRenderStep(STEP_NAME, Enum.RenderPriority.Camera.Value + 1, function(dt)
		step(inspect, dt)
	end)
end

return CardInspect
