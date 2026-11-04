-- First-person movement: runs the rules each frame and applies them to the Humanoid.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Input = require(script.Parent.Input)
local Movement = ReplicatedStorage:WaitForChild("Movement")
local MoveState = require(Movement:WaitForChild("MoveState"))
local poseRemote = ReplicatedStorage:WaitForChild("MovementRemotes"):WaitForChild("Pose") :: RemoteEvent

local FIELD_OF_VIEW = 80
local SLIDE_CAMERA_DROP = Vector3.new(0, -2, 0)
local CAMERA_EASE = 15

local player = Players.LocalPlayer
local humanoid: Humanoid? = nil
local root: BasePart? = nil
local state = MoveState.new()
local slideDirection = Vector3.zero
local sentPose = "Normal"

local function poseFor(mode: string): string
	if mode == "Slide" or mode == "Crouch" then
		return mode
	end
	return "Normal"
end

local function onCharacter(character: Model)
	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	root = character:WaitForChild("HumanoidRootPart") :: BasePart
	humanoid.AutoRotate = false
	state = MoveState.new()
	slideDirection = Vector3.zero
	sentPose = "Normal"
	workspace.CurrentCamera.FieldOfView = FIELD_OF_VIEW
end

local function onFrame(dt: number)
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end

	local keys = Input.read()
	local wasSliding = state.mode == "Slide"
	local direction = humanoid.MoveDirection
	local now = os.clock()
	MoveState.step(state, {
		moving = direction.Magnitude > 0,
		sprint = keys.sprint,
		crouch = keys.crouch,
		jump = keys.jump,
		grounded = humanoid.FloorMaterial ~= Enum.Material.Air,
	}, now)

	humanoid.WalkSpeed = MoveState.speed(state, now)

	local pose = poseFor(state.mode)
	if pose ~= sentPose then
		sentPose = pose
		poseRemote:FireServer(pose)
	end

	local sliding = state.mode == "Slide"
	if sliding then
		if not wasSliding then
			slideDirection = direction.Unit
		end
		humanoid:Move(slideDirection, false)
	end

	local target = if sliding then SLIDE_CAMERA_DROP else Vector3.zero
	humanoid.CameraOffset = humanoid.CameraOffset:Lerp(target, math.min(dt * CAMERA_EASE, 1))

	local yaw = math.atan2(-workspace.CurrentCamera.CFrame.LookVector.X, -workspace.CurrentCamera.CFrame.LookVector.Z)
	root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0)
end

player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end

-- Runs after the default controls, so the slide direction overrides the keys.
RunService:BindToRenderStep("DeckMovement", Enum.RenderPriority.Character.Value, onFrame)
