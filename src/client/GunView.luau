-- The gun held in view, with the arms holding it. Uses the model in ReplicatedStorage.GunModels named after the gun,
local Palette = require(game:GetService("ReplicatedStorage"):WaitForChild("Guns"):WaitForChild("Palette"))
-- or a grey block if that model hasn't been imported.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmClip = require(ReplicatedStorage.Guns.ArmClip)
local ArmClips = require(ReplicatedStorage.Guns.ArmClips)
local CardClip = require(ReplicatedStorage.Guns.ArmClips.Card)
local GunConfig = require(ReplicatedStorage.Guns.GunConfig)
local CardView = require(script.Parent.CardView)
local ViewArms = require(script.Parent.ViewArms)

local PRIMARY_LENGTH = 2.4
local SIDEARM_LENGTH = 1
local MODEL_SCALE = 0.031
-- Guns that looked too small in the soldier's hands are drawn bigger. The grips move with them.
local VIEW_SCALES: { [string]: number } = { Longscope = 1.35 }
-- Where the left hand holds a gun, as a share of its length from the middle, where the usual spot is out of reach.
-- Too far forward and the arm locks straight with the shoulder sliding into view.
local LEFT_GRIPS: { [string]: number } = { Longscope = 0 }
local leftGrip = LEFT_GRIP_Z
-- Shoulders moved for a gun, in camera space. The Longscope's left arm comes up from below instead of
-- reaching across the screen.
local SHOULDERS: { [string]: { [string]: Vector3 } } = { Longscope = { Left = Vector3.new(-0.55, -1.8, 0.2) } }
-- How far a thumb curls around the gun, in radians at the tip.
local THUMB_WRAPS: { [string]: { [string]: number } } = { Longscope = { Left = math.rad(70) } }
local BLOCK_SECTION = Vector2.new(0.3, 0.4)
local BARREL_RISE = 0.26 -- how far above the model's middle the barrel sits, as a share of its height
local HIP = CFrame.new(0.9, -0.8, -2)
local AIMED = CFrame.new(0, -0.55, -2)
local RELOAD_DIP = CFrame.new(0, -0.7, 0) * CFrame.Angles(math.rad(-25), 0, 0)
-- Sway: the gun and arms lag behind the mouse, then swing back on a spring.
local SWAY_TURN = 0.03 -- how far they turn per radian per second the camera turns
local SWAY_MOVE = 0.3 -- and how far they slide, in studs per radian they turn
local SWAY_MAX = math.rad(6)
local SWAY_STIFF = 120 -- spring strength
local SWAY_DAMP = 17 -- spring damping, a little under critical, so it swings past once
local SWAY_AIMED = 0.25 -- the share of sway left while scoped
-- Bob: the gun rides the steps, dipping and nodding on each footfall and swinging side to side
-- every two steps. Studs and degrees at walking speed.
local BOB_HEIGHT = 0.03
local BOB_SIDE = 0.035
local BOB_NOD = 1.2
local BOB_ROLL = 1.5
local STEP_STUDS = 9 -- the footstep sounds play this far apart, so the dips land with them
local BOB_SPRINT = 1.9 -- how much bigger the bob is while sprinting
local WALK_SPEED = 16
-- Sprinting: the gun settles a little lower and closer, tipped down. Small on purpose.
local SPRINT_HOLD = CFrame.new(0.03, -0.08, 0.06) * CFrame.Angles(math.rad(-6), math.rad(4), math.rad(3))
local EASE = 11
-- A new clip fades in from the last pose over this long, so the end of a reload doesn't cut to idle.
-- A shot and a swap start at once, so they keep their snap.
local CLIP_BLEND = 0.25
-- Motion blur: Roblox can't blur one object, so faded copies of the gun and arms trail behind them,
-- spread between where they were SMEAR_TIME ago and where they are now. Only while the gun moves fast enough.
local SMEAR_COPIES = 4
local SMEAR_TIME = 0.06
local SMEAR_OPACITY = 0.5
local SMEAR_MIN_MOVE = 0.04 -- studs the gun must travel in SMEAR_TIME to blur
local SMEAR_MIN_TURN = math.rad(4)
local SNAPPY = { fire = true, holster = true }
-- How each gun moves when it fires: pushed back and dropped (studs), barrel up and rolled (degrees).
-- A single shot pushes out over rise seconds, fast then easing into the peak. An automatic gets a shove each
-- shot that stacks a little while spraying. Either way the gun comes home on a spring (stiff, damp) that swings
-- a little past. Guns with clips (M57, Energy Pistol) move the whole view, arms and all, on top of the clip.
local VIEW_KICKS: { [string]: any } = {
	M57 = { back = 0.066, drop = 0.011, up = 1.5, roll = 0.9, stiff = 315, damp = 27.8, auto = true },
	B33 = { back = 0.154, drop = 0.022, up = 3.3, roll = 1.5, stiff = 270, damp = 24.4, auto = true },
	SMG = { back = 0.099, drop = 0.011, up = 2.2, roll = 1.3, stiff = 360, damp = 29.6, auto = true },
	["Energy Pistol"] = { back = 0.132, drop = 0.033, up = 7.7, roll = 2.2, rise = 0.04, stiff = 165, damp = 19.1 },
	Shotgun = { back = 0.605, drop = 0.132, up = 14.3, roll = -6.6, rise = 0.081, stiff = 52.5, damp = 10.4 },
	Longscope = { back = 0.935, drop = 0.242, up = 20.9, roll = -12.1, rise = 0.103, stiff = 41.2, damp = 8.7 },
}
local DEFAULT_KICK = { back = 0.165, drop = 0.022, up = 4.4, roll = 1.7, rise = 0.034, stiff = 187.5, damp = 20.9 }
-- An automatic's shove, as a multiple of its spring's speed, so one shot alone peaks at about the full kick.
local AUTO_SHOVE = 2.3
-- Reloads for guns posed in code, as keys: seconds into the reload, the gun's turn and shift from its hold, where
-- the left hand is from its grip (in the space of the gun before any spin, so it can let go and catch), and how the move into that key eases. A reload with
-- a spin turns the gun once backwards round the trigger between those times. Timed to the sound, and stretched if the gun's reload time differs
-- from length.
local function key(at: number, gun: CFrame, hand: Vector3, ease: string?): any
	return { at = at, gun = gun, hand = hand, ease = ease or "inOut" }
end
local function tilt(roll: number, yaw: number, pitch: number, x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(math.rad(pitch), math.rad(yaw), math.rad(roll))
end
local RELOADS: { [string]: any } = {
	-- reload-sniper.wav: a rising whine to 0.95s, a click at 0.94s and a clunk at 1.06s. The gun spins once
	-- backwards round the trigger finger during the whine, then the left hand clicks the cell home and locks it.
	Longscope = {
		length = 1.714,
		-- One smooth spin from the shove to the catch, so it never slows between keys.
		spin = { from = 0.13, to = 0.76 },
		keys = {
			key(0, CFrame.identity, Vector3.zero),
			key(0.12, tilt(0, 0, -10, 0, -0.05, 0.03), Vector3.zero), -- dips to wind up
			key(0.2, tilt(0, 0, -4, 0, -0.02, 0.03), Vector3.new(0, 0.22, -0.12), "in"), -- the left hand shoves it up
			key(0.27, tilt(0, 0, 0, 0, 0.04, 0.02), Vector3.new(-0.05, 0.38, -0.05), "out"), -- and follows through
			key(0.45, tilt(0, 0, 0, 0, 0.1, 0), Vector3.new(-0.3, -0.7, 0.3)), -- drops away while it whips round
			key(0.68, tilt(0, 0, 0, 0, 0.06, 0), Vector3.new(-0.05, -0.3, 0.08)), -- comes up under it
			key(0.76, tilt(4, -2, 2, -0.02, 0.03, 0.01), Vector3.zero, "out"), -- catches it
			key(0.81, tilt(8, -3, -3, -0.04, -0.04, 0.02), Vector3.new(0, -0.04, 0), "out"), -- and gives with the weight
			-- CLICK: the gun tips to show the cell slot, the hand pulls back to load up, then drives the cell in on
			-- the sound and the gun bumps up off the hit and settles.
			key(0.85, tilt(18, -6, 2, -0.06, 0, 0.03), Vector3.new(0, -0.38, 0.26)),
			key(0.97, tilt(19, -6, 1, -0.06, -0.01, 0.03), Vector3.new(0, -0.4, 0.26)), -- holds there, loaded
			key(1.03, tilt(18, -6, 2, -0.06, 0, 0.03), Vector3.new(0.02, -0.02, 0.24), "in"),
			key(1.07, tilt(16, -6, 9, -0.06, 0.09, 0.03), Vector3.new(0.02, 0.05, 0.24), "out"),
			key(1.11, tilt(20, -7, 1, -0.07, -0.01, 0.03), Vector3.new(0.02, -0.01, 0.24)),
			-- CLICK release: a small wind-up further into the tilt, then a beat after the clunk the gun eases back to
			-- ready, rolls just past and settles, the hand riding back onto its grip.
			key(1.24, tilt(23, -8, 0, -0.08, -0.02, 0.03), Vector3.new(0.02, -0.02, 0.22), "in"),
			key(1.4, tilt(-3, 1, 1.5, 0.005, 0.015, 0), Vector3.zero), -- eases back round, just past
			key(1.58, tilt(0.8, -0.3, -0.4, 0, -0.004, 0), Vector3.zero),
			key(1.714, CFrame.identity, Vector3.zero),
		},
	},
}

local function eased(ease: string, u: number): number
	if ease == "in" then
		return u * u * u
	elseif ease == "out" then
		return 1 - (1 - u) ^ 3
	end
	return u * u * (3 - 2 * u)
end

-- How far a reload's spin has turned, in radians, on one smooth curve from the shove to the catch.
local function spinAt(reload: any, at: number): number
	local spin = reload.spin
	if not spin or at <= spin.from then
		return 0
	elseif at >= spin.to then
		return 0 -- a full turn is back where it started
	end
	local u = (at - spin.from) / (spin.to - spin.from)
	-- Leaves the shove already moving, peaks a quarter of the way round, and slows to a stop in the hand.
	local eased = 1.2 * u + 0.6 * u * u - 0.8 * u * u * u
	return eased * 2 * math.pi
end

-- The gun's offset, the left hand's, and the gun's backward spin in radians, elapsed seconds into a keyed reload.
local function reloadPose(reload: any, elapsed: number, reloadTime: number): (CFrame, Vector3, number)
	local at = elapsed * reload.length / reloadTime
	local keys = reload.keys
	for index = 2, #keys do
		local to = keys[index]
		if at < to.at then
			local from = keys[index - 1]
			local u = eased(to.ease, (at - from.at) / (to.at - from.at))
			return from.gun:Lerp(to.gun, u), from.hand:Lerp(to.hand, u), spinAt(reload, at)
		end
	end
	return CFrame.identity, Vector3.zero, 0
end

-- Equipping a gun posed in code: it swings in from below and to the right.
local EQUIP_TIME = 0.45
local EQUIP_FROM = CFrame.new(0.6, -1.2, 0.3) * CFrame.Angles(math.rad(-40), math.rad(25), math.rad(-30))
-- Scoping in and out is quick on a gun that can scope.
local AIM_EASE = 24
local HOLSTER_WAIT = 0.3 -- how long the gun stays down waiting for the server to swap it

-- Where the hands sit. Primary wrists sit along the gun as a share of its length.
local RIGHT_GRIP_Z = 0.2
local LEFT_GRIP_Z = -0.12
local PRIMARY_RIGHT = { x = 0.16, y = -0.2, along = Vector3.new(-0.2, -0.25, -0.95), thumb = Vector3.new(0, 1, 0) }
local PRIMARY_LEFT = { x = 0.01, y = -0.3, along = Vector3.new(0.2, 0, -1), thumb = Vector3.new(-0.7, 0.7, -0.2) }
local SIDEARM_RIGHT = {
	wrist = Vector3.new(0.11, -0.2, 0.4),
	along = Vector3.new(-0.2, -0.25, -0.95),
	thumb = Vector3.new(0, 1, 0),
}
local SIDEARM_LEFT = {
	wrist = Vector3.new(-0.09, -0.3, 0.35),
	along = Vector3.new(0.5, 0.3, -0.8),
	thumb = Vector3.new(-0.6, 0.6, -0.4),
}

-- Turns a model so its barrel points forward, for models exported facing another way.
local TURNS: { [string]: CFrame } = {}

local view: PVInstance? = nil
local shownGun: string? = nil
local length = PRIMARY_LENGTH
local barrelRise = 0
local isSidearm = false
local viewScale = 1
local held = HIP
local kick = 0
local kickSpeed = 0
local kickRoll = 1 -- which way this shot rolls
local shown = HIP
local clips: any = nil
local firedAt: number? = nil
local reloadAt: number? = nil
local reloadClip: any = nil
local equipAt: number? = nil
local keyedReloadAt: number? = nil -- when a keyed reload started
local holsterAt: number? = nil
local snapAt: number? = nil
local cardAt: number? = nil
local shownCard: any = nil
local shownFrame: any = nil -- what's on screen, with any snap laid over it
local shownBase: any = nil
local shownSnap: any = nil
local smears: { any } = {}
local smearShown = false
local history: { { at: number, frame: any } } = {} -- recent poses, oldest first
local shownKind: string? = nil -- which clip is playing
local blendFrom: any = nil -- the pose a clip change fades out of
local blendAt = 0

local function makeBlock(): Part
	local part = Instance.new("Part")
	part.Name = "GunView"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Color = Palette.DeepNavy
	part.Size = Vector3.new(BLOCK_SECTION.X, BLOCK_SECTION.Y, length)
	return part
end

-- Clones the gun's model. One scale for all of them keeps the guns' sizes relative to each other.
local function makeModel(name: string): Model?
	local folder = ReplicatedStorage:FindFirstChild("GunModels")
	local source = folder and folder:FindFirstChild(name)
	if not source then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "GunView"
	source:Clone().Parent = model
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
		end
	end
	model:ScaleTo(MODEL_SCALE * viewScale)
	model.WorldPivot = model:GetBoundingBox()
	local size = model:GetExtentsSize()
	length = size.Z
	barrelRise = size.Y * BARREL_RISE
	return model
end

local function hideSmears()
	smearShown = false
	for _, smear in smears do
		smear.gun.Parent = nil
		if smear.arms then
			ViewArms.hideGhost(smear.arms)
		end
	end
end

local function removeSmears()
	for _, smear in smears do
		smear.gun:Destroy()
		if smear.arms then
			ViewArms.removeGhost(smear.arms)
		end
	end
	table.clear(smears)
	table.clear(history)
	smearShown = false
end

local function makeSmears()
	for i = 1, SMEAR_COPIES do
		local gun = (view :: any):Clone()
		local parts = {}
		for _, part in gun:GetDescendants() do
			if part:IsA("BasePart") then
				table.insert(parts, part)
			end
		end
		if gun:IsA("BasePart") then
			table.insert(parts, gun)
		end
		smears[i] = { gun = gun, parts = parts, arms = ViewArms.makeGhost(), share = i / (SMEAR_COPIES + 1) }
	end
end

-- Remembers this frame's pose and trails the copies from the oldest remembered one up to it,
-- the copies nearest the gun the strongest.
-- whole is this frame's pose: gun, plus bones on a gun with clips. hold is what the pose's gun is relative to.
-- A gun posed in code has no bones, so only the gun trails.
local function drawSmear(camera: Camera, whole: any, base: CFrame, hold: CFrame)
	local now = os.clock()
	table.insert(history, { at = now, frame = whole })
	while #history > 1 and history[2].at <= now - SMEAR_TIME do
		table.remove(history, 1)
	end
	local from = history[1].frame
	local moved = (from.gun.Position - whole.gun.Position).Magnitude
	local _, turned = from.gun:ToObjectSpace(whole.gun):ToAxisAngle()
	if moved < SMEAR_MIN_MOVE and math.abs(turned) < SMEAR_MIN_TURN then
		if smearShown then
			hideSmears()
		end
		return
	end
	if #smears == 0 then
		makeSmears()
	end
	smearShown = true
	for _, smear in smears do
		local transparency = 1 - SMEAR_OPACITY * smear.share
		for _, part in smear.parts do
			part.Transparency = transparency
		end
		smear.gun:PivotTo(hold * from.gun:Lerp(whole.gun, smear.share))
		smear.gun.Parent = camera
		if smear.arms and whole.bones and from.bones and clips then
			ViewArms.poseGhost(smear.arms, clips.meshOffset, ArmClip.blendBones(from.bones, whole.bones, smear.share))
			ViewArms.placeGhost(smear.arms, camera, transparency, base)
		elseif smear.arms then
			ViewArms.hideGhost(smear.arms)
		end
	end
end

local swayAngles = Vector2.zero -- pitch, yaw, in radians
local swaySpeed = Vector2.zero
local lastLook: CFrame? = nil
local bobPhase = 0
local bobWeight = 0
local sprintWeight = 0

-- Lags the gun behind the camera's turning, and bobs it with the player's steps.
local function swayAndBob(dt: number, camera: Camera, aiming: boolean, sprinting: boolean): CFrame
	local look = camera.CFrame.Rotation
	local turn = Vector2.zero
	if lastLook and dt > 0 then
		local pitch, yaw = lastLook:ToObjectSpace(look):ToEulerAnglesYXZ()
		turn = Vector2.new(pitch, yaw) / dt
	end
	lastLook = look
	local share = if aiming then SWAY_AIMED else 1
	local goal = -turn * SWAY_TURN * share
	goal = Vector2.new(math.clamp(goal.X, -SWAY_MAX, SWAY_MAX), math.clamp(goal.Y, -SWAY_MAX, SWAY_MAX))
	local step = math.min(dt, 1 / 30)
	swaySpeed += ((goal - swayAngles) * SWAY_STIFF - swaySpeed * SWAY_DAMP) * step
	swayAngles += swaySpeed * step

	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local speed = 0
	if root and humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
		local velocity = root.AssemblyLinearVelocity
		speed = Vector2.new(velocity.X, velocity.Z).Magnitude
	end
	bobPhase += speed * dt * math.pi / STEP_STUDS
	local running = sprinting and speed > 1
	local bobGoal = math.min(speed / WALK_SPEED, 1) * (if running then BOB_SPRINT else 1) * share
	bobWeight += (bobGoal - bobWeight) * (1 - math.exp(-dt * 6))
	sprintWeight += ((if running and not aiming then 1 else 0) - sprintWeight) * (1 - math.exp(-dt * 5))
	local side = math.sin(bobPhase)
	local dip = math.abs(math.cos(bobPhase)) -- 1 on each footfall
	local bob = CFrame.new(side * BOB_SIDE * bobWeight, -dip * BOB_HEIGHT * bobWeight, 0)
		* CFrame.Angles(
			math.rad(-dip * BOB_NOD * bobWeight),
			math.rad(side * BOB_ROLL * 0.6 * bobWeight),
			math.rad(side * BOB_ROLL * bobWeight)
		)
	bob = CFrame.identity:Lerp(SPRINT_HOLD, sprintWeight) * bob

	return CFrame.new(swayAngles.Y * SWAY_MOVE, swayAngles.X * SWAY_MOVE, 0)
		* CFrame.Angles(swayAngles.X, swayAngles.Y, swayAngles.Y * 0.6)
		* bob
end

local GunView = {}

local function grips(): (any, any)
	if isSidearm then
		return SIDEARM_RIGHT, SIDEARM_LEFT
	end
	local right = { wrist = Vector3.new(PRIMARY_RIGHT.x * viewScale, PRIMARY_RIGHT.y * viewScale, length * RIGHT_GRIP_Z) }
	right.along, right.thumb = PRIMARY_RIGHT.along, PRIMARY_RIGHT.thumb
	local left = { wrist = Vector3.new(PRIMARY_LEFT.x * viewScale, PRIMARY_LEFT.y * viewScale, length * leftGrip) }
	left.along, left.thumb = PRIMARY_LEFT.along, PRIMARY_LEFT.thumb
	return right, left
end

function GunView.setGun(gunId: string, slot: string)
	if gunId == shownGun then
		return
	end
	shownGun = gunId
	removeSmears()
	if view then
		view:Destroy()
	end
	isSidearm = slot == "sidearm"
	viewScale = VIEW_SCALES[GunConfig.guns[gunId].name] or 1
	leftGrip = LEFT_GRIPS[GunConfig.guns[gunId].name] or LEFT_GRIP_Z
	length = if isSidearm then SIDEARM_LENGTH else PRIMARY_LENGTH
	barrelRise = 0
	view = makeModel(GunConfig.guns[gunId].name) or makeBlock()
	clips = ArmClips[GunConfig.guns[gunId].name]
	firedAt = nil
	reloadAt = nil
	holsterAt = nil
	equipAt = os.clock()
	snapAt = nil
	shownFrame = nil
	shownBase = nil
	shownSnap = nil
end

-- Lowers the gun as soon as the swap key goes down, before the server has answered.
function GunView.holster()
	holsterAt = os.clock()
end

-- Snaps the fingers of the free hand, on guns that leave one free.
function GunView.snap()
	if clips and clips.snap then
		snapAt = os.clock()
	end
end

-- Where bullets leave the gun on screen, or nil while it's hidden.
function GunView.muzzle(): Vector3?
	if not view or not view.Parent then
		return nil
	end
	return view:GetPivot() * Vector3.new(0, barrelRise, -length / 2)
end

function GunView.kick()
	local config = if shownGun then GunConfig.guns[shownGun] else nil
	local viewKick = (config and VIEW_KICKS[config.name]) or DEFAULT_KICK
	if viewKick.auto then
		kickSpeed += AUTO_SHOVE * math.sqrt(viewKick.stiff)
		kickRoll = if math.random() < 0.5 then -1 else 1
	else
		kick = 0
		kickSpeed = 0
		kickRoll = 1
	end
	firedAt = os.clock()
end

-- The frame to show. Swapping guns beats everything, then reloading, then a shot, then running, then idle.
local function clipFrame(reloading: boolean, sprinting: boolean): (any, string)
	if holsterAt then
		local elapsed = os.clock() - holsterAt
		local frames = clips.holster.frames
		local frame = ArmClip.sampleAt(clips.holster, elapsed)
		if frame or elapsed < HOLSTER_WAIT then
			return frame or frames[#frames], "holster"
		end
		holsterAt = nil
	end
	if equipAt then
		local frame = ArmClip.sampleAt(clips.equip, os.clock() - equipAt)
		if frame then
			return frame, "equip"
		end
		equipAt = nil
	end
	if reloading and not reloadAt then
		reloadClip = ArmClip.pickReload(clips, math.random())
	end
	reloadAt = if reloading then reloadAt or os.clock() else nil
	if reloadAt then
		local frame = ArmClip.sampleAt(reloadClip, os.clock() - reloadAt)
		if frame then
			return frame, "reload"
		end
	end
	if firedAt then
		local frame = ArmClip.sampleAt(clips.fire, os.clock() - firedAt)
		if frame then
			return frame, "fire"
		end
		firedAt = nil
	end
	return ArmClip.sampleAt(if sprinting then clips.run else clips.idle, os.clock()), if sprinting then "run" else "idle"
end

-- The snap frame to lay over the clip, if one is playing.
local function snapFrame(): any
	local frame = if snapAt then ArmClip.sampleAt(clips.snap, os.clock() - snapAt) else nil
	if not frame then
		snapAt = nil
	end
	return frame
end

-- With a card out, the gun drops, then the arms play the card flying across and holding it.
-- Returns true while the card has the screen.
local function showCard(camera: Camera, cardOut: boolean, cardSway: CFrame): boolean
	if not cardOut then
		if cardAt then
			cardAt, shownCard, holsterAt = nil, nil, nil
			equipAt = os.clock()
			shownFrame, shownBase, shownSnap = nil, nil, nil
			CardView.hide()
		end
		return false
	end
	if not cardAt then
		cardAt = os.clock()
		holsterAt = cardAt
	end
	local drop = if clips then #clips.holster.frames / clips.holster.fps else 0
	local elapsed = os.clock() - (cardAt :: number) - drop
	if elapsed < 0 then
		return false
	end
	if view and view.Parent then
		view.Parent = nil
		hideSmears()
		table.clear(history)
	end
	local frame = ArmClip.sampleAt(CardClip.draw, elapsed) or ArmClip.sampleAt(CardClip.hold, os.clock())
	shownCard = frame
	ViewArms.showFrame(CardClip.meshOffset, frame.bones)
	CardView.show(camera, frame, cardSway)
	ViewArms.place(camera, camera.CFrame * cardSway)
	return true
end

function GunView.update(
	dt: number,
	camera: Camera,
	aiming: boolean,
	reloading: boolean,
	sprinting: boolean,
	cardOut: boolean
)
	view = view or makeBlock()
	local goal = if aiming then AIMED else HIP
	local keyedReload = if shownGun then RELOADS[GunConfig.guns[shownGun].name] else nil
	if reloading and not clips and not keyedReload then
		goal *= RELOAD_DIP
	end
	local config = if shownGun then GunConfig.guns[shownGun] else nil
	local viewKick = (config and VIEW_KICKS[config.name]) or DEFAULT_KICK
	local ease = 1 - math.exp(-dt * (if config and config.aimFov then AIM_EASE else EASE))
	held = held:Lerp(goal, ease)
	local rising = viewKick.rise and firedAt and os.clock() - firedAt < viewKick.rise
	if rising then
		local u = (os.clock() - (firedAt :: number)) / viewKick.rise
		kick = 1 - (1 - u) ^ 3
		kickSpeed = 0
	else
		local step = math.min(dt, 1 / 30)
		kickSpeed += (-kick * viewKick.stiff - kickSpeed * viewKick.damp) * step
		kick += kickSpeed * step
	end
	local recoil = CFrame.new(0, -viewKick.drop * kick, viewKick.back * kick)
		* CFrame.Angles(math.rad(viewKick.up * kick), 0, math.rad(viewKick.roll * kickRoll * kick))
	local sway = swayAndBob(dt, camera, aiming, sprinting)
	-- A gun with clips kicks the whole view, so the arms holding it go too.
	local base = camera.CFrame * sway * (if clips then recoil else CFrame.identity)
	if showCard(camera, cardOut, sway) then
		return
	end
	if clips then
		local frame, kind = clipFrame(reloading, sprinting)
		if kind ~= shownKind then
			blendFrom = if shownBase and not SNAPPY[kind] then shownBase else nil
			blendAt = os.clock()
			shownKind = kind
		end
		if blendFrom then
			local t = (os.clock() - blendAt) / CLIP_BLEND
			if t >= 1 then
				blendFrom = nil
			else
				frame = ArmClip.blendFrames(blendFrom, frame, t * t * (3 - 2 * t))
			end
		end
		local snap = snapFrame()
		local whole = if snap then ArmClip.overlay(frame, snap) else frame
		shownFrame, shownBase, shownSnap = whole, frame, snap
		ViewArms.showFrame(clips.meshOffset, whole.bones)
		-- Reloading and scoping still move the whole hold, on top of the clip.
		shown = held * HIP:Inverse() * frame.gun
	else
		local now = os.clock()
		local equip = CFrame.identity
		if equipAt then
			local t = (now - equipAt) / EQUIP_TIME
			if t < 1 then
				local share = 1 - (1 - t) ^ 3
				equip = EQUIP_FROM:Lerp(CFrame.identity, share)
			else
				equipAt = nil
			end
		end
		-- A gun drawn bigger moves forward by its extra length, so its stock stays clear of the camera.
		local forward = CFrame.new(0, 0, -length * (1 - 1 / viewScale) / 2)
		local reloadGun, reloadHand, spin = CFrame.identity, Vector3.zero, 0
		keyedReloadAt = if reloading and keyedReload then keyedReloadAt or now else nil
		if keyedReloadAt and config then
			reloadGun, reloadHand, spin = reloadPose(keyedReload, now - keyedReloadAt, config.reload)
		end
		local right, left = grips()
		-- The hands go by the gun before its spin: the right stays put with its finger in the trigger guard while the
		-- gun spins round it, and the left lets go and catches it.
		local hand = held * forward * equip * recoil * reloadGun * (turn or CFrame.identity)
		local pivot = right.wrist
		shown = held * forward * equip * recoil * reloadGun
			* CFrame.new(pivot) * CFrame.Angles(spin, 0, 0) * CFrame.new(-pivot)
			* (turn or CFrame.identity)
		if reloadHand ~= Vector3.zero then
			left = table.clone(left)
			left.wrist += reloadHand
		end
		ViewArms.pose(shown, right, left, config and SHOULDERS[config.name], config and THUMB_WRAPS[config.name], hand, hand)
	end
	view:PivotTo(base * shown)
	view.Parent = camera
	ViewArms.place(camera, base)
	if clips and shownFrame then
		drawSmear(camera, shownFrame, base, base * held * HIP:Inverse())
	elseif not clips then
		-- Guns posed in code trail too, so the Longscope's reload spin and kick blur.
		drawSmear(camera, { gun = shown }, base, base)
	elseif smearShown then
		hideSmears()
	end
end

function GunView.hide()
	hideSmears()
	table.clear(history)
	if view then
		view.Parent = nil
	end
	CardView.hide()
	ViewArms.hide()
end

return GunView
