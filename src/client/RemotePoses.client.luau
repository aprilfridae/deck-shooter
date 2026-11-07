-- Draws every body in stop-motion. Whatever the Animator plays is sampled once per held frame,
-- then the crouch, slide, landing and run lean go on top, as on the first-person arms.
-- A soldier body (the character has the SoldierRig attribute) shows the gun poses from the pose files
-- instead: GunStance picks one per held frame from what every client can see, and HeldGuns puts the gun in its hand.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local ArmPose = require(Guns:WaitForChild("ArmPose"))
local Zones = require(Guns:WaitForChild("Zones"))
local GunConfig = require(Guns:WaitForChild("GunConfig"))
local Movement = ReplicatedStorage:WaitForChild("Movement")
local BodyPose = require(Movement:WaitForChild("BodyPose"))
local BodyPoses = require(Movement:WaitForChild("BodyPoses"))
local GunStance = require(Movement:WaitForChild("GunStance"))
local HeldGuns = require(script.Parent:WaitForChild("HeldGuns"))

local shotsRemote = ReplicatedStorage:WaitForChild("GunRemotes"):WaitForChild("Shots") :: RemoteEvent

local FORWARD_LEAN_AXIS = Vector3.xAxis
local STILL_SPEED = 1
local FEET_BELOW_ROOT = 3 -- the soldier's root sits this far above its feet
local GROUND_REACH = 0.6 -- studs below the feet that still count as standing
local FIRST_PERSON = 1.5 -- a camera this close to your own head is first person, so your held gun hides

-- Sidearms without poses of their own borrow the Energy Pistol's.
local POSES_OF = {
	["Machine pistol"] = "Energy Pistol",
	["Revolver"] = "Energy Pistol",
	["Auto-pistol"] = "Energy Pistol",
}

local lastShot: { [Player]: number } = {}
shotsRemote.OnClientEvent:Connect(function(shooter: Player)
	lastShot[shooter] = os.clock()
end)
Players.PlayerRemoving:Connect(function(player)
	lastShot[player] = nil
end)

local function turns(pose: { [string]: BodyPose.Angles }): { [string]: CFrame }
	local result = {}
	for name, angles in pose do
		result[name] = CFrame.Angles(math.rad(angles.x), math.rad(angles.y), math.rad(angles.z))
	end
	return result
end

local SLIDE = turns(BodyPose.slide)
local CROUCH = turns(BodyPose.crouch)

type Body = {
	character: Model,
	root: BasePart,
	joints: { [string]: any },
	base: { [string]: CFrame },
	held: { [string]: CFrame },
	frame: number,
	seed: number,
	idleJitter: number,
	sliding: boolean,
	slideAt: number,
	slideFrom: number,
	slideWeight: number,
	crouch: number,
	landedAt: number,
	-- Soldier bodies only.
	player: Player?,
	soldier: boolean,
	airborne: boolean,
	travel: number,
	sampledAt: number,
	gunName: string?,
	poses: any,
	pose: any,
}
local bodies: { [Model]: Body } = {}

local function isJoint(joint: Instance): boolean
	return joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")
end

-- Another player's body arrives over the network a piece at a time, so wait as long as it exists.
local function waitFor(character: Model, name: string): Instance?
	while character.Parent do
		local child = character:WaitForChild(name, 1)
		if child then
			return child
		end
	end
	return nil
end

local function onCharacter(character: Model)
	local humanoid = waitFor(character, "Humanoid") :: Humanoid?
	local root = waitFor(character, "HumanoidRootPart") :: BasePart?
	if not waitFor(character, "LowerTorso") or not humanoid or not root then
		return
	end

	-- The joints can turn up after the parts do, so keep collecting them.
	local joints = {}
	for _, descendant in character:GetDescendants() do
		if isJoint(descendant) then
			joints[descendant.Name] = descendant
		end
	end
	character.DescendantAdded:Connect(function(descendant)
		if isJoint(descendant) then
			joints[descendant.Name] = descendant
		end
	end)
	-- An avatar stands still. Only the game's body keeps twitching at rest.
	local player = Players:GetPlayerFromCharacter(character)
	local avatar = player ~= nil and Zones.usesAvatar(Zones.of(player))
	local body: Body = {
		character = character,
		root = root,
		joints = joints,
		base = {},
		held = {},
		frame = -1,
		seed = math.random(1, 10000), -- so bodies don't twitch in time with each other
		idleJitter = if avatar then 0 else BodyPose.idleJitter,
		sliding = false,
		slideAt = -math.huge,
		slideFrom = 0,
		slideWeight = 0,
		crouch = 0,
		landedAt = -math.huge,
		player = player,
		soldier = character:GetAttribute("SoldierRig") == true,
		airborne = false,
		travel = 0,
		sampledAt = os.clock(),
		gunName = nil,
		poses = nil,
		pose = nil,
	}
	bodies[character] = body
	humanoid.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Landed then
			body.landedAt = os.clock()
		end
	end)
	character:GetAttributeChangedSignal("SoldierRig"):Connect(function()
		body.soldier = character:GetAttribute("SoldierRig") == true
		table.clear(body.held)
		table.clear(body.base)
		if not body.soldier then
			HeldGuns.remove(character)
		end
	end)
	character.Destroying:Once(function()
		bodies[character] = nil
		HeldGuns.remove(character)
	end)
end

-- The gun a body holds, by the display name the pose files use, and its poses. A body with no player,
-- such as the soldier test dummy, names its gun with its own GunId attribute.
local function gunOf(player: Player?, character: Model): (string?, any)
	local id = if player then player:GetAttribute("GunId") else character:GetAttribute("GunId")
	local gun = id and GunConfig.guns[id]
	if not gun then
		return nil, BodyPoses.Empty
	end
	local poses = BodyPoses[gun.name] or BodyPoses[POSES_OF[gun.name] or ""]
	if not poses then
		return nil, BodyPoses.Empty
	end
	return gun.name, poses
end

local function onGround(body: Body): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { body.character }
	local reach = FEET_BELOW_ROOT + GROUND_REACH
	return workspace:Raycast(body.root.Position, Vector3.new(0, -reach, 0), params) ~= nil
end

local function jitter(body: Body, strength: number)
	local seed = body.seed
	for name, degrees in BodyPose.jitter do
		seed += 1
		if body.held[name] then
			local _, _, _, pitch, yaw, roll = ArmPose.shake(body.frame, seed)
			local turn = math.rad(degrees * BodyPose.jitterScale * strength)
			body.held[name] *= CFrame.Angles(pitch * turn, yaw * turn, roll * turn)
		end
	end
end

-- A soldier body: one gun pose per held frame, legs mirrored on every other step.
local function sampleStance(body: Body, now: number)
	local velocity = body.root.AssemblyLinearVelocity
	local flatSpeed = Vector2.new(velocity.X, velocity.Z).Magnitude
	local airborne = not onGround(body)
	if body.airborne and not airborne then
		body.landedAt = now
	end
	body.airborne = airborne
	if not airborne then
		body.travel += flatSpeed * (now - body.sampledAt)
	end
	body.sampledAt = now

	local player = body.player
	local gunName, poses = gunOf(player, body.character)
	local pick = GunStance.pick({
		reloading = player ~= nil and player:GetAttribute("Reloading") == true,
		pose = body.character:GetAttribute("MovePose"),
		airborne = airborne,
		verticalSpeed = velocity.Y,
		flatSpeed = flatSpeed,
		sinceLanded = now - body.landedAt,
		sinceShot = now - (player and lastShot[player] or -math.huge),
		travel = body.travel,
	})
	local pose = poses.poses[pick.name] or poses.poses.Stand
	body.gunName = gunName
	body.poses = poses
	body.pose = pose

	for name in body.joints do
		local value = pose.joints[name]
		if pick.mirrored and GunStance.legSwap[name] then
			local other = pose.joints[GunStance.legSwap[name]]
			value = other and GunStance.mirror(other)
		end
		if value then
			body.held[name] = HeldGuns.frame(value)
		end
	end
	jitter(body, if flatSpeed < STILL_SPEED and not airborne then body.idleJitter else 1)
end

local function samplePose(body: Body, now: number)
	if body.soldier then
		sampleStance(body, now)
		return
	end
	local pose = body.character:GetAttribute("MovePose")
	local sliding = pose == "Slide"
	if sliding ~= body.sliding then
		body.sliding = sliding
		body.slideAt = now
		body.slideFrom = body.slideWeight
	end
	local since = now - body.slideAt
	local slide = if sliding then BodyPose.slideIn(since) else BodyPose.slideOut(since, body.slideFrom)
	body.slideWeight = slide
	local settled = math.min(slide, 1)

	-- Crouch moves one held frame at a time toward its target.
	local crouchGoal = if pose == "Crouch" then 1 else 0
	body.crouch += (crouchGoal - body.crouch) * 0.6
	local crouch = math.max(body.crouch, BodyPose.landDip(now - body.landedAt)) * (1 - settled)

	local velocity = body.root.AssemblyLinearVelocity
	local flatSpeed = Vector2.new(velocity.X, velocity.Z).Magnitude
	local lean = BodyPose.runLean(flatSpeed) * (1 - settled) * (1 - crouch)

	for name, joint in body.joints do
		-- A joint no track is moving still shows what we held last, so don't build on that.
		local current = joint.Transform
		if current ~= body.held[name] then
			body.base[name] = current
		end
		local frame = body.base[name] or CFrame.identity
		if CROUCH[name] and crouch > 0 then
			frame = frame:Lerp(CROUCH[name], crouch)
		end
		if SLIDE[name] and slide > 0 then
			frame = frame:Lerp(SLIDE[name], slide)
		end
		body.held[name] = frame
	end

	jitter(body, if flatSpeed < STILL_SPEED and settled == 0 then body.idleJitter else 1)

	local drop = BodyPose.slideDrop * settled + BodyPose.crouchDrop * crouch
	local tilt = BodyPose.slideLean * slide - lean
	local rootFrame = body.held.Root
	if rootFrame then
		body.held.Root = CFrame.new(0, -drop, 0) * rootFrame * CFrame.fromAxisAngle(FORWARD_LEAN_AXIS, math.rad(tilt))
	end
end

-- Runs after the Animator has written its frame, so these poses win.
RunService.PreSimulation:Connect(function()
	local now = os.clock()
	local frame = BodyPose.frame(now)
	for _, body in bodies do
		if frame ~= body.frame then
			body.frame = frame
			samplePose(body, now)
		end
		for name, joint in body.joints do
			local held = body.held[name]
			if held then
				joint.Transform = held
			end
		end
	end
end)

-- Guns go in the hands once the bodies have moved this frame.
RunService.PreRender:Connect(function()
	local camera = workspace.CurrentCamera
	for character, body in bodies do
		if body.soldier then
			local visible = true
			if body.player == Players.LocalPlayer and camera then
				-- Locked first person always hides it: the slide pose moves the head away from the camera,
				-- which follows the root, so the head distance alone let the gun show mid-slide.
				local head = character:FindFirstChild("Head") :: BasePart?
				visible = body.player.CameraMode ~= Enum.CameraMode.LockFirstPerson
					and (head == nil or (camera.CFrame.Position - head.Position).Magnitude > FIRST_PERSON)
			end
			HeldGuns.show(character, body.gunName, body.poses, body.pose, visible)
		end
	end
end)

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

-- Bodies with no player, such as the soldier test dummy.
local CollectionService = game:GetService("CollectionService")
CollectionService:GetInstanceAddedSignal("PosedBody"):Connect(onCharacter)
for _, model in CollectionService:GetTagged("PosedBody") do
	task.spawn(onCharacter, model)
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayer, player)
end
