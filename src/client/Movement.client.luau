-- First-person movement: runs the rules each frame and applies them to the Humanoid.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Input = require(script.Parent.Input)
local Movement = ReplicatedStorage:WaitForChild("Movement")
local MoveConfig = require(Movement:WaitForChild("MoveConfig"))
local MoveState = require(Movement:WaitForChild("MoveState"))
local poseRemote = ReplicatedStorage:WaitForChild("MovementRemotes"):WaitForChild("Pose") :: RemoteEvent

local FIELD_OF_VIEW = 80
local SLIDE_CAMERA_DROP = Vector3.new(0, -2, 0)
local CAMERA_EASE = 15
local SLIDE_FOV = 88
local JUMP_FOV = 84
local SLIDE_JUMP_FOV = 96
local FOV_EASE = 7
local LAND_CAMERA_DIP = Vector3.new(0, -0.9, 0)
local MIN_AIR_FOR_DIP = 0.15
local EFFECT_EASE = 7
local POSE_SEND_GAP = 0.12 -- stays under the server's 10 per second limit

local player = Players.LocalPlayer
local humanoid: Humanoid? = nil
local root: BasePart? = nil
local state = MoveState.new()
local slideDirection = Vector3.zero
local airFromSlide = false
local jumped = false
local fieldOfView = FIELD_OF_VIEW
local landDip = 0
local airStartedAt = 0
local sentPose = "Normal"
local poseSentAt = -math.huge

local function poseFor(mode: string): string
	if mode == "Slide" or mode == "Crouch" then
		return mode
	end
	return "Normal"
end

local function targetFieldOfView(): number
	if state.mode == "Slide" then
		return SLIDE_FOV
	elseif state.mode ~= "Air" then
		return FIELD_OF_VIEW
	elseif airFromSlide then
		return if jumped then SLIDE_JUMP_FOV else SLIDE_FOV
	end
	return if jumped then JUMP_FOV else FIELD_OF_VIEW
end

local function onCharacter(character: Model)
	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	root = character:WaitForChild("HumanoidRootPart") :: BasePart
	humanoid.AutoRotate = false
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = MoveConfig.JumpHeight
	state = MoveState.new()
	slideDirection = Vector3.zero
	airFromSlide = false
	jumped = false
	fieldOfView = FIELD_OF_VIEW
	landDip = 0
	sentPose = "Normal"
	workspace.CurrentCamera.FieldOfView = FIELD_OF_VIEW
end

local function onFrame(dt: number)
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end

	local keys = Input.read()
	local previousMode = state.mode
	local wasSliding = previousMode == "Slide"
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
	if pose ~= sentPose and now - poseSentAt >= POSE_SEND_GAP then
		sentPose = pose
		poseSentAt = now
		poseRemote:FireServer(pose)
	end

	local sliding = state.mode == "Slide"
	if sliding then
		if not wasSliding then
			slideDirection = direction.Unit
		end
		humanoid:Move(slideDirection, false)
	end

	-- A jump off a slide keeps its momentum when no keys are held.
	if state.mode ~= "Air" then
		airFromSlide = false
	elseif wasSliding then
		airFromSlide = true
	end
	if airFromSlide and direction.Magnitude == 0 then
		humanoid:Move(slideDirection, false)
	end

	-- The view widens through slides and jumps, and landing dips the camera.
	local airborne = state.mode == "Air"
	if airborne and previousMode ~= "Air" then
		airStartedAt = now
		jumped = keys.jump
	elseif previousMode == "Air" and not airborne and now - airStartedAt >= MIN_AIR_FOR_DIP then
		landDip = 1
	end
	landDip *= math.exp(-dt * EFFECT_EASE)
	fieldOfView += (targetFieldOfView() - fieldOfView) * (1 - math.exp(-dt * FOV_EASE))
	workspace.CurrentCamera.FieldOfView = fieldOfView

	local target = (if sliding then SLIDE_CAMERA_DROP else Vector3.zero) + LAND_CAMERA_DIP * landDip
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
