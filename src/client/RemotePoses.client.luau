-- Draws every body in stop-motion. Whatever the Animator plays is sampled once per held frame,
-- then the crouch, slide, landing and run lean go on top, as on the first-person arms.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local ArmPose = require(Guns:WaitForChild("ArmPose"))
local Zones = require(Guns:WaitForChild("Zones"))
local BodyPose = require(ReplicatedStorage:WaitForChild("Movement"):WaitForChild("BodyPose"))

local FORWARD_LEAN_AXIS = Vector3.xAxis
local STILL_SPEED = 1

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
}
local bodies: { [Model]: Body } = {}

local function isJoint(joint: Instance): boolean
	return joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")
end

local function onCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not character:WaitForChild("LowerTorso", 5) or not humanoid or not root then
		return
	end

	local joints = {}
	for _, descendant in character:GetDescendants() do
		if isJoint(descendant) then
			joints[descendant.Name] = descendant
		end
	end
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
	}
	bodies[character] = body
	humanoid.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Landed then
			body.landedAt = os.clock()
		end
	end)
	character.Destroying:Once(function()
		bodies[character] = nil
	end)
end

local function samplePose(body: Body, now: number)
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

	local strength = if flatSpeed < STILL_SPEED and settled == 0 then body.idleJitter else 1
	local seed = body.seed
	for name, degrees in BodyPose.jitter do
		seed += 1
		if body.held[name] then
			local _, _, _, pitch, yaw, roll = ArmPose.shake(body.frame, seed)
			local turn = math.rad(degrees * BodyPose.jitterScale * strength)
			body.held[name] *= CFrame.Angles(pitch * turn, yaw * turn, roll * turn)
		end
	end

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

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayer, player)
end
