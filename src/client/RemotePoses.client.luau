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
local BodyHands = require(script.Parent:WaitForChild("BodyHands"))
local BodyCards = require(script.Parent:WaitForChild("BodyCards"))
local SlideSparks = require(script.Parent:WaitForChild("SlideSparks"))
local CardFlourish = require(Guns:WaitForChild("CardFlourish"))
local ArmReach = require(script.Parent:WaitForChild("ArmReach"))
local AkReload = require(Guns:WaitForChild("AkReload"))
local BodyReloads = require(Guns:WaitForChild("BodyReloads"))

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
-- Reloads keyed in code, by the gun's display name: the same reload first person plays (the hands, the
-- magazine, the bolt and the gun's turn), put on the third-person body. perMetre is the stored model's studs to a
-- metre and origin is where the reload's own origin is from the model's middle, in metres, both as GunView has
-- them for first person.
-- A reload without them (BodyReloads) is keyed straight in the held gun's own studs.
-- outro is how long before its end, in the reload's own seconds, a reload starts easing back to the base pose:
-- the gun, both hands and the body all lean toward where the pose has them while the reload's last moves are
-- still playing, so the two run together as one motion (River, 2026-11-11). The M57's is short, so its last
-- flourish (the gun snapped over flat after the bolt) still plays.
local CODED_RELOADS: { [string]: { reload: any, perMetre: number?, origin: Vector3?, outro: number } } = {
	M57 = { reload = AkReload, perMetre = 91.09, origin = Vector3.new(-0.011, 0.0535, 0.137), outro = 0.26 },
	["Energy Pistol"] = { reload = BodyReloads["Energy Pistol"], outro = 0.42 },
	Longscope = { reload = BodyReloads.Longscope, outro = 0.45 },
}
local RELOAD_BLEND = 0.08 -- of the reload's own seconds: how long the arms take to pass to it and back
-- For reloads marked natural (BodyReloads):
local RELOAD_EASE = 20 -- how fast the hands and gun follow the reload, per second: takes the snap off single-frame jumps (30 at first; River asked for smoother)
local RELOAD_BODY_HIPS_YAW = 0.35 -- where a reload says how the torso leans: the hips' share of its turn
local RELOAD_BODY_HIPS_SHIFT = 0.9 -- and studs the hips shift per radian it tips, the other way
local RELOAD_WRIST_MOST = math.rad(60) -- the furthest the left wrist is bent to match a palm
-- The body goes with the reload (River: "make the torso turn with the reload ... more natural and more swaggy").
-- The gun's own turn already swings, overshoots and rebounds, so the torso takes a share of it: leaning back as
-- the muzzle comes up, turning with it, and tipping over with its roll. The hips take a little, and the head
-- stays more level and looks down at the hands while the left one is on the magazine.
local RELOAD_TORSO = { pitch = 0.18, yaw = 0.9, roll = 0.11 } -- shares of the gun's turn
local RELOAD_HIPS_YAW = 0.3 -- the hips' share of the gun's yaw
local RELOAD_HIPS_SHIFT = 0.07 -- studs the hips shift per radian the gun rolls, the other way
local RELOAD_HEAD_LEVEL = 0.7 -- how much of the torso's turn and tip the head undoes
local RELOAD_HEAD_DOWN = math.rad(14) -- how far the head drops to watch the magazine go in
-- Roughly which way each elbow points while its hand is placed, in the torso's space.
local ELBOW_WAYS = { Right = Vector3.new(0.5, -1, 0.3), Left = Vector3.new(-0.6, -1, 0.25) }

-- A wall jump (the client says when, and which way is out of the wall): the body leans away from the wall, the
-- leg nearer it shoves off it and the other tucks up, then it all eases back into the jump pose.
local WALL_KICK_SECONDS = 0.45
local WALL_KICK_ATTACK = 0.12 -- the share of that it takes to hit the full shove
local WALL_KICK_LEAN = math.rad(20)
local WALL_KICK_LEG = math.rad(42) -- how far the kicking leg swings toward the wall
local WALL_KICK_TUCK = math.rad(50) -- how far the other leg's hip and knee fold

-- The cards: with a card out the body puts its gun away and plays first person's own deck flourish
-- (CardFlourish), then holds the deck; turning to the next card flips one across, and using the card crushes it in
-- the right fist. First person works all of that out from the camera, in front of the eye. On the body it hangs
-- from a frame in front of the chest, turned with the look, and both arms are bent to the flourish's palms.
-- That frame, from the middle of the upper torso, facing the way the body faces: the flourish sits 1.4 ahead of
-- it and 0.36 below. It was fixed to the root at first, 0.45 further back. But the poses carry the chest off the
-- root (a quarter stud to the right standing, well forward running), so the cards sat too close, off to the
-- left, and behind the chest on the run (River, 2026-11-11).
-- Then it followed the middle of the torso but stayed upright, and the run leans the torso nearly 30 degrees:
-- the shoulders and head went forward and down and the cards didn't, so the arms trailed behind the body on the
-- move. Now it hangs from the top of the torso and leans with it.
local CARD_NECK = Vector3.new(0, 0.72, 0) -- where it hangs from, on the upper torso
local CARD_OUT = CFrame.new(0, 0, -0.45) -- and how far out from there, along its own leaned line
local CARD_LEAN = 0.9 -- the share of the torso's forward lean it takes (none of its twist or tip)
local CARD_LOOK = 0.5 -- the share of the look's pitch it tips with
local CARD_BLEND = 0.12 -- seconds the arms take to pass to the cards
-- A jump with the cards out is kept quiet. The full jump drives a knee up to the chest, where the deck is being
-- worked, tips the body about and drops into a deep crouch, and with the flourish going on in front it all looked
-- goofy (River, 2026-11-11). So the legs mostly hang as they do coming down, the body tips far less, and the
-- landing is shallower.
local CARD_AIR_CALM = 0.8 -- at least this much of the coming-down pose through the whole jump
local CARD_AIR_TIP = 0.3 -- the share of the body's tip in the air
local CARD_LAND_SHARE = 0.45 -- the share of the landing crouch
-- With the cards out the torso is stood up: this share of whatever forward lean the pose has is taken back out at
-- the waist. The poses lean the torso in to shoulder a gun, and over a deck held out in front that read as
-- hunched, more leaned in than with the AK or the pistol (River, 2026-11-11).
local CARD_UPRIGHT = 0.8

-- The jump. The pose files have one pose going up (a knee driven high), one coming down and one deep landing
-- crouch, and the body used to snap between them. Now:
-- going up blends into coming down by how fast the body is rising or falling, so the legs unfold through the top;
-- the knee that drives up is whichever leg was swinging forward at takeoff, so it changes from jump to jump;
-- the body tips forward off the ground, back over the top, and into the way it's travelling;
-- and the landing crouch is as deep as the fall was fast, hit at once and risen out of, where every landing,
-- even off a kerb, used to drop into the full crouch for a quarter second.
local AIR_FULL = 22 -- studs a second up or down that is fully "going up" or "coming down"
local AIR_TIP = { up = math.rad(-9), down = math.rad(7) } -- the hips' lean forward going up and back coming down
local AIR_INTO = math.rad(9) -- lean into the way it's travelling, at a full run
-- The arms go out to the sides in the air, for balance (River: "wave the arms to the side like with the gun in
-- hand"): the right arm swings out with the gun in its hand, the left comes off the gun and swings out the other
-- way, both lifting a little more over the top of the jump, and they come back in on landing. Not while
-- shooting, reloading or with the cards out, when the hands are busy.
local AIR_ARMS_OUT = { Right = math.rad(46), Left = math.rad(68) } -- how far each arm swings out from the body (34 and 52 at first; River asked for a bit more)
local AIR_ARMS_UP = math.rad(18) -- and how much further they lift over the top
local AIR_ARMS_EASE = 9 -- how fast they go out and come back, per second
local AIR_ARMS_QUIET = 0.6 -- seconds after a shot they stay on the gun
local AIR_ARMS_BACK = 5 -- studs a second of fall at which they start back to the gun
local AIR_ARMS_IN = 13 -- how fast they come back, per second: quicker than they go out
local LAND_HIT = 0.05 -- seconds to drop into the landing
local LAND_RISE = 0.42 -- and to rise out of it
local LAND_FULL = 50 -- studs a second of fall that lands in the full crouch
local LAND_LEAST = 0.18 -- the share of the crouch any landing gets

-- The slide. The pose is a still one, so it gets some life:
-- going in, the body whips back past the pose and settles, and it shudders a little with the ground while moving;
-- the left hand comes off the gun and drags its fingertips along the ground beside the hip, throwing sparks and
-- dust (SlideSparks), with the torso tipped a little over that hand. Not while reloading or with the cards out.
local SLIDE_WHIP = math.rad(11) -- how far past the pose the lean-back goes on the way in
local SLIDE_SHUDDER = 0.035 -- studs the hips rattle at full speed
local SLIDE_TIP = math.rad(9) -- the torso tips to its left, over the dragging hand
local SLIDE_HAND = Vector3.new(-0.5, 0, 0.4) -- where the hand goes down, from under the left shoulder: out and back
local SLIDE_HAND_UP = 0.5 -- the hand's middle above the ground, so its fingertips touch
local SLIDE_HAND_IN = 0.16 -- seconds the hand takes to get down

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
	kickStamp: any, -- the wall jump's stamp as last seen, to spot a new one
	wallKickAt: number, -- when this body last kicked off a wall
	wallWay: Vector3, -- and which way was out of the wall
	cards: any, -- the card hand as last seen and when things happened to it, while a card is out
	cardPose: any, -- this frame's flourish pose, its view from the torso and the crush, while a card is out
	fallSpeed: number, -- the fastest it has fallen this time in the air
	armsOut: number, -- how far out the arms are for a jump, 0 to 1, eased
	landHard: number, -- how hard the last landing was, 0 to 1
	airLead: string, -- which knee drives up this jump: the pose's own ("Right") or the other
	slideSince: number, -- when the slide being shown began
	slideHand: Vector3?, -- where the dragging hand is on the ground this frame, for the sparks
	wasReloading: boolean,
	reloadAt: number?, -- when the reload being played started
	codedAt: number?, -- how far into a coded reload it is, in the reload's own seconds
	arms: { [string]: ArmReach.Arm }, -- each arm's lengths, once measured
	moves: any, -- this frame's moves of the gun, its magazine and its bolt, from a coded reload
	eased: any, -- a natural reload's gun and hands as last shown, from the torso, to ease from
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
		kickStamp = if player == Players.LocalPlayer then player:GetAttribute("WallKickAt") else character:GetAttribute("WallKickAt"),
		wallKickAt = -math.huge,
		wallWay = Vector3.xAxis,
		cards = nil,
		cardPose = nil,
		fallSpeed = 0,
		armsOut = 0,
		landHard = 0,
		airLead = "Right",
		slideSince = -math.huge,
		slideHand = nil,
		wasReloading = false,
		reloadAt = nil,
		codedAt = nil,
		arms = {},
		moves = nil,
		eased = nil,
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
			BodyHands.remove(character)
			BodyCards.remove(character)
			SlideSparks.remove(character)
		end
	end)
	-- A body that's replaced is only taken out of the game here, not destroyed, so watch for it leaving too.
	-- Otherwise its gun stays behind where it last stood.
	local function drop()
		if bodies[character] == body then
			bodies[character] = nil
			HeldGuns.remove(character)
			BodyHands.remove(character)
			BodyCards.remove(character)
			SlideSparks.remove(character)
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
		body.landHard = math.clamp(body.fallSpeed / LAND_FULL, LAND_LEAST, 1)
		body.fallSpeed = 0
	elseif airborne and not body.airborne then
		-- The right foot is planted for the first part of the stride, so in its first half the left leg is the
		-- one swinging forward, and it carries on up.
		body.airLead = if body.phase < 0.5 then "Left" else "Right"
	end
	if airborne then
		body.fallSpeed = math.max(body.fallSpeed, -velocity.Y)
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
		sinceLanded = math.huge, -- the landing is blended in below, as deep as the fall was hard
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
	-- A gun with a coded reload stands the way it reloads. The reload plays over the Fire pose, which stands up
	-- straight with the gun up, and the Stand pose doesn't, so the body shifted stance going into every reload and
	-- again coming out, however the reload's ending was eased. River: "just make the base pose stand up straight
	-- how it is when your reloading", first for the pistol, then the AK (M57) and the sniper too. So those guns
	-- are held up and aimed whenever the body stands; their Stand poses are unused.
	if gunName and CODED_RELOADS[gunName] and pick.name == "Stand" and poses.poses.Fire then
		pick = { name = "Fire", mirrored = false }
	end

	-- A coded reload runs from when the reload starts to its own end, a little after the gun is loaded, unless
	-- it is cut short.
	if reloading and not body.wasReloading then
		body.reloadAt = now
	end
	body.wasReloading = reloading
	local coded = gunName and CODED_RELOADS[gunName]
	body.codedAt = nil
	if coded and body.reloadAt then
		local id = if player then player:GetAttribute("GunId") else body.character:GetAttribute("GunId")
		local config = id and GunConfig.guns[id]
		local at = (now - body.reloadAt) * coded.reload.SOUND / (config and config.reload or 2) + (coded.reload.lead or 0)
		if at >= coded.reload.LENGTH or (not reloading and at < coded.reload.SOUND * 0.95) then
			body.reloadAt = nil
		else
			body.codedAt = at
		end
	elseif not reloading then
		body.reloadAt = nil
	end

	local arms = nil
	if body.codedAt and poses.poses.Fire then
		-- The reload is played over the gun held up, as first person plays it over its hold.
		if KEEPS_BODY[pick.name] then
			arms = poses.poses.Fire
		else
			pick = { name = "Fire", mirrored = false }
		end
	elseif reloading and poses.poses.Reload then
		if KEEPS_BODY[pick.name] then
			arms = poses.poses.Reload
		else
			pick = { name = "Reload", mirrored = false }
		end
	elseif KEEPS_BODY[pick.name] and poses.poses.Fire and now - shotAt < GunStance.fireTime then
		arms = poses.poses.Fire -- shooting in a slide or the air: the gun still comes up
	end

	-- The cards, on first person's own timing (GunView's showCard): the flourish from when a card comes out, a
	-- flip for each turn to the next card (which skips what's left of the flourish), and the crush when one is used.
	do
		local hand: Instance = if player == Players.LocalPlayer then player else body.character
		local out = hand:GetAttribute("CardsOut") == true
		local turns = hand:GetAttribute("CardTurns") or 0
		local used = hand:GetAttribute("CardUsed") or 0
		local cards = body.cards
		if cards and out and cards.crushAt then
			cards = nil -- another card came out mid-crush
		end
		if cards and not out then
			if not cards.crushAt and used ~= cards.used then
				cards.crushAt = now
			end
			if not cards.crushAt or now - cards.crushAt >= CardFlourish.CRUSH then
				cards = nil
			end
		end
		if out and not cards then
			cards = { at = now, crushAt = nil, used = used, seenTurns = turns, turns = 0, turnAt = now, life = math.random() * 100 }
		end
		body.cards = cards
		body.cardPose = nil
		if cards then
			local elapsed = (cards.crushAt or now) - cards.at
			if turns ~= cards.seenTurns then
				cards.seenTurns = turns
				cards.turns += 1
				cards.turnAt = now
				if elapsed < CardFlourish.LENGTH then
					cards.at = now - CardFlourish.LENGTH
					elapsed = CardFlourish.LENGTH
				end
			end
			local crush = if cards.crushAt then CardFlourish.crush(elapsed, now - cards.crushAt, cards.turns) else nil
			local pose = if crush
				then crush.pose
				elseif cards.turns > 0 then CardFlourish.turn(cards.turns, now - cards.turnAt)
				else CardFlourish.at(CardFlourish.tempo(elapsed, cards.life + now))
			pose = CardFlourish.sway(pose, cards.life + now)
			-- The card that shows its face: the one flipped up at the flourish's end, or turned to since.
			local faceUp = if cards.turns > 0 or elapsed >= CardFlourish.LENGTH - 0.3 or crush then CardFlourish.top(cards.turns) else nil
			body.cardPose = { pose = pose, faceUp = faceUp, gone = if crush then crush.crushed else nil, since = now - cards.at }
		end
	end

	-- A new wall jump: your own from this client, anyone else's from the server.
	local kicker: Instance = if player == Players.LocalPlayer then player else body.character
	local stamp = kicker:GetAttribute("WallKickAt")
	if stamp ~= body.kickStamp then
		body.kickStamp = stamp
		local way = kicker:GetAttribute("WallKick")
		if stamp and typeof(way) == "Vector3" and way.Magnitude > 0.5 then
			body.wallKickAt = now
			body.wallWay = way.Unit
		end
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

	-- A second pose mixed into the picked one: coming down into going up, or the landing crouch into whatever
	-- the body is doing on the ground.
	local mixName, mixShare = nil, 0
	if pick.name == "Jump_Up" or pick.name == "Fall" then
		pick = { name = "Jump_Up", mirrored = body.airLead == "Left" }
		pose = poses.poses.Jump_Up or pose
		local falling = math.clamp(0.5 - velocity.Y / (2 * AIR_FULL), 0, 1)
		mixName, mixShare = "Fall", falling * falling * (3 - 2 * falling)
		if body.cardPose then
			mixShare = math.max(mixShare, CARD_AIR_CALM)
		end
	elseif not airborne and body.character:GetAttribute("MovePose") ~= "Slide" then
		local since = now - body.landedAt
		if since < LAND_HIT + LAND_RISE then
			local rise = math.clamp((since - LAND_HIT) / LAND_RISE, 0, 1)
			mixName = "Land"
			mixShare = body.landHard * math.min(since / LAND_HIT, 1) * (1 - rise * rise * (3 - 2 * rise))
			if body.cardPose then
				mixShare *= CARD_LAND_SHARE
			end
		end
	end
	local mix = mixName and mixShare > 0.001 and poses.poses[mixName] or nil
	local mixArms = if mix and pistolArms then PistolArms[mixName] else nil

	for name in body.joints do
		local fromArms = arms ~= nil and ARM_JOINTS[name] == true
		local value = (if fromArms then arms else pose).joints[name]
		local other = if mix and not fromArms then mix.joints[name] else nil
		if pistolArms and pistolArms[name] then
			value = pistolArms[name]
			other = if mix then (mixArms and mixArms[name]) or other else nil
		end
		if pick.mirrored and GunStance.legSwap[name] then
			local swapped = pose.joints[GunStance.legSwap[name]]
			value = swapped and GunStance.mirror(swapped)
			local otherSwapped = mix and mix.joints[GunStance.legSwap[name]]
			other = if otherSwapped then GunStance.mirror(otherSwapped) else other
		end
		if value then
			local frame = HeldGuns.frame(value)
			body.held[name] = if other then frame:Lerp(HeldGuns.frame(other), mixShare) else frame
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
	-- The pistol is held in one hand: the other arm hangs at the side and doesn't lift with the aim or the shot.
	local oneHanded = body.poses == BodyPoses["Energy Pistol"]
	for _, name in { "RightShoulder", "LeftShoulder" } do
		if joints[name] and not (oneHanded and name == "LeftShoulder") then
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

-- In the air: the hips tip forward going up and back coming down, and lean into the way the body is travelling.
local function applyAir(body: Body, dt: number, now: number)
	local joint = body.joints.Root
	local inAir = body.airborne and body.character:GetAttribute("MovePose") ~= "Slide"
	local velocity = body.root.AssemblyLinearVelocity
	local rising = math.clamp(velocity.Y / AIR_FULL, -1, 1)

	-- The arms: out while in the air with free hands, eased both ways so they swing out and come back in.
	local shotAt = body.player and lastShot[body.player] or -math.huge
	-- They are out on the way up and over the top, and come back onto the gun once the body is properly coming
	-- down, so it lands in its shooting position (River: "bring it back to shooting position before hitting the
	-- ground"). A jump's fall from its top takes about 0.4s and the arms take about a quarter second to come in.
	local free = inAir
		and velocity.Y > -AIR_ARMS_BACK
		and not body.cardPose
		and not body.codedAt
		and not body.wasReloading
		and now - shotAt > AIR_ARMS_QUIET
	body.armsOut += ((if free then 1 else 0) - body.armsOut) * (1 - math.exp(-dt * (if free then AIR_ARMS_EASE else AIR_ARMS_IN)))
	if body.armsOut > 0.01 then
		local over = 1 - math.abs(rising) -- most over the top of the jump
		for side, sign in { Right = 1, Left = -1 } do
			local shoulder = body.joints[side .. "Shoulder"]
			if shoulder then
				-- About the torso's own axes: a turn about Z swings a hanging arm out to the body's right.
				local out = (AIR_ARMS_OUT[side] + AIR_ARMS_UP * over) * body.armsOut
				shoulder.Transform = CFrame.Angles(0, 0, sign * out) * shoulder.Transform
			end
		end
		-- The left arm straightens some as it leaves the gun.
		local elbow = body.joints.LeftElbow
		if elbow then
			elbow.Transform = elbow.Transform:Lerp(CFrame.Angles(math.rad(18), 0, 0), 0.6 * body.armsOut)
		end
	end

	if not inAir or not joint then
		return
	end
	local tip = if rising > 0 then AIR_TIP.up * rising else AIR_TIP.down * -rising
	if body.cardPose then
		tip *= CARD_AIR_TIP
	end
	local going = body.root.CFrame:VectorToObjectSpace(Vector3.new(velocity.X, 0, velocity.Z)) / 18
	local forward, right = math.clamp(-going.Z, -1, 1), math.clamp(going.X, -1, 1)
	joint.Transform = joint.Transform * CFrame.Angles(tip - forward * AIR_INTO, 0, -right * AIR_INTO)
end

-- The slide's own life, over its pose. Returns nothing; leaves where the dragging hand is for the sparks.
local function applySlide(body: Body, now: number)
	body.slideHand = nil
	local joints = body.joints
	if body.character:GetAttribute("MovePose") ~= "Slide" or body.airborne then
		body.slideSince = -math.huge
		return
	end
	if body.slideSince == -math.huge then
		body.slideSince = now
	end
	local since = now - body.slideSince
	local velocity = body.root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local much = math.clamp(speed / 28, 0, 1)
	-- The whip going in, and the shudder while it moves.
	local whip = SLIDE_WHIP * math.exp(-since * 7) * math.sin(math.min(since * 11, math.pi))
	local shudder = SLIDE_SHUDDER * much * math.sin(now * 61) * math.sin(now * 23)
	if joints.Root then
		joints.Root.Transform = CFrame.new(0, shudder, 0) * joints.Root.Transform * CFrame.Angles(whip, 0, 0)
	end
	-- The hand: not when the arms are busy with a reload or the cards.
	if body.cardPose or body.codedAt or body.wasReloading then
		return
	end
	for _, name in { "Root", "Waist", "LeftShoulder", "LeftElbow", "LeftWrist" } do
		if not joints[name] or not joints[name]:IsA("Motor6D") then
			return
		end
	end
	local reach = math.clamp(since / SLIDE_HAND_IN, 0, 1)
	reach = reach * reach * (3 - 2 * reach)
	joints.Waist.Transform = CFrame.Angles(0, 0, SLIDE_TIP * reach) * joints.Waist.Transform
	if joints.Neck then
		joints.Neck.Transform = CFrame.Angles(0, 0, -SLIDE_TIP * reach) * joints.Neck.Transform -- the head stays level
	end
	local torso = body.root.CFrame * joints.Root.C0 * joints.Root.Transform * joints.Root.C1:Inverse()
	torso = torso * joints.Waist.C0 * joints.Waist.Transform * joints.Waist.C1:Inverse()
	local shoulder, elbow, wrist = joints.LeftShoulder, joints.LeftElbow, joints.LeftWrist
	local base = torso * shoulder.C0
	local facing = body.root.CFrame.Rotation
	local over = base.Position + facing * SLIDE_HAND
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { body.character }
	local ground = workspace:Raycast(over + Vector3.new(0, 1, 0), Vector3.new(0, -5, 0), params)
	if not ground then
		return
	end
	-- Fingers pointing down and back, palm toward the body.
	local fingers = (facing * Vector3.new(-0.15, -1, 0.45)).Unit
	local palmUp = facing * Vector3.new(1, 0, 0)
	local x = (palmUp - fingers * palmUp:Dot(fingers)).Unit
	local palm = CFrame.fromMatrix(ground.Position + Vector3.new(0, SLIDE_HAND_UP, 0), x, fingers, x:Cross(fingers))
	local arm = body.arms.Left
	if not arm then
		arm = ArmReach.measure(shoulder, elbow, wrist)
		body.arms.Left = arm
	end
	local turns = { ArmReach.solve(arm, base, palm * BodyHands.handOnPalm("Left"), facing * Vector3.new(-0.6, 0, 1)) }
	for index, joint in { shoulder, elbow, wrist } do
		joint.Transform = joint.Transform:Lerp(turns[index], reach)
	end
	if reach > 0.7 and speed > 6 then
		body.slideHand = ground.Position
	end
end

-- The wall jump, over the jump pose.
local function applyWallKick(body: Body, now: number)
	local through = (now - body.wallKickAt) / WALL_KICK_SECONDS
	if through < 0 or through >= 1 then
		return
	end
	local joints = body.joints
	-- A quick shove that eases away, and a slower tuck that follows it.
	local attack = math.clamp(through / WALL_KICK_ATTACK, 0, 1)
	local shove = attack * attack * (3 - 2 * attack) * (1 - through) ^ 2
	local tuck = math.sin(math.pi * through) ^ 2
	-- Out of the wall, as the body sees it: +X its right, +Z behind it.
	local out = body.root.CFrame:VectorToObjectSpace(body.wallWay)
	local flat = Vector3.new(out.X, 0, out.Z)
	if flat.Magnitude < 0.1 then
		return
	end
	flat = flat.Unit
	-- Leaning away: a turn about Z tips the top to the left, one about X tips it back.
	if joints.Root then
		joints.Root.Transform = joints.Root.Transform * CFrame.Angles(flat.Z * WALL_KICK_LEAN * shove, 0, -flat.X * WALL_KICK_LEAN * shove)
	end
	-- The leg on the wall's side kicks; with the wall dead ahead or behind, the right one.
	local kicking = if flat.X > 0.3 then "Left" else "Right"
	local other = if kicking == "Left" then "Right" else "Left"
	local hip, knee = joints[kicking .. "Hip"], joints[kicking .. "Knee"]
	if hip and knee then
		-- Toward the wall: a hip turn about Z swings the foot to the right, one about X swings it forward.
		hip.Transform = CFrame.Angles(flat.Z * WALL_KICK_LEG * shove, 0, -flat.X * WALL_KICK_LEG * shove) * hip.Transform
		knee.Transform = knee.Transform:Lerp(CFrame.Angles(LegCycle.restKnee, 0, 0), shove) -- straight as it shoves
	end
	local otherHip, otherKnee = joints[other .. "Hip"], joints[other .. "Knee"]
	if otherHip and otherKnee then
		otherHip.Transform = CFrame.Angles(WALL_KICK_TUCK * tuck, 0, 0) * otherHip.Transform
		otherKnee.Transform = otherKnee.Transform * CFrame.Angles(-WALL_KICK_TUCK * 1.3 * tuck, 0, 0)
	end
end

local function through(frame: CFrame, joint: Motor6D): CFrame
	return frame * joint.C0 * joint.Transform * joint.C1:Inverse()
end

-- A card out: both arms are bent to the flourish's palms and the head drops to the cards. Leaves where the
-- flourish hangs, from the torso, for the deck to be placed once the body has moved.
local function applyCards(body: Body)
	local shown = body.cardPose
	local joints = body.joints
	if not shown then
		return
	end
	for _, name in { "Root", "Waist", "RightShoulder", "RightElbow", "RightWrist", "LeftShoulder", "LeftElbow", "LeftWrist" } do
		if not joints[name] or not joints[name]:IsA("Motor6D") then
			return
		end
	end
	local blend = math.clamp(shown.since / CARD_BLEND, 0, 1)
	local torso = through(through(body.root.CFrame, joints.Root), joints.Waist)
	local facing = body.root.CFrame.Rotation
	local lean = (facing:Inverse() * torso.Rotation):ToEulerAnglesYXZ() -- the torso's pitch from upright; forward is negative
	if lean < 0 then
		local back = -lean * CARD_UPRIGHT * blend
		joints.Waist.Transform = CFrame.Angles(back, 0, 0) * joints.Waist.Transform
		-- The head stays facing exactly where the pose has it with a gun. The pose tips the head up to make up
		-- for the torso's lean, so standing the torso up alone left it looking at the sky (River).
		if joints.Neck then
			joints.Neck.Transform = CFrame.Angles(-back, 0, 0) * joints.Neck.Transform
		end
		torso = through(through(body.root.CFrame, joints.Root), joints.Waist)
		lean = (facing:Inverse() * torso.Rotation):ToEulerAnglesYXZ()
	end
	local view = CFrame.new(torso * CARD_NECK) * facing * CFrame.Angles(lean * CARD_LEAN + body.look * CARD_LOOK, 0, 0) * CARD_OUT
	for _, side in { "Right", "Left" } do
		local shoulder, elbow, wrist = joints[side .. "Shoulder"], joints[side .. "Elbow"], joints[side .. "Wrist"]
		local arm = body.arms[side]
		if not arm then
			arm = ArmReach.measure(shoulder, elbow, wrist)
			body.arms[side] = arm
		end
		local palm = if side == "Right" then shown.pose.right else shown.pose.left
		local goal = view * palm * BodyHands.handOnPalm(side)
		local turns = { ArmReach.solve(arm, torso * shoulder.C0, goal, torso:VectorToWorldSpace(ELBOW_WAYS[side])) }
		for index, joint in { shoulder, elbow, wrist } do
			joint.Transform = joint.Transform:Lerp(turns[index], blend)
		end
	end
	shown.view = torso:ToObjectSpace(view)
end


-- A coded reload: turns the gun, moves its magazine and bolt, and puts the hands where the reload has them, on
-- top of everything else. Works out where the pose has the torso, the hands and the gun from the joints as they
-- now stand, then bends both arms to reach.
local function applyReload(body: Body, dt: number)
	body.moves = nil
	local at = body.codedAt
	if not at then
		body.eased = nil
	end
	local coded = body.gunName and CODED_RELOADS[body.gunName]
	local middle, ratio = HeldGuns.fit(body.character)
	local joints = body.joints
	if not at or not coded or not middle or not ratio or not body.pose or not body.pose.gun then
		return
	end
	for _, name in { "Root", "Waist", "RightShoulder", "RightElbow", "RightWrist", "LeftShoulder", "LeftElbow", "LeftWrist" } do
		if not joints[name] or not joints[name]:IsA("Motor6D") then
			return
		end
	end
	local reload = coded.reload
	local per = if coded.perMetre then coded.perMetre * ratio else 1
	local origin = if coded.origin then middle + coded.origin * per else Vector3.zero
	-- A frame in the reload's metres, as a place on the gun; and a move in them, as a move of something on it.
	local function placed(frame: CFrame): CFrame
		return CFrame.new(origin + frame.Position * per) * frame.Rotation
	end
	local function moved(frame: CFrame): CFrame
		return placed(frame) * CFrame.new(-origin)
	end

	local pose = reload.at(at, { middle = middle, ratio = ratio })
	-- The arms pass to the reload over its first moments and back over its last, so the elbows don't jump.
	local blend = math.clamp(math.min(at - (reload.lead or 0), reload.LENGTH - at) / RELOAD_BLEND, 0, 1)
	-- How much of the reload still shows: all of it until the outro, then easing to none by the end.
	local left = math.clamp((reload.LENGTH - at) / coded.outro, 0, 1)
	local fade = left * left * (3 - 2 * left)
	local carry = blend * fade -- for the body's lean

	-- The body goes with it, before the hands are found, so they and the gun are carried along.
	-- A natural reload's gun stays where it is in the air while the torso leans and turns under it: the torso's
	-- move is there to reach the other hand to the gun, not to carry the gun about. So where the pose has the
	-- gun and the hands on it is found now, before the lean.
	local before = nil
	if reload.natural then
		local torsoBefore = through(through(body.root.CFrame, joints.Root), joints.Waist)
		local rightBefore = through(through(through(torsoBefore, joints.RightShoulder), joints.RightElbow), joints.RightWrist)
		local leftBefore = through(through(through(torsoBefore, joints.LeftShoulder), joints.LeftElbow), joints.LeftWrist)
		local holdBefore = rightBefore * HeldGuns.frame(body.pose.gun)
		before = { hold = holdBefore, Right = holdBefore:ToObjectSpace(rightBefore), Left = holdBefore:ToObjectSpace(leftBefore) }
	end

	-- The torso's lean back, turn to its left and tip to its left: what the reload says, or a share of the gun's
	-- own turn. The hips turn a little the same way and shift against the tip.
	local leanBack, leanTurn, leanTip, hipsTurn, hipsShift
	if pose.body then
		leanBack, leanTurn, leanTip = pose.body.pitch * carry, pose.body.yaw * carry, pose.body.roll * carry
		hipsTurn, hipsShift = leanTurn * RELOAD_BODY_HIPS_YAW, -leanTip * RELOAD_BODY_HIPS_SHIFT
	else
		local pitch, yaw, roll = pose.gun:ToEulerAnglesXYZ()
		pitch, yaw, roll = pitch * carry, yaw * carry, roll * carry
		leanBack, leanTurn, leanTip = pitch * RELOAD_TORSO.pitch, yaw * RELOAD_TORSO.yaw, roll * RELOAD_TORSO.roll
		hipsTurn, hipsShift = yaw * RELOAD_HIPS_YAW, -roll * RELOAD_HIPS_SHIFT
	end
	joints.Waist.Transform = CFrame.Angles(leanBack, leanTurn, leanTip) * joints.Waist.Transform
	joints.Root.Transform = CFrame.new(hipsShift, 0, 0) * CFrame.Angles(0, hipsTurn, 0) * joints.Root.Transform
	if joints.Neck then
		joints.Neck.Transform = CFrame.Angles(
			-leanBack * RELOAD_HEAD_LEVEL - pose.weight * RELOAD_HEAD_DOWN * carry,
			-leanTurn * RELOAD_HEAD_LEVEL,
			-leanTip * RELOAD_HEAD_LEVEL
		) * joints.Neck.Transform
	end

	local torso = through(through(body.root.CFrame, joints.Root), joints.Waist)
	local hands = {}
	for _, side in { "Right", "Left" } do
		hands[side] = through(through(through(torso, joints[side .. "Shoulder"]), joints[side .. "Elbow"]), joints[side .. "Wrist"])
	end
	local hold = hands.Right * HeldGuns.frame(body.pose.gun) -- the gun before the reload turns it
	-- Where each hand is on the gun as the pose has them.
	local onGun = { Right = hold:ToObjectSpace(hands.Right), Left = hold:ToObjectSpace(hands.Left) }
	if before then
		hold, onGun = before.hold, { Right = before.Right, Left = before.Left }
	end
	-- A pull draws the whole gun in toward the body; the hands and the places the reload gives them go with it.
	if pose.pull then
		hold += body.root.CFrame:VectorToWorldSpace(pose.pull)
	end
	local turned = hold * moved(pose.gun)
	-- A spin is a turn of the gun the hands don't go round with: the Longscope flipping over about the trigger.
	local handle = if pose.spin then turned * moved(pose.spin) else turned

	-- Each hand goes round with the gun, and leaves it for the magazine, the slide or the charging knob.
	local goals = {
		Right = turned * onGun.Right,
		-- A left hand that isn't on the gun (the pistol's hangs at the side) stays where its pose has it.
		Left = if pose.freeLeft then hands.Left else turned * onGun.Left,
	}
	if pose.palm and pose.weight > 0 then
		goals.Left = goals.Left:Lerp(hold * placed(pose.palm) * BodyHands.handOnPalm("Left"), pose.weight)
	end
	if pose.leftShift then
		goals.Left += hold.Rotation * (pose.leftShift * per)
	end
	if pose.rightShift then
		goals.Right += turned.Rotation * (pose.rightShift * per)
	end
	if pose.right and pose.rightWeight > 0 then
		local away = hold * placed(pose.right) * BodyHands.handOnPalm("Right")
		goals.Right = goals.Right:Lerp(away, pose.rightWeight) + hold.Rotation * (pose.rightSwing * per)
	end

	-- A natural reload's gun and hands are eased toward where the reload has them, from the torso, so a move the
	-- reload makes in one frame is spread over a few.
	local natural = reload.natural == true
	if natural then
		local now = { handle = torso:ToObjectSpace(handle), Right = torso:ToObjectSpace(goals.Right), Left = torso:ToObjectSpace(goals.Left) }
		local eased = body.eased
		if eased then
			local share = 1 - math.exp(-dt * RELOAD_EASE)
			for key, frame in now do
				now[key] = eased[key]:Lerp(frame, share)
			end
		end
		body.eased = now
		handle, goals.Right, goals.Left = torso * now.handle, torso * now.Right, torso * now.Left
	end

	-- The outro: the gun and both hands ease from where the reload has them to where the pose does.
	if fade < 1 then
		handle = (hands.Right * HeldGuns.frame(body.pose.gun)):Lerp(handle, fade)
		goals.Right = hands.Right:Lerp(goals.Right, fade)
		goals.Left = hands.Left:Lerp(goals.Left, fade)
	end

	for _, side in { "Right", "Left" } do
		local shoulder, elbow, wrist = joints[side .. "Shoulder"], joints[side .. "Elbow"], joints[side .. "Wrist"]
		local arm = body.arms[side]
		if not arm then
			arm = ArmReach.measure(shoulder, elbow, wrist)
			body.arms[side] = arm
		end
		local base = torso * shoulder.C0
		local way = torso:VectorToWorldSpace(ELBOW_WAYS[side])
		if natural then
			-- The elbow stays on the side the pose has it. Pointing it somewhere fixed swung the pistol arm's
			-- elbow round under it and left the wrist twisted 80 degrees to make up (measured in Play).
			local poseElbow = (base * shoulder.Transform * shoulder.C1:Inverse() * elbow.C0).Position
			if (poseElbow - base.Position).Magnitude > 0.1 then
				way = poseElbow - base.Position
			end
		end
		local turns = { ArmReach.solve(arm, base, goals[side], way) }
		if natural and side == "Left" then
			-- A wrist isn't bent past what a wrist does to match the palm exactly: the hand stays where it is
			-- and turns as far as it can.
			local axis, angle = turns[3]:ToAxisAngle()
			if angle > RELOAD_WRIST_MOST then
				turns[3] = CFrame.fromAxisAngle(axis, RELOAD_WRIST_MOST)
			end
		end
		for index, joint in { shoulder, elbow, wrist } do
			joint.Transform = joint.Transform:Lerp(turns[index], blend)
		end
	end

	-- The old magazine is the gun's until it is let go; from then the one shown is the new one, in the hand and
	-- then in the gun. (First person shows both for a moment; this body's gun has the one.)
	body.moves = {
		handle = torso:ToObjectSpace(handle),
		mag = CFrame.identity:Lerp(moved(pose.spare or pose.mag), fade),
		action = CFrame.new(0, 0, pose.bolt * per * fade),
	}
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
			applyAir(body, dt, now)
			applySlide(body, now)
			applyWallKick(body, now)
			if body.cardPose then
				body.moves = nil
				applyCards(body)
			else
				applyReload(body, dt)
			end
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
			-- A coded reload's gun is placed from the torso, since neither hand need be holding it.
			local moves = nil
			local torso = character:FindFirstChild("UpperTorso")
			if body.moves and torso and torso:IsA("BasePart") then
				moves = { handle = torso.CFrame * body.moves.handle, mag = body.moves.mag, action = body.moves.action }
			end
			-- With a card out the gun is put away and the deck is in the hands, their fingers shaped to it.
			local cards = body.cardPose
			local deckView = if cards and cards.view and torso and torso:IsA("BasePart") then torso.CFrame * cards.view else nil
			HeldGuns.show(character, body.gunName, body.poses, body.pose, visible and not cards, moves)
			BodyHands.show(character, visible, if cards then cards.pose.fingers else nil)
			if visible and body.slideHand then
				local velocity = body.root.AssemblyLinearVelocity
				local flat = Vector3.new(velocity.X, 0, velocity.Z)
				SlideSparks.show(character, body.slideHand, if flat.Magnitude > 0.1 then flat.Unit else body.root.CFrame.LookVector, flat.Magnitude)
			else
				SlideSparks.hide(character)
			end
			if visible and cards and deckView then
				BodyCards.show(character, deckView, cards.pose.cards, cards.faceUp, cards.gone)
			else
				BodyCards.hide(character)
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
