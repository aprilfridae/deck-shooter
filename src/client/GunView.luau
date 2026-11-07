-- The gun held in view, with the arms holding it. Uses the model in ReplicatedStorage.GunModels named after the gun,
local Palette = require(game:GetService("ReplicatedStorage"):WaitForChild("Guns"):WaitForChild("Palette"))
local BodyStyle = require(game:GetService("ReplicatedStorage"):WaitForChild("Guns"):WaitForChild("BodyStyle"))
-- or a grey block if that model hasn't been imported.
-- Guns with FirstPersonClips are held in the soldier's own arms (FirstPersonArms) once that model is imported:
-- every pose sits relative to the camera at the centre of the red eye bar, aiming down sights included.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmClip = require(ReplicatedStorage.Guns.ArmClip)
local ArmClips = require(ReplicatedStorage.Guns.ArmClips)
local CardClip = require(ReplicatedStorage.Guns.ArmClips.Card)
local ArmPose = require(ReplicatedStorage.Guns.ArmPose)
local GunConfig = require(ReplicatedStorage.Guns.GunConfig)
local FirstPersonClip = require(ReplicatedStorage.Guns.FirstPersonClip)
local FirstPersonClips = require(ReplicatedStorage.Guns.FirstPersonClips)
local CardView = require(script.Parent.CardView)
local PoseGun = require(script.Parent.PoseGun)
local FirstPersonArms = require(script.Parent.FirstPersonArms)
local ViewArms = require(script.Parent.ViewArms)

local PRIMARY_LENGTH = 2.4
local SIDEARM_LENGTH = 1
local MODEL_SCALE = 0.031
local BLOCK_SECTION = Vector2.new(0.3, 0.4)
local BARREL_RISE = 0.26 -- how far above the model's middle the barrel sits, as a share of its height
local HIP = CFrame.new(0.9, -0.8, -2)
local AIMED = CFrame.new(0, -0.55, -2)
local RELOAD_DIP = CFrame.new(0, -0.7, 0) * CFrame.Angles(math.rad(-25), 0, 0)
local KICK_BACK = 0.25
local EASE = 14
local POSE_FPS = 12 -- the gun and arms hold each pose like stop motion
-- The gun twitches a little on every step, like a hand-drawn line that never sits still.
local JITTER_MOVE = 0.012
local JITTER_TURN = math.rad(0.6)
local JITTER_SEED = 100
local IDLE_JITTER = 0.35 -- share of the jitter left while standing, walking or holding a card
local AIM_JITTER = 0.5 -- share of the idle jitter left while aiming down sights
-- Motion blur: Roblox can't blur one object, so faded copies of the gun and arms fill the jump between two poses.
local SMEAR_COPIES = BodyStyle.smearCopies
local SMEAR_TIME = BodyStyle.smearTime
local SMEAR_OPACITY = BodyStyle.smearOpacity
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
local held = HIP
local kick = 0
local shownStep = -1
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
local smearAt: number? = nil
-- The soldier's own arms and the posed gun, once FirstPersonArms is imported and the gun has FirstPersonClips.
local soldier: any = nil
local aimedLast = false
local aimChangedAt = -math.huge

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
	model:ScaleTo(MODEL_SCALE)
	model.WorldPivot = model:GetBoundingBox()
	local size = model:GetExtentsSize()
	length = size.Z
	barrelRise = size.Y * BARREL_RISE
	return model
end

local function hideSmears()
	smearAt = nil
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
	smearAt = nil
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
		smears[i] = { gun = gun, parts = parts, arms = ViewArms.makeGhost(), share = i / (SMEAR_COPIES + 1) }
	end
end

-- Spreads the copies between the frame that just ended and the one that just started.
local function startSmear(from: any, to: any)
	if #smears == 0 then
		makeSmears()
	end
	for _, smear in smears do
		smear.pose = from.gun:Lerp(to.gun, smear.share)
		if smear.arms then
			ViewArms.poseGhost(smear.arms, ArmClip.blendBones(from.bones, to.bones, smear.share))
		end
	end
	smearAt = os.clock()
end

-- Fades the copies out, with those nearest the new pose the strongest.
local function drawSmear(camera: Camera)
	if not smearAt then
		return
	end
	local fade = 1 - (os.clock() - smearAt) / SMEAR_TIME
	if fade <= 0 then
		hideSmears()
		return
	end
	local hold = camera.CFrame * held * HIP:Inverse()
	for _, smear in smears do
		local transparency = 1 - SMEAR_OPACITY * smear.share * fade
		for _, part in smear.parts do
			part.Transparency = transparency
		end
		smear.gun:PivotTo(hold * smear.pose)
		smear.gun.Parent = camera
		if smear.arms then
			ViewArms.placeGhost(smear.arms, camera, clips.meshOffset, transparency)
		end
	end
end

local GunView = {}

local function grips(): (any, any)
	if isSidearm then
		return SIDEARM_RIGHT, SIDEARM_LEFT
	end
	local right = { wrist = Vector3.new(PRIMARY_RIGHT.x, PRIMARY_RIGHT.y, length * RIGHT_GRIP_Z) }
	right.along, right.thumb = PRIMARY_RIGHT.along, PRIMARY_RIGHT.thumb
	local left = { wrist = Vector3.new(PRIMARY_LEFT.x, PRIMARY_LEFT.y, length * LEFT_GRIP_Z) }
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
	length = if isSidearm then SIDEARM_LENGTH else PRIMARY_LENGTH
	barrelRise = 0
	view = makeModel(GunConfig.guns[gunId].name) or makeBlock()
	clips = ArmClips[GunConfig.guns[gunId].name]
	if soldier then
		soldier.gun.model:Destroy()
		soldier = nil
	end
	local data = FirstPersonClips[GunConfig.guns[gunId].name]
	if data and FirstPersonArms.ready() then
		local idle = data.poses.Idle
		local gun = PoseGun.build(GunConfig.guns[gunId].name, data.parts, PoseGun.frame(idle.Mag), PoseGun.frame(idle.Action))
		if gun then
			soldier = {
				gun = gun,
				clips = FirstPersonClip.expand(data),
				muzzle = Vector3.new(table.unpack(data.muzzle)),
				reload = GunConfig.guns[gunId].reload,
				handle = nil,
			}
		end
	end
	firedAt = nil
	reloadAt = nil
	holsterAt = nil
	equipAt = os.clock()
	snapAt = nil
	shownFrame = nil
	shownBase = nil
	shownSnap = nil
	shownStep = -1
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
	if soldier then
		return if soldier.handle and soldier.gun.model.Parent then soldier.handle * soldier.muzzle else nil
	end
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
local function clipFrame(reloading: boolean, sprinting: boolean): any
	if holsterAt then
		local elapsed = os.clock() - holsterAt
		local frames = clips.holster.frames
		local frame = ArmClip.frameAt(clips.holster, elapsed)
		if frame or elapsed < HOLSTER_WAIT then
			return frame or frames[#frames]
		end
		holsterAt = nil
	end
	if equipAt then
		local frame = ArmClip.frameAt(clips.equip, os.clock() - equipAt)
		if frame then
			return frame
		end
		equipAt = nil
	end
	if reloading and not reloadAt then
		reloadClip = ArmClip.pickReload(clips, math.random())
	end
	reloadAt = if reloading then reloadAt or os.clock() else nil
	if reloadAt then
		local frame = ArmClip.frameAt(reloadClip, os.clock() - reloadAt)
		if frame then
			return frame
		end
	end
	if firedAt then
		local frame = ArmClip.frameAt(clips.fire, os.clock() - firedAt)
		if frame then
			return frame
		end
		firedAt = nil
	end
	return ArmClip.frameAt(if sprinting then clips.run else clips.idle, os.clock())
end

-- The snap frame to lay over the clip, if one is playing.
local function snapFrame(): any
	local frame = if snapAt then ArmClip.frameAt(clips.snap, os.clock() - snapAt) else nil
	if not frame then
		snapAt = nil
	end
	return frame
end

-- The soldier's frame. Swapping guns beats everything, then reloading, then a shot, then aiming in or out,
-- then aiming, running or idle. Reloads are stretched to the gun's reload time.
local function soldierFrame(reloading: boolean, sprinting: boolean, aiming: boolean): any
	local c = soldier.clips
	local now = os.clock()
	if holsterAt then
		local elapsed = now - holsterAt
		local frame = ArmClip.frameAt(c.holster, elapsed)
		if frame or elapsed < HOLSTER_WAIT then
			return frame or c.holster.frames[#c.holster.frames]
		end
		holsterAt = nil
	end
	if equipAt then
		local frame = ArmClip.frameAt(c.equip, now - equipAt)
		if frame then
			return frame
		end
		equipAt = nil
	end
	reloadAt = if reloading then reloadAt or now else nil
	if reloadAt then
		c.reload.fps = FirstPersonClip.fpsFor(c.reload, soldier.reload)
		local frame = ArmClip.frameAt(c.reload, now - reloadAt)
		if frame then
			return frame
		end
	end
	if firedAt then
		local frame = ArmClip.frameAt(if aiming then c.aimFire else c.fire, now - firedAt)
		if frame then
			return frame
		end
		firedAt = nil
	end
	if aiming ~= aimedLast then
		aimedLast = aiming
		aimChangedAt = now
	end
	local turning = ArmClip.frameAt(if aiming then c.aimIn else c.aimOut, now - aimChangedAt)
	if turning then
		return turning
	end
	if aiming then
		return ArmClip.frameAt(c.aim, now)
	end
	return ArmClip.frameAt(if sprinting then c.run else c.idle, now)
end

local function hideSoldier()
	if soldier then
		soldier.gun.model.Parent = nil
	end
	FirstPersonArms.hide()
end

-- With a card out, the gun drops, then the arms play the card flying across and holding it.
-- Returns true while the card has the screen.
local function showCard(camera: Camera, cardOut: boolean, step: number): boolean
	if not cardOut then
		if cardAt then
			cardAt, shownCard, holsterAt = nil, nil, nil
			equipAt = os.clock()
			shownFrame, shownBase, shownSnap = nil, nil, nil
			shownStep = -1
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
	end
	hideSoldier()
	local frame = ArmClip.frameAt(CardClip.draw, elapsed) or ArmClip.frameAt(CardClip.hold, os.clock())
	if frame ~= shownCard then
		shownCard = frame
		ViewArms.showFrame(CardClip.meshOffset, frame.bones)
	end
	CardView.show(camera, frame, ViewArms.shaken(step, JITTER_SEED, JITTER_MOVE * IDLE_JITTER, JITTER_TURN * IDLE_JITTER))
	ViewArms.jitter(step, IDLE_JITTER)
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
	local ease = 1 - math.exp(-dt * EASE)
	held = held:Lerp(goal, ease)
	kick *= math.exp(-dt * EASE)
	local turn = if shownGun then TURNS[GunConfig.guns[shownGun].name] else nil
	-- The camera stays smooth. Only the held pose steps.
	local step = ArmPose.step(os.clock(), POSE_FPS)
	if showCard(camera, cardOut, step) then
		return
	end
	if soldier then
		-- The soldier's own arms: every pose is relative to the camera at the centre of the red eye bar.
		local frame = soldierFrame(reloading, sprinting, aiming)
		local idle = not sprinting and not reloading and not firedAt
		-- Aiming twitches least, so the sights stay on the middle of the view.
		local jitter = if aiming and idle then IDLE_JITTER * AIM_JITTER elseif idle then IDLE_JITTER else 1
		local base = camera.CFrame * ViewArms.shaken(step, JITTER_SEED, JITTER_MOVE * jitter, JITTER_TURN * jitter)
		local bones = frame.bones
		local handle = base * PoseGun.frame(bones.Gun)
		soldier.handle = handle
		PoseGun.place(soldier.gun, handle, PoseGun.frame(bones.Mag), PoseGun.frame(bones.Action), camera)
		FirstPersonArms.place(camera, base, bones)
		if view then
			view.Parent = nil
		end
		hideSmears()
		ViewArms.hide()
		return
	end
	if clips then
		local frame = clipFrame(reloading, sprinting)
		local snap = snapFrame()
		if frame ~= shownBase or snap ~= shownSnap then
			local whole = if snap then ArmClip.overlay(frame, snap) else frame
			-- The idle breath moves too little to blur.
			local breathing = not snap
				and not shownSnap
				and table.find(clips.idle.frames, frame)
				and table.find(clips.idle.frames, shownBase)
			if shownFrame and not breathing then
				startSmear(shownFrame, whole)
			end
			shownFrame, shownBase, shownSnap = whole, frame, snap
			ViewArms.showFrame(clips.meshOffset, whole.bones)
		end
		-- Reloading and scoping still move the whole hold, on top of the clip.
		shown = held * HIP:Inverse() * frame.gun
	elseif step ~= shownStep then
		shownStep = step
		shown = held * CFrame.new(0, 0, KICK_BACK * kick) * (turn or CFrame.identity)
		local right, left = grips()
		ViewArms.pose(shown, right, left)
	end
	local idle = not sprinting and not reloading and (not clips or table.find(clips.idle.frames, shownBase) ~= nil)
	local jitter = if idle then IDLE_JITTER else 1
	view:PivotTo(camera.CFrame * shown * ViewArms.shaken(step, JITTER_SEED, JITTER_MOVE * jitter, JITTER_TURN * jitter))
	view.Parent = camera
	ViewArms.jitter(step, jitter)
	ViewArms.place(camera)
	drawSmear(camera)
end

function GunView.hide()
	if view then
		view.Parent = nil
	end
	hideSoldier()
	hideSmears()
	CardView.hide()
	ViewArms.hide()
end

return GunView
