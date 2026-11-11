-- First-person movement: runs the rules each frame and applies them to the Humanoid.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GunAudio = require(script.Parent.GunAudio)
local Input = require(script.Parent.Input)
local Ledge = require(script.Parent.Ledge)
local PlayerSettings = require(script.Parent.PlayerSettings)
local Guns = ReplicatedStorage:WaitForChild("Guns")
local Zones = require(Guns:WaitForChild("Zones"))
local CardCore = ReplicatedStorage:WaitForChild("CardCore")
local Config = require(CardCore:WaitForChild("Config"))
local Movement = ReplicatedStorage:WaitForChild("Movement")
local Parry = require(Movement:WaitForChild("Parry"))
local MoveState = require(Movement:WaitForChild("MoveState"))
local MoveConfig = require(Movement:WaitForChild("MoveConfig"))
local poseRemote = ReplicatedStorage:WaitForChild("MovementRemotes"):WaitForChild("Pose") :: RemoteEvent
local abilityRemotes = ReplicatedStorage:WaitForChild("AbilityRemotes")
local dashRemote = abilityRemotes:WaitForChild("Dash") :: RemoteEvent
local pushRemote = abilityRemotes:WaitForChild("Push") :: RemoteEvent

local FIELD_OF_VIEW = 80
local SLIDE_CAMERA_DROP = Vector3.new(0, -2, 0)
-- The player rig has auto scaling off, so Roblox puts the camera 2 studs over the root, not 1.5.
local BODY_CAMERA = Vector3.new(0, 0.94, -0.5) -- level with the eye bar, from the default spot 2 above the root
local CAMERA_EASE = 15
local SLIDE_FOV = 88
local JUMP_FOV = 84
local SLIDE_JUMP_FOV = 96
local CHAIN_JUMP_FOV = 104
local FOV_EASE = 7
local SCOPE_FOV_EASE = 30 -- scoping out snaps
local SCOPE_IN_EASE = 13 -- scoping in takes a moment, about a quarter of a second
local LAND_CAMERA_DIP = Vector3.new(0, -0.9, 0)
local MIN_AIR_FOR_DIP = 0.15
local EFFECT_EASE = 7
local POSE_SEND_GAP = 0.12 -- stays under the server's 10 per second limit
local DASH_RADIUS = 1.5 -- keeps the body this far from a wall
local DASH_BACK_START = 1.6
local DASH_GROUND_REACH = 6

local player = Players.LocalPlayer
local humanoid: Humanoid? = nil
local root: BasePart? = nil
local state = MoveState.new()
local slideDirection = Vector3.zero
local airFromSlide = false
local jumped = false
local fieldOfView = FIELD_OF_VIEW
local wasScoped = false
local scopeEasing = false
local landDip = 0
local SLIDE_CAMERA_HOLD = 0.35 -- seconds the camera stays low after a slide blips into the air with crouch held
local slidSeenAt = -math.huge
local JUMP_SOUND_GAP = 0.3 -- seconds before the jump sound can play again
local jumpSoundAt = -math.huge
local airStartedAt = 0
local peakFall = 0 -- the fastest fall since leaving the ground
local sentPose = "Normal"
local poseSentAt = -math.huge
local jumpHeld = false
local stepTravel = 0

type DashPath = {
	from: Vector3,
	to: Vector3,
	forward: Vector3,
	startedAt: number,
	entrySpeed: number,
	fallSpeed: number,
}
local dash: DashPath? = nil

local function poseFor(mode: string): string
	if mode == "Slide" or mode == "Crouch" then
		return mode
	end
	return "Normal"
end

-- Space is only the default jump key, so Roblox's own jump is switched off. Jumping comes from
-- the player's binding, in the step below.
ContextActionService:BindActionAtPriority("BlockDefaultJump", function()
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space)

local function movementFieldOfView(): number
	if state.mode == "Slide" then
		return SLIDE_FOV
	elseif state.mode ~= "Air" then
		return FIELD_OF_VIEW
	elseif airFromSlide then
		if not jumped then
			return SLIDE_FOV
		end
		return if state.chained then CHAIN_JUMP_FOV else SLIDE_JUMP_FOV
	end
	return if jumped then JUMP_FOV else FIELD_OF_VIEW
end

-- The player's setting moves the base view, and the boosts keep their distance above it.
local function targetFieldOfView(): number
	local aimFov = player:GetAttribute("AimFov")
	if aimFov then
		return aimFov
	end
	return movementFieldOfView() + PlayerSettings.get().fieldOfView - FIELD_OF_VIEW
end

local function flatLook(): Vector3
	local look = workspace.CurrentCamera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	return if flat.Magnitude > 0.01 then flat.Unit else root.CFrame.LookVector
end

local function startParry(forward: Vector3, height: number, now: number)
	MoveState.parry(state, now)
	local speed = MoveState.speed(state, now)
	local rise = Parry.riseSpeed(height, workspace.Gravity)
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	root.AssemblyLinearVelocity = forward * speed + Vector3.new(0, rise, 0)
	slideDirection = forward
	airFromSlide = true
	jumped = true
	airStartedAt = now
	peakFall = 0
end

-- A jump press near a low edge parries off it.
local function tryParry(moveDirection: Vector3, now: number)
	local rootHeight = humanoid.HipHeight + root.Size.Y / 2
	local heading = if state.mode == "Slide" or (airFromSlide and moveDirection.Magnitude == 0)
		then slideDirection
		elseif moveDirection.Magnitude > 0 then moveDirection.Unit
		else flatLook()
	local edge = Ledge.find(humanoid.Parent :: Model, root, heading, rootHeight)
	if edge then
		startParry(heading, edge.height, now)
		return true
	end
	return false
end

-- A jump press in the air beside a wall kicks off it: away from the wall and toward where the player is looking,
-- keeping their speed. A few to a time in the air, and never off the same wall twice running.
local wallJumps = 0
local wallJumpAt = -math.huge
local lastWall: Vector3? = nil
local wallParams = RaycastParams.new()
wallParams.FilterType = Enum.RaycastFilterType.Exclude
wallParams.RespectCanCollide = true

local function tryWallJump(moveDirection: Vector3, now: number)
	if
		state.mode ~= "Air"
		or humanoid.FloorMaterial ~= Enum.Material.Air
		or wallJumps >= MoveConfig.WallJumps
		or now - wallJumpAt < MoveConfig.WallJumpGap
		or now - airStartedAt < MoveConfig.WallJumpMinAir
	then
		return
	end
	wallParams.FilterDescendantsInstances = { humanoid.Parent :: Instance }
	-- The nearest wall within reach, looking all the way round.
	local look = flatLook()
	local nearest: RaycastResult? = nil
	for turn = 0, 7 do
		local way = CFrame.Angles(0, turn * math.pi / 4, 0) * look
		local hit = workspace:Raycast(root.Position, way * MoveConfig.WallJumpReach, wallParams)
		if hit and math.abs(hit.Normal.Y) <= MoveConfig.WallJumpSteep and (not nearest or hit.Distance < nearest.Distance) then
			nearest = hit
		end
	end
	if not nearest then
		return
	end
	local away = Vector3.new(nearest.Normal.X, 0, nearest.Normal.Z).Unit
	if lastWall and away:Dot(lastWall) > MoveConfig.WallJumpSame then
		return
	end
	-- Where the player is steering, or looking, bounced off the wall if it points into it.
	local aim = if moveDirection.Magnitude > 0 then moveDirection.Unit else look
	local into = aim:Dot(away)
	if into < 0 then
		aim -= away * (2 * into)
	end
	local kick = (away + aim * MoveConfig.WallJumpLook).Unit
	MoveState.wallJump(state, now)
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	root.AssemblyLinearVelocity = kick * MoveState.speed(state, now)
		+ Vector3.new(0, Parry.riseSpeed(MoveConfig.WallJumpHeight, workspace.Gravity), 0)
	slideDirection = kick
	airFromSlide = true
	jumped = true
	airStartedAt = now
	peakFall = 0
	wallJumps += 1
	wallJumpAt = now
	lastWall = away
	jumpSoundAt = now
	GunAudio.playJump()
end

-- A dash follows a set path, then hands back to normal movement in the air.
local function startDash(distance: number)
	if not humanoid or not root or humanoid.Health <= 0 or dash then
		return
	end
	local direction = humanoid.MoveDirection
	local forward = if direction.Magnitude > 0 then direction.Unit else flatLook()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { humanoid.Parent :: Model }
	params.RespectCanCollide = true

	-- On the ground the path follows the slope, so a ramp does not stop the dash.
	local ground = workspace:Raycast(root.Position, Vector3.new(0, -DASH_GROUND_REACH, 0), params)
	if ground then
		forward = (forward - ground.Normal * forward:Dot(ground.Normal)).Unit
	end

	-- A sphere cast misses anything it starts inside, so it starts behind the player
	-- to catch a wall they are already touching.
	local start = root.Position - forward * DASH_BACK_START
	local hit = workspace:Spherecast(start, DASH_RADIUS, forward * (distance + DASH_BACK_START), params)
	local travel = if hit then math.max(hit.Distance - DASH_BACK_START, 0) else distance
	local from = root.Position
	dash = {
		from = from,
		to = from + forward * travel,
		forward = forward,
		startedAt = os.clock(),
		entrySpeed = MoveState.speed(state, os.clock()),
		fallSpeed = root.AssemblyLinearVelocity.Y,
	}
	MoveState.startDash(state)
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
end

local function advanceDash(path: DashPath, now: number)
	local progress = math.min((now - path.startedAt) / Config.DashSeconds, 1)
	root.CFrame = CFrame.new(path.from:Lerp(path.to, progress)) * root.CFrame.Rotation
	root.AssemblyLinearVelocity = Vector3.zero

	if progress >= 1 then
		dash = nil
		local dashSpeed = (path.to - path.from).Magnitude / Config.DashSeconds
		MoveState.finishDash(state, path.entrySpeed, dashSpeed, now)
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		slideDirection = Vector3.new(path.forward.X, 0, path.forward.Z).Unit
		local speed = MoveState.speed(state, now)
		root.AssemblyLinearVelocity = slideDirection * speed + Vector3.yAxis * path.fallSpeed
		airFromSlide = true
		jumped = false
		airStartedAt = now
		peakFall = 0
	end
end

-- In the Outpost the body turns to face where it's walking. In first person this script turns it to the camera.
local function updateAutoRotate()
	if humanoid then
		humanoid.AutoRotate = Zones.autoRotates(Zones.of(player))
	end
end

local function onCharacter(character: Model)
	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	root = character:WaitForChild("HumanoidRootPart") :: BasePart
	updateAutoRotate()
	humanoid.UseJumpPower = false
	state = MoveState.new()
	slideDirection = Vector3.zero
	airFromSlide = false
	jumped = false
	fieldOfView = FIELD_OF_VIEW
	landDip = 0
	sentPose = "Normal"
	jumpHeld = false
	dash = nil
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
	local jumpPressed = keys.jump and not jumpHeld
	jumpHeld = keys.jump
	if keys.jump then
		humanoid.Jump = true
	end

	if jumpPressed and state.mode ~= "Dash" and not tryParry(direction, now) then
		tryWallJump(direction, now)
	end
	if humanoid.FloorMaterial ~= Enum.Material.Air then
		wallJumps, lastWall = 0, nil -- back on the ground
	end
	if dash then
		advanceDash(dash, now)
	end

	MoveState.step(state, {
		moving = direction.Magnitude > 0 or airFromSlide,
		sprint = keys.sprint,
		crouch = keys.crouch,
		jump = keys.jump,
		grounded = humanoid.FloorMaterial ~= Enum.Material.Air,
	}, now)

	humanoid.WalkSpeed = MoveState.speed(state, now)
	humanoid.JumpHeight = MoveState.jumpHeight(state)
	player:SetAttribute("MoveMode", state.mode)

	local pose = poseFor(state.mode)
	if pose ~= sentPose and now - poseSentAt >= POSE_SEND_GAP then
		sentPose = pose
		poseSentAt = now
		poseRemote:FireServer(pose)
	end

	local sliding = state.mode == "Slide"
	if sliding then
		if not wasSliding then
			GunAudio.playSlideStart()
			if direction.Magnitude > 0 then
				slideDirection = direction.Unit
			end
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

	-- The keys take hold at once. Left to itself the Humanoid eases up to speed and back down, slowly at this
	-- gravity, so the flat velocity is set here: straight to the keys on the ground (and to a stop with none
	-- held), and quickly toward them in the air. Air with no keys held is left alone, so a jump, a push or a
	-- wall kick carries. A dash moves itself.
	if not dash and state.mode ~= "Dash" then
		local wish = direction
		if sliding or (airFromSlide and direction.Magnitude == 0) then
			wish = slideDirection
		end
		local moving = root.AssemblyLinearVelocity
		local goal = Vector3.new(wish.X, 0, wish.Z) * humanoid.WalkSpeed
		if state.mode ~= "Air" then
			root.AssemblyLinearVelocity = Vector3.new(goal.X, moving.Y, goal.Z)
		elseif wish.Magnitude > 0 then
			local flat = Vector3.new(moving.X, 0, moving.Z):Lerp(goal, 1 - math.exp(-dt * MoveConfig.AirResponse))
			root.AssemblyLinearVelocity = Vector3.new(flat.X, moving.Y, flat.Z)
		end
	end

	local velocity = root.AssemblyLinearVelocity

	local flatSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local stepped
	stepTravel, stepped = MoveState.stepTravel(stepTravel, flatSpeed * dt, state.mode)
	if stepped then
		GunAudio.playStep()
	end

	-- The view widens through slides and jumps, and landing dips the camera.
	local airborne = state.mode == "Air"
	if airborne and previousMode ~= "Air" then
		airStartedAt = now
		peakFall = 0
		jumped = keys.jump
		-- Once a jump: the ground check can flicker as the feet leave, which would count as leaving it twice.
		if jumped and now - jumpSoundAt >= JUMP_SOUND_GAP then
			jumpSoundAt = now
			GunAudio.playJump()
		end
	elseif previousMode == "Air" and not airborne and now - airStartedAt >= MIN_AIR_FOR_DIP then
		landDip = 1
		GunAudio.playLand(MoveState.hardLanding(peakFall))
	end
	if airborne then
		peakFall = math.max(peakFall, -fallY)
	end
	landDip *= math.exp(-dt * EFFECT_EASE)
	local scoped = player:GetAttribute("AimFov") ~= nil
	if scoped ~= wasScoped then
		wasScoped = scoped
		scopeEasing = true
	end
	local targetFov = targetFieldOfView()
	if scopeEasing and math.abs(targetFov - fieldOfView) < 1 then
		scopeEasing = false
	end
	fieldOfView += (targetFov - fieldOfView) * (1 - math.exp(-dt * (if scopeEasing then (if scoped then SCOPE_IN_EASE else SCOPE_FOV_EASE) else FOV_EASE)))
	workspace.CurrentCamera.FieldOfView = fieldOfView

	-- The camera stays low through a slide's blips. A slide that loses the ground for a moment (a bump, a lip, the
	-- start of a slope) becomes "Air" for at least MinAirTime before it can be a slide again, and with slides spammed
	-- that happened over and over: the game had you sliding, mostly, while the camera kept being let back up and never
	-- got down. So it also counts as low while crouch is still held just after a slide.
	if sliding then
		slidSeenAt = now
	end
	local low = sliding or (keys.crouch and state.mode == "Air" and now - slidSeenAt < SLIDE_CAMERA_HOLD)
	local target = BODY_CAMERA + (if low then SLIDE_CAMERA_DROP else Vector3.zero) + LAND_CAMERA_DIP * landDip
	humanoid.CameraOffset = humanoid.CameraOffset:Lerp(target, math.min(dt * CAMERA_EASE, 1))

	-- In first person (the combat zones), manually rotate character to face camera direction.
	-- In third-person (Outpost), AutoRotate is enabled so character faces move direction.
	local zone = Zones.of(player)
	if not Zones.autoRotates(zone) then
		local yaw = math.atan2(-workspace.CurrentCamera.CFrame.LookVector.X, -workspace.CurrentCamera.CFrame.LookVector.Z)
		root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0)
	end
end

-- Roblox gives every character a looping "Running" sound. Ours are in GunAudio instead.
local function muteRunning(sound: Instance)
	if sound:IsA("Sound") and sound.Name == "Running" then
		sound.Volume = 0
	end
end

local function muteDefaultSteps(character: Model)
	local body = character:WaitForChild("HumanoidRootPart")
	body.ChildAdded:Connect(muteRunning)
	for _, child in body:GetChildren() do
		muteRunning(child)
	end
end

local function watchPlayer(other: Player)
	other.CharacterAdded:Connect(muteDefaultSteps)
	if other.Character then
		task.spawn(muteDefaultSteps, other.Character)
	end
end

Players.PlayerAdded:Connect(watchPlayer)
for _, other in Players:GetPlayers() do
	watchPlayer(other)
end

dashRemote.OnClientEvent:Connect(startDash)
pushRemote.OnClientEvent:Connect(function(velocity: Vector3)
	if humanoid and root and not dash then
		local flat = Vector3.new(velocity.X, 0, velocity.Z)
		MoveState.launch(state, flat.Magnitude, os.clock())
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		root.AssemblyLinearVelocity = velocity
		slideDirection = flat.Unit
		airFromSlide = true
		jumped = false
		airStartedAt = os.clock()
	end
end)

player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end

player:GetAttributeChangedSignal("Zone"):Connect(updateAutoRotate)
updateAutoRotate()

-- Runs after the default controls, so the slide direction overrides the keys.
RunService:BindToRenderStep("DeckMovement", Enum.RenderPriority.Character.Value, onFrame)
