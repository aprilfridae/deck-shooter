-- The gun held in view, with the arms holding it. Uses the model in ReplicatedStorage.GunModels named after the gun,
local Palette = require(game:GetService("ReplicatedStorage"):WaitForChild("Guns"):WaitForChild("Palette"))
-- or a grey block if that model hasn't been imported.
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
local BLOCK_SECTION = Vector2.new(0.3, 0.4)
local BARREL_RISE = 0.26 -- how far above the model's middle the barrel sits, as a share of its height
local HIP = CFrame.new(0.9, -0.8, -2)
local AIMED = CFrame.new(0, -0.55, -2)
local RELOAD_DIP = CFrame.new(0, -0.7, 0) * CFrame.Angles(math.rad(-25), 0, 0)
local EASE = 14
-- A new clip fades in from the last pose over this long, so the end of a reload doesn't cut to idle.
-- A shot and a swap start at once, so they keep their snap.
local CLIP_BLEND = 0.2
-- Motion blur: Roblox can't blur one object, so faded copies of the gun and arms trail behind them,
-- spread between where they were SMEAR_TIME ago and where they are now. Only while the gun moves fast enough.
local SMEAR_COPIES = 4
local SMEAR_TIME = 0.06
local SMEAR_OPACITY = 0.5
local SMEAR_MIN_MOVE = 0.04 -- studs the gun must travel in SMEAR_TIME to blur
local SMEAR_MIN_TURN = math.rad(4)
local SNAPPY = { fire = true, holster = true }
-- Guns posed in code move like this when they fire: pushed back (studs), dropped (studs), barrel up and
-- rolled (degrees), settling at ease per second. The Longscope slams back hard and is home in about 0.15s.
local VIEW_KICKS: { [string]: any } = {
	Longscope = { back = 0.6, drop = 0.15, up = 14, roll = -8, ease = 16, slap = true },
}
local DEFAULT_KICK = { back = 0.25, drop = 0, up = 0, roll = 0, ease = 14, slap = false }
-- Recharging an energy gun: after the kick, the left hand comes off, then slaps the side of the gun,
-- which jolts right and rolls. Seconds after the shot.
local SLAP_LEAVE = 0.18 -- the hand starts to pull away
local SLAP_HIT = 0.42 -- and lands back on the gun
local SLAP_HAND = Vector3.new(-0.4, -0.2, 0.15) -- how far the hand pulls away, in the gun's space
local SLAP_SHOVE = Vector3.new(0.07, 0.03, 0) -- the gun's jolt
local SLAP_ROLL = -12 -- degrees
local SLAP_SETTLE = 14 -- how fast the jolt dies away, per second
-- Equipping a gun posed in code: it swings in from below and to the right.
local EQUIP_TIME = 0.4
local EQUIP_FROM = CFrame.new(0.6, -1.2, 0.3) * CFrame.Angles(math.rad(-40), math.rad(25), math.rad(-30))
-- Scoping in and out is quick on a gun that can scope.
local AIM_EASE = 30
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
local shown = HIP
local clips: any = nil
local firedAt: number? = nil
local reloadAt: number? = nil
local reloadClip: any = nil
local equipAt: number? = nil
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
local function drawSmear(camera: Camera, whole: any)
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
	local hold = camera.CFrame * held * HIP:Inverse()
	for _, smear in smears do
		local transparency = 1 - SMEAR_OPACITY * smear.share
		for _, part in smear.parts do
			part.Transparency = transparency
		end
		smear.gun:PivotTo(hold * from.gun:Lerp(whole.gun, smear.share))
		smear.gun.Parent = camera
		if smear.arms then
			ViewArms.poseGhost(smear.arms, clips.meshOffset, ArmClip.blendBones(from.bones, whole.bones, smear.share))
			ViewArms.placeGhost(smear.arms, camera, transparency)
		end
	end
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
	kick = 1
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
local function showCard(camera: Camera, cardOut: boolean): boolean
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
	CardView.show(camera, frame, CFrame.identity)
	ViewArms.place(camera)
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
	if reloading and not clips then
		goal *= RELOAD_DIP
	end
	local config = if shownGun then GunConfig.guns[shownGun] else nil
	local viewKick = (config and VIEW_KICKS[config.name]) or DEFAULT_KICK
	local ease = 1 - math.exp(-dt * (if config and config.aimFov then AIM_EASE else EASE))
	held = held:Lerp(goal, ease)
	kick *= math.exp(-dt * viewKick.ease)
	local turn = if shownGun then TURNS[GunConfig.guns[shownGun].name] else nil
	if showCard(camera, cardOut) then
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
		local slap = CFrame.identity
		local handAway = 0
		if viewKick.slap and firedAt then
			local since = now - firedAt
			if since >= SLAP_LEAVE and since < SLAP_HIT then
				-- Eases out, then snaps back in for the hit.
				local t = (since - SLAP_LEAVE) / (SLAP_HIT - SLAP_LEAVE)
				handAway = if t < 0.7 then math.sin(t / 0.7 * math.pi / 2) else 1 - ((t - 0.7) / 0.3) ^ 2
			elseif since >= SLAP_HIT then
				local jolt = math.exp(-(since - SLAP_HIT) * SLAP_SETTLE)
				slap = CFrame.new(SLAP_SHOVE * jolt) * CFrame.Angles(0, 0, math.rad(SLAP_ROLL * jolt))
			end
		end
		local recoil = CFrame.new(0, -viewKick.drop * kick, viewKick.back * kick)
			* CFrame.Angles(math.rad(viewKick.up * kick), 0, math.rad(viewKick.roll * kick))
		-- A gun drawn bigger moves forward by its extra length, so its stock stays clear of the camera.
		local forward = CFrame.new(0, 0, -length * (1 - 1 / viewScale) / 2)
		shown = held * forward * equip * recoil * slap * (turn or CFrame.identity)
		local right, left = grips()
		if handAway > 0 then
			left = table.clone(left)
			left.wrist += SLAP_HAND * handAway
		end
		ViewArms.pose(shown, right, left, config and SHOULDERS[config.name])
	end
	view:PivotTo(camera.CFrame * shown)
	view.Parent = camera
	ViewArms.place(camera)
	if clips and shownFrame then
		drawSmear(camera, shownFrame)
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
