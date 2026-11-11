-- Draws every body. A soldier body (the character has the SoldierRig attribute) shows the gun poses from the
-- pose files: GunStance picks one every frame from what every client can see, the joints ease toward it at full
-- framerate, and HeldGuns puts the gun in its hand.
-- Any other body samples whatever the Animator plays once per held frame, then the crouch, slide, landing and
-- run lean go on top.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local GunConfig = require(Guns:WaitForChild("GunConfig"))
local Movement = ReplicatedStorage:WaitForChild("Movement")
local BodyPose = require(Movement:WaitForChild("BodyPose"))
local BodyPoses = require(Movement:WaitForChild("BodyPoses"))
local GunStance = require(Movement:WaitForChild("GunStance"))
local LegCycle = require(Movement:WaitForChild("LegCycle"))
local ShotKick = require(Movement:WaitForChild("ShotKick"))
local PistolArms = require(Movement:WaitForChild("PistolArms"))
local GunAudio = require(script.Parent:WaitForChild("GunAudio"))
local HeldGuns = require(script.Parent:WaitForChild("HeldGuns"))

local shotsRemote = ReplicatedStorage:WaitForChild("GunRemotes"):WaitForChild("Shots") :: RemoteEvent

local FORWARD_LEAN_AXIS = Vector3.xAxis
local FEET_BELOW_ROOT = 3 -- the soldier's root sits this far above its feet
local GROUND_REACH = 0.6 -- studs below the feet that still count as standing
local FIRST_PERSON = 1.5 -- a camera this close to your own head is first person, so your held gun hides
local POSE_EASE = 14 -- how fast a soldier's joints catch up with the picked pose, per second
-- The run (LegCycle): on the ground and moving, a soldier's legs are worked out every frame from the ground it
-- has covered, in place of the still stride poses, and laid over the pose by a weight that eases in and out.
local LEG_EASE = 10 -- how fast the run takes over the legs and lets go of them, per second
local TURN_EASE = 12 -- how fast the legs follow a change in which way the body is going
-- While the run has the legs, the rest of the body holds one pose, not the two the stride used to flip between.
local STEADY = { Sprint_Pass = "Sprint_Contact", Walk_Pass = "Walk_Contact", Crouch_Idle = "Crouch_Walk" }
local SHOULDERS = 1.5 -- how far the shoulders turn against the hips: past square, so they swing the other way
-- Shooting and aiming, laid over whatever pose the body is in.
-- Looking up and down: the torso, arms and head share the bend, so the gun and the eyes point where the
-- player is looking. Shares of the look's pitch.
local LOOK_EASE = 12 -- how fast the bend follows the look, per second
local LOOK_WAIST = 0.5
local LOOK_ARMS = 0.5
local LOOK_NECK = 0.4
-- Each shot (ShotKick): degrees and studs for a kick of 1.
local KICK_ARMS = math.rad(4) -- the gun's muzzle rises
local KICK_WAIST = math.rad(2.5) -- the torso rocks back
local KICK_TWIST = math.rad(1.6) -- and twists a little, one way then the other
local KICK_BACK = 0.07 -- the hips are pushed back

-- Poses that keep their own body when reloading or shooting and take only the arms.
local KEEPS_BODY = { Slide = true, Jump_Up = true, Fall = true, Land = true }
local ARM_JOINTS = {
	RightShoulder = true,
	RightElbow = true,
	RightWrist = true,
	LeftShoulder = true,
	LeftElbow = true,
	LeftWrist = true,
}
local LEGS = {
	{ hip = "RightHip", knee = "RightKnee", ankle = "RightAnkle", offset = 0, side = 1 },
	{ hip = "LeftHip", knee = "LeftKnee", ankle = "LeftAnkle", offset = 0.5, side = -1 },
}

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
	shown: { [string]: CFrame }, -- soldier bodies: where each joint is on its way to held
	frame: number,
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
	phase: number, -- where the right foot is in its stride, 0 to 1
	legWeight: number, -- how much the run has the legs, 0 to 1
	runSpeed: number, -- the speed the stride is shaped for
	goForward: number, -- which way the body is going relative to the way it faces
	goRight: number,
	kick: ShotKick.Kick, -- the recoil spring
	shotSeen: number, -- the last shot of this body's that has kicked it
	look: number, -- how far up it is looking, radians, eased
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
	local player = Players:GetPlayerFromCharacter(character)
	local body: Body = {
		character = character,
		root = root,
		joints = joints,
		base = {},
		held = {},
		shown = {},
		frame = -1,
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
		phase = 0,
		legWeight = 0,
		runSpeed = 0,
		goForward = 1,
		goRight = 0,
		kick = ShotKick.new(),
		shotSeen = -math.huge,
		look = 0,
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
		table.clear(body.shown)
		table.clear(body.base)
		if not body.soldier then
			HeldGuns.remove(character)
		end
	end)
	-- A body that's replaced is only taken out of the game here, not destroyed, so watch for it leaving too.
	-- Otherwise its gun stays behind where it last stood.
	local function drop()
		if bodies[character] == body then
			bodies[character] = nil
			HeldGuns.remove(character)
		end
	end
	character.Destroying:Once(drop)
	character.AncestryChanged:Connect(function()
		if not character:IsDescendantOf(game) then
			drop()
		end
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

-- A soldier body: the gun pose to ease toward, legs mirrored on every other step.
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
	local dt = math.clamp(now - body.sampledAt, 0, 0.1)
	body.sampledAt = now

	-- The run: on the ground, moving, and not sliding.
	local running = not airborne and flatSpeed > GunStance.moving and body.character:GetAttribute("MovePose") ~= "Slide"
	body.legWeight += ((if running then 1 else 0) - body.legWeight) * (1 - math.exp(-dt * LEG_EASE))
	if running then
		-- Eased, so a change of speed reshapes the stride over a few frames, not at once.
		body.runSpeed += (flatSpeed - body.runSpeed) * (1 - math.exp(-dt * TURN_EASE))
		local advance = flatSpeed * dt / LegCycle.shape(flatSpeed).length
		-- A foot lands: the step sound, yours in your ears and anyone else's from their feet. River found the run
		-- out of time with the sound when the sound kept its own count of the ground, so the feet play it now.
		if LegCycle.lands(body.phase, advance) and body.player then
			if body.player == Players.LocalPlayer then
				local mode = body.player:GetAttribute("MoveMode")
				if mode == "Sprint" or mode == "Walk" then
					GunAudio.playStep()
				end
			elseif body.character:GetAttribute("MovePose") == "Normal" then
				GunAudio.playFarStep(body.root.Position - Vector3.new(0, FEET_BELOW_ROOT, 0))
			end
		end
		body.phase = (body.phase + advance) % 1
		local going = body.root.CFrame:VectorToObjectSpace(Vector3.new(velocity.X, 0, velocity.Z)) / flatSpeed
		local turn = 1 - math.exp(-dt * TURN_EASE)
		body.goForward += (-going.Z - body.goForward) * turn
		body.goRight += (going.X - body.goRight) * turn
	end

	local player = body.player
	local gunName, poses = gunOf(player, body.character)
	local reloading = player ~= nil and player:GetAttribute("Reloading") == true
	local shotAt = player and lastShot[player] or -math.huge
	local pick = GunStance.pick({
		reloading = false, -- worked out just below
		pose = body.character:GetAttribute("MovePose"),
		airborne = airborne,
		verticalSpeed = velocity.Y,
		flatSpeed = flatSpeed,
		sinceLanded = now - body.landedAt,
		sinceShot = now - shotAt,
		travel = body.travel,
	})
	if running and STEADY[pick.name] then
		pick = { name = STEADY[pick.name], mirrored = false }
	elseif running then
		pick = { name = pick.name, mirrored = false }
	end
	-- Reloading: the reload pose is a standing one, so in a slide or in the air only its arms are used and the
	-- rest of the body stays as it was. (River: reloading in a slide stood the torso up.)
	local arms = nil
	if reloading and poses.poses.Reload then
		if KEEPS_BODY[pick.name] then
			arms = poses.poses.Reload
		else
			pick = { name = "Reload", mirrored = false }
		end
	elseif KEEPS_BODY[pick.name] and poses.poses.Fire and now - shotAt < GunStance.fireTime then
		arms = poses.poses.Fire -- shooting in a slide or the air: the gun still comes up
	end

	-- A new shot kicks the body.
	if shotAt > body.shotSeen then
		body.shotSeen = shotAt
		local id = if player then player:GetAttribute("GunId") else body.character:GetAttribute("GunId")
		local gun = id and GunConfig.guns[id]
		ShotKick.hit(body.kick, ShotKick.strength(gun and gun.kick))
	end
	-- Where it is looking: your own from this client, anyone else's from the server.
	local pitch = if player == Players.LocalPlayer
		then player:GetAttribute("LookPitch")
		else body.character:GetAttribute("LookPitch")
	local lookGoal = math.rad(if type(pitch) == "number" then pitch else 0)
	body.look += (lookGoal - body.look) * (1 - math.exp(-dt * LOOK_EASE))
	local pose = poses.poses[pick.name] or poses.poses.Stand
	body.gunName = gunName
	body.poses = poses
	body.pose = arms or pose -- the gun goes where the hands are

	-- The pistol's arms come from PistolArms, not the pose file: held out flat and level as first person has
	-- it, with the left arm down at the side. A reload keeps the pose file's arms.
	local pistolArms = if poses == BodyPoses["Energy Pistol"] and pick.name ~= "Reload" and arms ~= poses.poses.Reload
		then PistolArms[pick.name]
		else nil
	for name in body.joints do
		local value = (if arms and ARM_JOINTS[name] then arms else pose).joints[name]
		if pistolArms and pistolArms[name] then
			value = pistolArms[name]
		end
		if pick.mirrored and GunStance.legSwap[name] then
			local other = pose.joints[GunStance.legSwap[name]]
			value = other and GunStance.mirror(other)
		end
		if value then
			body.held[name] = HeldGuns.frame(value)
		end
	end
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


	local drop = BodyPose.slideDrop * settled + BodyPose.crouchDrop * crouch
	local tilt = BodyPose.slideLean * slide - lean
	local rootFrame = body.held.Root
	if rootFrame then
		body.held.Root = CFrame.new(0, -drop, 0) * rootFrame * CFrame.fromAxisAngle(FORWARD_LEAN_AXIS, math.rad(tilt))
	end
end

-- Lays the run over a soldier's legs and hips. The hips' height and lean come from the pose being shown, so the
-- feet stay on the ground whatever the rest of the body is doing.
local function applyRun(body: Body)
	local weight = body.legWeight
	if weight < 0.001 then
		return
	end
	local rootShown = body.shown.Root or CFrame.identity
	-- The hips run level. The pose's hips are tipped a little to one side, which looked fine as one of two poses
	-- flipping but held still made the whole lower body lean left (River). Their height, forward lean, how far
	-- forward they sit and their turn are kept: the upper body's aim is built on that turn (the shooting pose
	-- stands side-on), so the legs allow for it below and run straight under turned hips.
	local tilt, turned = rootShown:ToEulerAnglesYXZ()
	rootShown = rootShown:Lerp(CFrame.new(0, rootShown.Y, rootShown.Z) * CFrame.fromEulerAnglesYXZ(tilt, turned, 0), weight)
	local shape = LegCycle.shape(body.runSpeed)
	local bob = LegCycle.bob(body.phase, shape) * weight
	-- The swagger: the hips sway over the planted foot, turn with the stride and drop on the swinging side, and
	-- the shoulders turn the other way. The head stays facing ahead.
	local hips = LegCycle.hips(body.phase, shape, body.runSpeed)
	hips.sway *= weight
	hips.twist *= weight
	hips.roll *= weight
	local underLegs = { sway = hips.sway, twist = hips.twist + turned, roll = hips.roll }
	local lean = rootShown:ToEulerAnglesYXZ() -- the hips' pitch; forward is negative
	local height = LegCycle.restHeight + rootShown.Y + bob
	for _, names in LEGS do
		local leg = LegCycle.leg(body.phase + names.offset, shape, body.goForward, body.goRight, height, names.side, underLegs)
		local frames = {
			[names.hip] = CFrame.Angles(0, 0, leg.roll) * CFrame.Angles(leg.pitch - lean - LegCycle.restHip, 0, 0),
			[names.knee] = CFrame.Angles(LegCycle.restKnee - leg.bend, 0, 0),
			[names.ankle] = CFrame.Angles(leg.foot - leg.pitch + leg.bend - LegCycle.restAnkle, 0, 0) * CFrame.Angles(0, 0, -leg.roll),
		}
		for name, frame in frames do
			local joint = body.joints[name]
			if joint then
				joint.Transform = (body.shown[name] or CFrame.identity):Lerp(frame, weight)
			end
		end
	end
	local rootJoint = body.joints.Root
	if rootJoint then
		rootJoint.Transform = CFrame.new(rootShown.Position + Vector3.new(hips.sway, bob, 0))
			* CFrame.Angles(0, hips.twist, 0)
			* rootShown.Rotation
			* CFrame.Angles(0, 0, hips.roll)
	end
	local waist, neck = body.joints.Waist, body.joints.Neck
	if waist and body.shown.Waist then
		waist.Transform = body.shown.Waist * CFrame.Angles(0, -hips.twist * SHOULDERS, -hips.roll)
	end
	if neck and body.shown.Neck then
		neck.Transform = body.shown.Neck * CFrame.Angles(0, hips.twist * (SHOULDERS - 1), 0)
	end
end

-- Bends the upper body to where the player is looking and kicks it with each shot, on top of whatever the
-- pose and the run have set. The turns go on the torso's side of each joint, so they are about the torso's own
-- axes whatever the pose has done with the arms.
local function applyAim(body: Body, dt: number)
	local kick = ShotKick.step(body.kick, dt)
	local look = body.look
	if math.abs(look) < 0.001 and math.abs(kick) < 0.001 then
		return
	end
	local joints = body.joints
	local twist = kick * KICK_TWIST * body.kick.side
	if joints.Waist then
		joints.Waist.Transform = CFrame.Angles(look * LOOK_WAIST + kick * KICK_WAIST, twist, 0) * joints.Waist.Transform
	end
	local arms = CFrame.Angles(look * LOOK_ARMS + kick * KICK_ARMS, 0, 0)
	for _, name in { "RightShoulder", "LeftShoulder" } do
		if joints[name] then
			joints[name].Transform = arms * joints[name].Transform
		end
	end
	if joints.Neck then
		-- The head carries on to the full look, and doesn't rock or twist with the shot.
		joints.Neck.Transform = CFrame.Angles(look * LOOK_NECK - kick * KICK_WAIST, -twist, 0) * joints.Neck.Transform
	end
	if joints.Root and kick > 0.001 then
		joints.Root.Transform = CFrame.new(0, 0, kick * KICK_BACK) * joints.Root.Transform
	end
end

-- Runs after the Animator has written its frame, so these poses win.
RunService.PreSimulation:Connect(function(dt: number)
	local now = os.clock()
	local frame = BodyPose.frame(now)
	local ease = 1 - math.exp(-dt * POSE_EASE)
	for _, body in bodies do
		if body.soldier then
			sampleStance(body, now)
			for name, joint in body.joints do
				local target = body.held[name]
				if target then
					local shown = body.shown[name]
					shown = if shown then shown:Lerp(target, ease) else target
					body.shown[name] = shown
					joint.Transform = shown
				end
			end
			applyRun(body)
			applyAim(body, dt)
			continue
		end
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
				visible = body.player:GetAttribute("ThirdPersonTest") == true -- the test view from behind
					or (
						body.player.CameraMode ~= Enum.CameraMode.LockFirstPerson
						and (head == nil or (camera.CFrame.Position - head.Position).Magnitude > FIRST_PERSON)
					)
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
