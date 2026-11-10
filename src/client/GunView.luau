-- The gun held in view, with the arms holding it. Uses the model in ReplicatedStorage.GunModels named after the gun,
local Palette = require(game:GetService("ReplicatedStorage"):WaitForChild("Guns"):WaitForChild("Palette"))
-- or a grey block if that model hasn't been imported.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmClip = require(ReplicatedStorage.Guns.ArmClip)
local Loosen = require(ReplicatedStorage.Guns.Loosen)
local GunAudio = require(script.Parent.GunAudio)
local AkReload = require(ReplicatedStorage.Guns.AkReload)
local SoldierPose = require(ReplicatedStorage.Guns.SoldierPose)
local ArmClips = require(ReplicatedStorage.Guns.ArmClips)
local CardFlourish = require(ReplicatedStorage.Guns.CardFlourish)
local GunConfig = require(ReplicatedStorage.Guns.GunConfig)
local CardInHand = require(script.Parent.CardInHand)
local CardView = require(script.Parent.CardView)
local ViewArms = require(script.Parent.ViewArms)

local PRIMARY_LENGTH = 2.4
local SIDEARM_LENGTH = 1
local MODEL_SCALE = 0.031
-- Guns that looked too small in the soldier's hands are drawn bigger. The grips move with them.
local VIEW_SCALES: { [string]: number } = { Longscope = 1.35, M57 = 1.25, ["Energy Pistol"] = 1.19 }
-- Where the left hand holds a gun, as a share of its length from the middle, where the usual spot is out of reach.
-- Too far forward and the arm locks straight with the shoulder sliding into view.
local LEFT_GRIPS: { [string]: number } = { Longscope = -0.065 } -- under the lever rifle's fore-end
local leftGrip = LEFT_GRIP_Z
-- Where a gun's own shape needs the hands moved, in studs. The Longscope is a lever rifle: its right hand sits in
-- the lever loop, behind and below the trigger, and its fore-end is shallow, so the left hand comes up to meet it.
local GRIP_SHIFTS: { [string]: { right: Vector3, left: Vector3 } } = {
	Longscope = { right = Vector3.new(0, 0, 0.54), left = Vector3.new(-0.07, 0.08, 0) },
}
local gripShift: { right: Vector3, left: Vector3 }? = nil
-- Shoulders moved for a gun, in camera space. The Longscope's left arm comes up from below instead of
-- reaching across the screen.
local SHOULDERS: { [string]: { [string]: Vector3 } } = { Longscope = { Left = Vector3.new(-0.55, -1.8, 0.2) } }
-- How far a thumb curls around the gun, in radians at the tip.
-- The lever rifle's fore-end is fat: the left hand sits a little to its left and its thumb only leans in, so the
-- thumb rests up the side where it shows instead of curling into the wood.
local THUMB_WRAPS: { [string]: { [string]: number } } = { Longscope = { Left = math.rad(25) } }
-- Guns with a lever: the parts named Lever_... swing about `pivot` and the ones named Bolt_... slide back with it.
-- pivot and slide are in the stored model's studs from its middle (see docs/HANDOFF.md for the lever rifle's
-- numbers); swing is how far the lever opens, down and forward.
local LEVERS: { [string]: { pivot: Vector3, swing: number, slide: number } } = {
	Longscope = { pivot = Vector3.new(0, -1.82, 9.1), swing = math.rad(55), slide = 6.08 },
}
local lever: { pivot: Vector3, swing: number, slide: number }? = nil -- the gun shown's, in view studs
local leverParts: { { part: BasePart, rest: CFrame, slides: boolean } } = {}
local BLOCK_SECTION = Vector2.new(0.3, 0.4)
local BARREL_RISE = 0.26 -- how far above the model's middle the barrel sits, as a share of its height
local BARREL_RISES: { [string]: number } = { Longscope = 0.098, M57 = 0.29, ["Energy Pistol"] = 0.38 } -- guns whose barrel sits somewhere else
-- Where a gun's model sits from the spot the hold and the clips turn it about: the model's ViewShift attribute, in
-- its own studs. Without one, that spot is the middle of the model. The M57 is River's AK now, held by clips made
-- for the old model, so its ViewShift puts its trigger where the old one's was.
-- Small moves of a gun in the hands on top of that, by eye, in view studs (-Z is forward).
local VIEW_NUDGES: { [string]: Vector3 } = { ["Energy Pistol"] = Vector3.new(0, 0.12, -0.12) }
local modelShift = Vector3.zero -- the gun shown's, in view studs
-- Hands moved along a gun from where its clips have them, in studs in the gun's own space. The M57's clips were made
-- on the old model, whose fore-end was where the AK's magazine is, so the left hand goes forward to the handguard.
-- Its right hand sat a little too far up the gun, which bent the trigger finger back on itself, and a little too
-- high on it, so it goes back and down.
local CLIP_NUDGES: { [string]: { [string]: Vector3 } } = {
	M57 = { Left = Vector3.new(0, 0.05, -0.42), Right = Vector3.new(0, -0.05, 0.08) },
}
-- Digits shaped in their own palm's space (+Y along the fingers; for a left hand -X is the way the palm faces and
-- -Z is the thumb's side): rest is on the gun, held is with something in the hand in a coded reload, and it blends
-- between them with the reload's hold on the hand. The M57's clips curled the left thumb over the top of the old
-- fore-end, which on the AK put it into the handguard. Resting, it now lies straight forward along the handguard
-- beside the fingers; holding a magazine, it wraps round the back of it, opposite the fingers.
local PALM_FINGERS: { [string]: { [string]: { [string]: { rest: { Vector3 }, held: { Vector3 } } } } } = {
	M57 = {
		Left = {
			Pulgar = {
				rest = {
					Vector3.new(0.1, 0.9, -0.35).Unit,
					Vector3.new(0.05, 0.98, -0.15).Unit,
					Vector3.new(0, 1, 0),
				},
				held = {
					Vector3.new(-0.3, 0.5, -0.8).Unit,
					Vector3.new(-0.8, 0.5, -0.3).Unit,
					Vector3.new(-0.95, 0.3, 0).Unit,
				},
			},
		},
	},
}
local clipPalms: { [string]: CFrame }? = nil -- this frame's moved palms, in the clip's space
-- Fingers given another shape than the clips', by side and digit bone: which way each joint points, in the gun's own
-- space. The M57's clips were made on the old model, and on the AK they left the trigger finger lying straight along
-- the outside of the trigger guard. With the hand back a little (CLIP_NUDGES), it runs forward along the side, turns
-- down and in, and lays its tip across the front of the blade (measured against the AK's trigger: the tip crosses
-- it within about 0.01 studs).
local CLIP_FINGERS: { [string]: { [string]: { [string]: { Vector3 } } } } = {
	M57 = {
		Right = {
			Indice = {
				Vector3.new(0.029, -0.004, -0.147).Unit, -- straight forward along the side of the gun
				Vector3.new(-0.094, -0.027, 0.019).Unit, -- then in to the trigger
				Vector3.new(-1, 0, 0.05).Unit, -- and its tip across the front of the blade
			},
			-- The thumb lay forward along the right side of the gun. It wraps round the back of the grip instead:
			-- across behind it, round onto its left side, and forward along that.
			Pulgar = {
				Vector3.new(-0.9, -0.2, -0.2).Unit, -- dipping under the back of the receiver
				Vector3.new(-0.75, -0.1, -0.65).Unit,
				Vector3.new(-0.2, -0.15, -0.97).Unit,
			},
		},
	},
}
-- The M57 is River's AK, and its reload's left hand, magazine and bolt are keyed in code on the AK's own shape
-- (AkReload), over the old clip's gun and right hand. perMetre is the stored model's studs to a metre and middle
-- is the model's middle in River's handoff (metres, +X muzzle, +Y left, +Z up).
local CODE_RELOADS: { [string]: { reload: any, perMetre: number, middle: Vector3 } } = {
	M57 = { reload = AkReload, perMetre = 91.09, middle = Vector3.new(0.137, -0.011, -0.0535) },
}
local codeReload: { reload: any, perMetre: number, origin: Vector3 }? = nil -- the gun shown's, in view studs
local codeReloadAt: number? = nil -- when it started
local codeReloading = false -- whether this reload has started it
local codePose: any = nil -- this frame's
local codeTurn = CFrame.identity -- this frame's turn of the gun, in view studs
local wristFlip = CFrame.identity -- this frame's flip of the gun about the wrist from a shot, in the clip's space
local smearFrame: any = nil -- this frame's pose for the motion blur, on a gun with clips
local codeParts: { { part: BasePart, rest: CFrame, slides: boolean } } = {}
local spareParts: { { part: BasePart, rest: CFrame } } = {} -- a second magazine, for while there are two
local spareShown = false
local HIP = CFrame.new(0.9, -0.8, -2)
-- Up against a wall the gun and arms would poke through it and vanish. So when something solid is closer in front
-- than the gun reaches, the whole view is tucked in: the muzzle tips up and the hold comes back and down, more the
-- closer the thing is. The cards, which sit closer in, just come back and down.
local WALL_REACH = 4.2 -- studs in front of the eye a gun needs clear
local CARD_REACH = 2.6 -- and the cards
local WALL_NEAR = 0.9 -- at this close it's tucked all the way
local WALL_WIDTH = 0.55 -- how wide a path is checked: the radius of the ball swept forward
local WALL_BEHIND = 0.7 -- the sweep starts this far behind the eye, so a wall the eye is against still counts
local WALL_EASE = 12 -- how fast it tucks and comes back, a second
local WALL_PITCH = math.rad(66) -- how far the muzzle tips up, tucked all the way
local WALL_BACK = 0.85 -- studs the hold comes back
local WALL_DROP = 0.3 -- and down
local CARD_BACK = 1.1 -- the same for the cards
local CARD_DROP = 0.35
local wallShare = 0 -- how tucked the view is, 0 to 1
local wallParams = RaycastParams.new()
wallParams.FilterType = Enum.RaycastFilterType.Exclude
wallParams.RespectCanCollide = true -- only things that are really in the way

-- Eases wallShare toward how tucked the view should be, for something that needs `reach` studs clear.
local function tuck(camera: Camera, dt: number, reach: number): number
	wallParams.FilterDescendantsInstances = { camera, Players.LocalPlayer.Character :: Instance }
	local eye = camera.CFrame
	local hit = workspace:Spherecast(
		eye.Position - eye.LookVector * WALL_BEHIND,
		WALL_WIDTH,
		eye.LookVector * (reach + WALL_BEHIND),
		wallParams
	)
	local clear = if hit then math.max(hit.Distance - WALL_BEHIND, 0) else reach
	local wanted = math.clamp((reach - clear) / (reach - WALL_NEAR), 0, 1)
	wallShare += (wanted - wallShare) * (1 - math.exp(-dt * WALL_EASE))
	return wallShare
end
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
-- Guns that sank too low sprinting: their own lean, and how much of the footstep dip they take.
local SPRINT_HOLDS: { [string]: CFrame } = {
	["Energy Pistol"] = CFrame.new(0.02, -0.02, 0.03) * CFrame.Angles(math.rad(-2), math.rad(3), math.rad(2)),
	M57 = CFrame.new(0.03, -0.03, 0.05) * CFrame.Angles(math.rad(-3), math.rad(4), math.rad(3)),
}
local BOB_DIPS: { [string]: number } = { ["Energy Pistol"] = 0.5, M57 = 0.7 }
local EASE = 11
-- Idle: the gun is never quite still. It drifts and turns on the same slow wander as the hands holding the
-- deck (Loosen.drift). Running leaves the player winded, so it wanders bigger and quicker for a few seconds after.
local BREATH_MOVING = 0.3 -- the share left while walking, where the bob takes over
local BREATH_AIMED = 0.35
local WINDED_SIZE = 1.9 -- how much bigger, and
local WINDED_SPEED = 1.5 -- how much quicker, the wander is right after a sprint
local WINDED_GAIN = 0.35 -- per second of sprinting
local WINDED_FADE = 0.2 -- per second of rest
-- A new clip fades in from the last pose over this long, so the end of a reload doesn't cut to idle.
-- A shot and a swap start at once, so they keep their snap.
local CLIP_BLEND = 0.25
local RELOAD_BLEND = 1 -- the end of a reload settles into the next clip slowly, with weight
local SNAP_BLEND = 0.12 -- a shot fired while the gun is still settling catches up this fast
-- Times a reload clip to its sound: pairs of seconds into the sound and the clip time that should show then. In
-- reload-assault-v4.wav the mag clicks out at 0.42s, slams in at 0.64s and the charge is pulled at 0.86s; the
-- clip's hand jerks the mag out at 0.43s, drives the new one home at 0.68s and slaps at 0.86s. The slap is held back to 0.93s: River times it by ear
-- against the sound, so move it only as asked. The last pair ends the clip with the reload.
local RELOAD_SYNC: { [string]: { { number } } } = {
	M57 = { { 0, 0 }, { 0.42, 0.43 }, { 0.64, 0.68 }, { 0.93, 0.86 }, { 0.985, 0.985 } },
}
-- Motion blur: Roblox can't blur one object, so faded copies of the gun and arms trail behind them,
-- spread between where they were SMEAR_TIME ago and where they are now. Only while the gun moves fast enough.
local SMEAR_COPIES = 12 -- a lot of them, over a long trail: River wants it over the top
local SMEAR_TIME = 0.14
local SMEAR_OPACITY = 0.075
local SMEAR_MIN_MOVE = 0.04 -- studs the gun must travel in SMEAR_TIME to blur
local SMEAR_MIN_TURN = math.rad(4)
local SNAPPY = { fire = true }
-- How each gun moves when it fires: pushed back and dropped (studs), barrel up and rolled (degrees).
-- A single shot pushes out over rise seconds, fast then easing into the peak. An automatic gets a shove each
-- shot that stacks a little while spraying. Either way the gun comes home on a spring (stiff, damp) that swings
-- a little past. Guns with clips (M57, Energy Pistol) move the whole view, arms and all, on top of the clip.
local VIEW_KICKS: { [string]: any } = {
	M57 = {
		back = 0.066, drop = 0.011, up = 1.5, roll = 0.9, stiff = 315, damp = 27.8, auto = true,
		-- A slower layer under the shot kicks: each shot pushes it further (up to 1), and once firing stops it
		-- eases home on its own soft spring, so the gun takes its time getting back to its shooting position.
		settle = { back = 0.08, drop = 0.035, up = 2.4, perShot = 0.3, stiff = 28, damp = 10.5 },
	},
	B33 = { back = 0.154, drop = 0.022, up = 3.3, roll = 1.5, stiff = 270, damp = 24.4, auto = true },
	SMG = { back = 0.099, drop = 0.011, up = 2.2, roll = 1.3, stiff = 360, damp = 29.6, auto = true },
	-- A hard, snappy kick that never goes the same way twice: it rolls to either side (sides), and each shot's
	-- climb, shove, roll and twist vary twice as much as other guns' (loose).
	["Energy Pistol"] = {
		back = 0.16, drop = 0.04, up = 8, roll = 2.5, rise = 0.04, stiff = 70, damp = 12.5, sides = true, loose = 1.5,
		left = 2.5, -- degrees the muzzle kicks to the left as well
		stillLeft = true, -- the kick is the gun hand's: the left hand stays where it is
		wrist = 5, -- degrees more the gun snaps up about the wrist, on top of the whole arm's kick
		-- Its soft spring (it was 165 and 19.1) takes about twice as long to bring it home.
	},
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
	-- reload-pistol-v4.wav is quiet until the new cell slams in at 0.58s, with the slide racked at 0.68s and home by
	-- about 0.74s. The pistol has a reload clip, so this layers on top of it and turns the whole hold, arms and all,
	-- for weight: the gun sags as the old cell leaves and winds down further before the slam, the slam drives it up
	-- and back hard and it drops past, the rack yanks it back with the muzzle dipping, and the slide flying home throws
	-- it forward before it settles.
	["Energy Pistol"] = {
		length = 0.964,
		layer = true,
		keys = {
			key(0, CFrame.identity, Vector3.zero),
			key(0.12, tilt(6, -3, 5, 0, 0.02, 0.01), Vector3.zero, "flow"), -- lifts as the cell is let go
			key(0.3, tilt(10, -5, -4, -0.02, -0.05, 0), Vector3.zero, "flow"), -- and sags, lighter in the hand
			key(0.5, tilt(13, -6, -7, -0.02, -0.08, 0.01), Vector3.zero, "flow"), -- winds down before the slam
			key(0.58, tilt(7, -3, 13, -0.01, 0.1, 0.06), Vector3.zero, "in"), -- SLAM: driven up and back
			key(0.63, tilt(11, -5, -6, -0.02, -0.07, 0), Vector3.zero, "out"), -- and drops past
			key(0.68, tilt(4, -2, -10, 0, -0.04, 0.08), Vector3.zero, "in"), -- the rack yanks it back, muzzle dipping
			key(0.74, tilt(2, -1, 9, 0, 0.05, -0.06), Vector3.zero, "out"), -- the slide flies home and throws it forward
			key(0.84, tilt(-2, 1, -3, 0, -0.02, 0.01), Vector3.zero, "flow"), -- it rocks back past ready
			key(0.964, CFrame.identity, Vector3.zero, "flow"),
		},
	},
	-- gun-sniper-base.wav, from the shot: the blast, a rising click from 1s peaking at 1.04s, a clunk at 1.32s and a
	-- whirr to 1.6s. The gun spins once backwards round the trigger finger while the blast rings out and the left
	-- hand catches it; the right hand throws the lever open on the click, slams it shut on the clunk, and the gun
	-- settles back to ready through the whirr.
	Longscope = {
		length = 1.714,
		-- It reloads after every shot, so its keys start at the shot: the reload itself begins lead seconds later.
		-- The kick throws the barrel up and that same turn carries on into the backward spin, one throw from the
		-- shot to the catch, with no stop or change of direction between them.
		lead = 0.12,
		-- The kick starts the turn, it eases off a little, then the left hand shoves it round faster, and it coasts into
		-- the catch. Never close to a stop until the hand has it.
		spin = {
			from = 0,
			to = 0.62,
			points = { { 0, 0, 2 }, { 0.15, 0.25, 1.3 }, { 0.26, 0.55, 3.4 }, { 0.62, 1, 0.6 } },
		},
		smoothFrom = 0.15, -- seconds in: everything after the kick gets a touch more smoothing on top, so no jolt is hard
		-- How far open the lever is (0 to 1) at each time: thrown open into the click, held, and slammed shut on the
		-- clunk. Each move speeds up into its stop.
		lever = { { 0.92, 0 }, { 1.03, 1 }, { 1.2, 1 }, { 1.32, 0 } },
		keys = {
			key(0, CFrame.identity, Vector3.zero),
			-- The shot heaves it back and up, slowly enough to feel the hit, knocking the left hand off; then it sinks
			-- back down slowly while it spins.
			key(0.15, tilt(-9, 0, 0, 0, 0.34, 0.6), Vector3.new(0, 0.03, -0.4), "out"),
			-- The left hand drives the gun up into the flip and stops there, held up in the air; the gun turns over above
			-- it and drops back down into it (each key's gun and hand add up to the same spot), then hand and gun sink
			-- back down together.
			key(0.2, tilt(-7, 0, 0, 0, 0.33, 0.45), Vector3.new(0, -0.11, -0.05), "flow"), -- the hand gets under it
			key(0.28, tilt(-4, 0, 0, 0, 0.34, 0.2), Vector3.new(0.02, 0.12, -0.18), "out"), -- shoves it up and stops
			key(0.44, tilt(-2, 0, 0, 0, 0.53, 0.05), Vector3.new(0.02, -0.06, -0.03), "flow"), -- it flips up above the hand
			key(0.56, tilt(1, -1, 1, 0.01, 0.47, 0.02), Vector3.new(0.01, -0.03, 0), "flow"), -- and comes back down, the hand already easing down to meet it
			key(0.62, tilt(4, -2, 2, 0.02, 0.41, 0.02), Vector3.zero, "flow"), -- landing in the hand
			key(0.68, tilt(8, -3, -5, -0.01, 0.27, 0.02), Vector3.new(0, -0.03, 0), "flow"), -- both hands drop with the weight straight away
			key(0.79, tilt(10, -4, 2, -0.03, 0.1, 0.03), Vector3.zero, "flow"), -- then it sinks into both hands, canted a little
			-- CLICK: the left hand keeps hold of the fore-end and the right hand throws the lever open, down and
			-- forward. The throw shoves the gun down and forward and kicks its muzzle up, and it rebounds.
			key(0.92, tilt(11, -4, 2.5, -0.03, 0.05, 0.03), Vector3.zero, "flow"), -- a small wind-up
			key(1.03, tilt(9.5, -3, 4.5, -0.02, -0.04, -0.05), Vector3.zero, "flow"), -- CLICK: the lever hits its stop
			key(1.1, tilt(10, -3, 2, -0.02, -0.02, -0.035), Vector3.zero, "flow"),
			key(1.2, tilt(10.5, -4, 2, -0.03, -0.025, -0.03), Vector3.zero, "flow"), -- held open
			-- CLUNK: the hand slams the lever shut, which shoves the gun up and back and dips its muzzle, and it
			-- eases back round to ready and settles.
			key(1.32, tilt(6, -2, -3, -0.01, 0.045, 0.065), Vector3.zero, "flow"),
			key(1.42, tilt(3, -1, -0.5, 0, 0.015, 0.03), Vector3.zero, "flow"),
			key(1.55, tilt(-1, 0.3, -0.5, 0.002, -0.006, 0.015), Vector3.zero, "flow"), -- and it rocks back a touch
			key(1.77, CFrame.identity, Vector3.zero, "flow"),
		},
	},
}

local flowHand: (any, number, number) -> Vector3
local flowing: (any, number, number) -> CFrame
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
	local points = spin.points
	if points then
		-- Points of { seconds, share of the turn, turns a second } joined by smooth curves, so the turn can slow
		-- and then be shoved faster again.
		for index = 2, #points do
			local a, b = points[index - 1], points[index]
			if at < b[1] then
				local span = b[1] - a[1]
				local u = (at - a[1]) / span
				local u2, u3 = u * u, u * u * u
				local turned = a[2] * (2 * u3 - 3 * u2 + 1)
					+ a[3] * span * (u3 - 2 * u2 + u)
					+ b[2] * (-2 * u3 + 3 * u2)
					+ b[3] * span * (u3 - u2)
				return turned * 2 * math.pi
			end
		end
		return 0
	end
	local u = (at - spin.from) / (spin.to - spin.from)
	-- Leaves already moving at launch times its average speed, and slows to a stop in the hand.
	local s = spin.launch or 1.2
	local eased = s * u + (3 - 2 * s) * u * u + (s - 2) * u * u * u
	return eased * 2 * math.pi
end

-- The gun's offset, the left hand's, and the gun's backward spin in radians, elapsed seconds into a keyed reload.
-- "flow" keys run through each other on one smooth curve instead of stopping at each one: a key between two flow
-- moves is passed through at speed, and one next to any other ease is stopped at, as that ease expects.
local function tangent(keys: any, index: number, value: (any) -> any): any
	local before, key, after = keys[index - 1], keys[index], keys[index + 1]
	if not before or not after or key.ease ~= "flow" or after.ease ~= "flow" then
		return value(key) * 0
	end
	return (value(after) - value(before)) / (after.at - before.at)
end
local function hermite(keys: any, index: number, u: number, value: (any) -> any): any
	local from, to = keys[index - 1], keys[index]
	local span = to.at - from.at
	local u2, u3 = u * u, u * u * u
	return value(from) * (2 * u3 - 3 * u2 + 1)
		+ tangent(keys, index - 1, value) * (span * (u3 - 2 * u2 + u))
		+ value(to) * (-2 * u3 + 3 * u2)
		+ tangent(keys, index, value) * (span * (u3 - u2))
end
local function handOf(key: any): Vector3
	return key.hand
end
local function placeOf(key: any): Vector3
	return key.gun.Position
end
local function turnOf(key: any): Vector3
	local axis, angle = key.gun:ToAxisAngle()
	return axis * angle
end
function flowHand(keys: any, index: number, u: number): Vector3
	return hermite(keys, index, u, handOf)
end
function flowing(keys: any, index: number, u: number): CFrame
	local from, to = keys[index - 1], keys[index]
	-- The turn rides the same kind of curve as the move, as a turn vector (axis times angle), so the gun doesn't
	-- change how fast it's turning at a key.
	local turn = hermite(keys, index, u, turnOf)
	local angle = turn.Magnitude
	local turned = if angle > 1e-5 then CFrame.fromAxisAngle(turn / angle, angle) else CFrame.identity
	return CFrame.new(hermite(keys, index, u, placeOf)) * turned
end

-- How far open a reload has the gun's lever, 0 to 1.
local function leverAt(reload: any, at: number): number
	local track = reload.lever
	if not track or at <= track[1][1] then
		return 0
	end
	for index = 2, #track do
		local from, to = track[index - 1], track[index]
		if at < to[1] then
			local u = (at - from[1]) / (to[1] - from[1])
			return from[2] + (to[2] - from[2]) * u * u
		end
	end
	return track[#track][2]
end

-- A reload with a lead counts from the shot before it, and only the part after the lead stretches.
-- Returns the gun's move, the left hand's, the spin and how far open the lever is.
local function reloadPose(reload: any, elapsed: number, reloadTime: number): (CFrame, Vector3, number, number)
	local lead = reload.lead or 0
	local at = if elapsed < lead then elapsed else lead + (elapsed - lead) * reload.length / reloadTime
	local keys = reload.keys
	for index = 2, #keys do
		local to = keys[index]
		if at < to.at then
			local from = keys[index - 1]
			local u = (at - from.at) / (to.at - from.at)
			if to.ease == "flow" then
				return flowing(keys, index, u), flowHand(keys, index, u), spinAt(reload, at), leverAt(reload, at)
			end
			u = eased(to.ease, u)
			return from.gun:Lerp(to.gun, u), from.hand:Lerp(to.hand, u), spinAt(reload, at), leverAt(reload, at)
		end
	end
	return CFrame.identity, Vector3.zero, 0, 0
end

-- Scoping in and out is quick on a gun that can scope.
local AIM_EASE = 24 -- lowering a scoped gun
local SCOPE_IN_EASE = 13 -- raising it to the eye, about a quarter of a second

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

-- Scopes: aiming lines the gun's sight up with your eye, and once it's there the screen shows the view through it
-- and the gun is hidden. part is the sight's glass in the model; eye is how far in front of the camera its back end
-- sits.
local SCOPES: { [string]: { part: string, eye: number } } = {
	Longscope = { part = "sight_glass_low", eye = 0.15 },
}
local SCOPE_SHOW_FROM = 0.82 -- share of the way in when the scope view appears and the gun hides
local SCOPE_FULL_AT = 0.88 -- when the scope view is solid: a fade of a frame or two, so it never pops
local scopeAim: CFrame? = nil -- the hold that lines the sight up with the eye, for the gun shown
local scopeShare = 0 -- how far into the scope the view is, 0 to 1
local scopeGui: ScreenGui? = nil
local scopeGroup: CanvasGroup? = nil

-- A round lens in black, with a thin reticle: drawn with frames, no images needed.
local function makeScopeGui(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "Scope"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -1 -- under the HUD
	local group = Instance.new("CanvasGroup")
	group.Size = UDim2.fromScale(1, 1)
	group.BackgroundTransparency = 1
	group.GroupTransparency = 1
	group.Parent = gui
	scopeGroup = group
	local lens = Instance.new("Frame")
	lens.AnchorPoint = Vector2.new(0.5, 0.5)
	lens.Position = UDim2.fromScale(0.5, 0.5)
	lens.Size = UDim2.fromScale(0.92, 0.92)
	lens.BackgroundColor3 = Palette.DataCyan
	lens.BackgroundTransparency = 0.95 -- a faint tint on the glass
	lens.Parent = group
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.DominantAxis = Enum.DominantAxis.Height
	aspect.Parent = lens
	Instance.new("UICorner", lens).CornerRadius = UDim.new(0.5, 0)
	-- Everything outside the lens is the scope's black tube.
	local tube = Instance.new("UIStroke")
	tube.Thickness = 4000
	tube.Color = Color3.new(0, 0, 0)
	tube.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	tube.Parent = lens
	-- A soft dark edge just inside the rim.
	local rim = Instance.new("Frame")
	rim.AnchorPoint = Vector2.new(0.5, 0.5)
	rim.Position = UDim2.fromScale(0.5, 0.5)
	rim.Size = UDim2.fromScale(1, 1)
	rim.BackgroundTransparency = 1
	rim.Parent = lens
	Instance.new("UICorner", rim).CornerRadius = UDim.new(0.5, 0)
	local rimStroke = Instance.new("UIStroke")
	rimStroke.Thickness = 14
	rimStroke.Color = Color3.new(0, 0, 0)
	rimStroke.Transparency = 0.35
	rimStroke.Parent = rim
	local function line(size: UDim2, position: UDim2, anchor: Vector2)
		local piece = Instance.new("Frame")
		piece.Size = size
		piece.Position = position
		piece.AnchorPoint = anchor
		piece.BackgroundColor3 = Color3.new(0, 0, 0)
		piece.BackgroundTransparency = 0.15
		piece.BorderSizePixel = 0
		piece.Parent = lens
	end
	-- Fine hairs through the middle, and thick posts in from the rim.
	line(UDim2.new(1, 0, 0, 1), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	line(UDim2.new(0, 1, 1, 0), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	line(UDim2.new(0.36, 0, 0, 5), UDim2.fromScale(0, 0.5), Vector2.new(0, 0.5))
	line(UDim2.new(0.36, 0, 0, 5), UDim2.fromScale(1, 0.5), Vector2.new(1, 0.5))
	line(UDim2.new(0, 5, 0.36, 0), UDim2.fromScale(0.5, 1), Vector2.new(0.5, 1))
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(4, 4)
	dot.BackgroundColor3 = Palette.SignalAcid
	dot.BorderSizePixel = 0
	dot.Parent = lens
	Instance.new("UICorner", dot).CornerRadius = UDim.new(0.5, 0)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

local function showScope(share: number)
	local fade = math.clamp((share - SCOPE_SHOW_FROM) / (SCOPE_FULL_AT - SCOPE_SHOW_FROM), 0, 1)
	if fade > 0 then
		scopeGui = scopeGui or makeScopeGui()
	end
	if scopeGroup then
		scopeGroup.GroupTransparency = 1 - fade
	end
	if scopeGui then
		scopeGui.Enabled = fade > 0
	end
	local shown = fade >= 1
	if Players.LocalPlayer:GetAttribute("ScopeShown") ~= (if shown then true else nil) then
		Players.LocalPlayer:SetAttribute("ScopeShown", if shown then true else nil)
	end
end
local kick = 0
local kickSpeed = 0
local kickRoll = 1 -- which way this shot rolls
local shot: Loosen.Shot = Loosen.STEADY -- how this shot differs from the usual
local settle, settleSpeed, settleGoal = 0, 0, 0
local shown = HIP
local clips: any = nil
local firedAt: number? = nil
local reloadAt: number? = nil
local reloadClip: any = nil
local keyedReloadAt: number? = nil -- when a keyed reload started, or the shot that starts it
local layerAt: number? = nil -- when a clip gun's reload layer started; it plays to its end even if the reload ends first
local layerShown = CFrame.identity
local reloadShown, handShown = CFrame.identity, Vector3.zero -- a code-posed gun's reload, smoothed
local leverOpen = 0 -- how far open the gun shown's lever is, 0 to 1
local snapAt: number? = nil
local cardAt: number? = nil
local cardUsed = 0 -- how many cards had been used when this one came out
local crushAt: number? = nil -- when the card in hand was used
local cardTurns = 0 -- CardInHand.turns as of the last look
local turns = 0 -- how many times the card held has been changed since the cards came out
local turnAt = 0 -- when it last was
local cardLife = 0 -- where this time out starts in the hands' sway, so no two go alike
-- The same for a gun's reload (and the Longscope's flip): its tempo and a little drift of the hold.
local LOOSE_EASE = 8 -- how fast the drift comes on and goes
local looseLife = 0
local looseShare = 0
local loosePlaying = false
local shownFrame: any = nil -- what's on screen, with any snap laid over it
local shownBase: any = nil
local shownSnap: any = nil
local smears: { any } = {}
local smearShown = false
local SMEAR_FADE = 14 -- how fast the blur fades in and out, a second
local smearStrength = 0 -- how much of it shows, 0 to 1
local smearSteppedAt = 0
local history: { { at: number, frame: any } } = {} -- recent poses, oldest first
local shownKind: string? = nil -- which clip is playing
local blendFrom: any = nil -- the pose a clip change fades out of
local blendAt = 0
local blendLength = CLIP_BLEND

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
	local middle = model:GetBoundingBox()
	local shift = source:GetAttribute("ViewShift")
	modelShift = (if typeof(shift) == "Vector3" then shift else Vector3.zero) * (MODEL_SCALE * viewScale)
		+ (VIEW_NUDGES[name] or Vector3.zero)
	model.WorldPivot = middle * CFrame.new(-modelShift)
	local size = model:GetExtentsSize()
	length = size.Z
	barrelRise = size.Y * (BARREL_RISES[name] or BARREL_RISE)
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
		-- A coded reload moves the magazine and bolt and shows a spare magazine. The blur copies' magazine and bolt
		-- follow the real ones (see drawSmear), and they have no spare.
		local rests = {}
		for _, moving in codeParts do
			rests[moving.part.Name] = moving
		end
		local parts, movers = {}, {}
		for _, part in gun:GetDescendants() do
			if part:IsA("BasePart") and part.Name == "Spare" then
				part:Destroy()
			elseif part:IsA("BasePart") then
				local real = rests[part.Name]
				if real then
					table.insert(movers, { part = part, rest = real.rest, slides = real.slides })
				end
				-- Blur copies glow in one flat colour: white nearest the gun, blue furthest back.
				part.Color = Palette.blur(i / SMEAR_COPIES)
				part.Material = Enum.Material.Neon
				if part:IsA("MeshPart") then
					part.TextureID = ""
				end
				for _, look in part:GetChildren() do
					if look:IsA("SurfaceAppearance") or look:IsA("Decal") or look:IsA("Texture") then
						look:Destroy()
					end
				end
				table.insert(parts, part)
			end
		end
		if gun:IsA("BasePart") then
			table.insert(parts, gun)
		end
		smears[i] = {
			gun = gun,
			parts = parts,
			movers = movers,
			arms = ViewArms.makeGhost(i / SMEAR_COPIES),
			share = i / (SMEAR_COPIES + 1),
		}
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
	-- The blur fades in as the gun gets going and out as it stops, over a few frames, so it never flickers on and
	-- off. It's wanted in full once the gun moves twice as fast as the least that blurs.
	local going = math.max(moved / SMEAR_MIN_MOVE, math.abs(turned) / SMEAR_MIN_TURN)
	local wanted = math.clamp(going - 1, 0, 1)
	local step = math.min(now - smearSteppedAt, 0.1)
	smearSteppedAt = now
	smearStrength += (wanted - smearStrength) * (1 - math.exp(-step * SMEAR_FADE))
	if smearStrength < 0.02 then
		smearStrength = 0
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
		local transparency = 1 - SMEAR_OPACITY * smear.share * smearStrength
		for _, part in smear.parts do
			part.Transparency = transparency
		end
		local placed = hold * from.gun:Lerp(whole.gun, smear.share)
		smear.gun:PivotTo(placed)
		if whole.mag and #smear.movers > 0 then
			-- The copy's magazine and bolt go where the real ones are, trailing like the gun. A magazine that has
			-- just changed places (the old one gone, the new one in) doesn't streak between the two.
			local was = from.mag or whole.mag
			local near = (was.Position - whole.mag.Position).Magnitude < 0.6
			local swapped = placed * (if near then was:Lerp(whole.mag, smear.share) else whole.mag)
			local back = (from.bolt or whole.bolt)
			local slid = placed * CFrame.new(0, 0, back + (whole.bolt - back) * smear.share)
			for _, moving in smear.movers do
				moving.part.CFrame = (if moving.slides then slid else swapped) * moving.rest
			end
		end
		smear.gun.Parent = camera
		if smear.arms and whole.bones and from.bones and clips then
			-- Hands a coded reload has moved trail from where they were, like the gun.
			local palms: { [string]: CFrame }? = nil
			if whole.palms then
				local between = {}
				for side, palm in whole.palms do
					local was = from.palms and from.palms[side] or palm
					between[side] = was:Lerp(palm, smear.share)
				end
				palms = between
			end
			ViewArms.poseGhost(
				smear.arms,
				clips.meshOffset,
				ArmClip.blendBones(from.bones, whole.bones, smear.share),
				palms
			)
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

local idleLife = math.random() * 100 -- where the gun is in its idle wander
local idleSize = 1 -- how much of that wander shows
local winded = 0

-- Moves the idle wander on, and works out how much of it shows.
local function idle(dt: number, aiming: boolean, running: boolean)
	winded = math.clamp(winded + (if running then WINDED_GAIN else -WINDED_FADE) * dt, 0, 1)
	idleLife += dt * (1 + (WINDED_SPEED - 1) * winded)
	idleSize = (1 + (WINDED_SIZE - 1) * winded)
		* (1 - (1 - BREATH_MOVING) * math.min(bobWeight, 1))
		* (if aiming then BREATH_AIMED else 1)
end

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
	-- No steps while sliding: the player glides, so the gun mustn't bob as if running.
	local sliding = Players.LocalPlayer:GetAttribute("MoveMode") == "Slide"
	if root and humanoid and humanoid.FloorMaterial ~= Enum.Material.Air and not sliding then
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
	local gunName = if shownGun then GunConfig.guns[shownGun].name else ""
	local bob = CFrame.new(side * BOB_SIDE * bobWeight, -dip * BOB_HEIGHT * bobWeight * (BOB_DIPS[gunName] or 1), 0)
		* CFrame.Angles(
			math.rad(-dip * BOB_NOD * bobWeight),
			math.rad(side * BOB_ROLL * 0.6 * bobWeight),
			math.rad(side * BOB_ROLL * bobWeight)
		)
	bob = CFrame.identity:Lerp(SPRINT_HOLDS[gunName] or SPRINT_HOLD, sprintWeight) * bob

	idle(dt, aiming, running)
	return CFrame.new(swayAngles.Y * SWAY_MOVE, swayAngles.X * SWAY_MOVE, 0)
		* CFrame.Angles(swayAngles.X, swayAngles.Y, swayAngles.Y * 0.6)
		* bob
end

-- Muzzle flashes, by gun name: how big, in studs on screen, and how long they show.
local FLASHES: { [string]: { size: number, time: number } } = {
	M57 = { size = 0.55, time = 0.045 },
	Longscope = { size = 1.3, time = 0.07 },
}
local FLASH_COLOR = Color3.fromRGB(150, 255, 255) -- Data Cyan, washed toward white, like the tracers
local flashModel: Model? = nil
local flashParts: { BasePart } = {}
local flashLight: PointLight? = nil
local flashShownAt = -math.huge
local flashRoll = 0
local flashScale = 1

-- A bright core and three petals round the barrel.
local function makeFlash(): Model
	local model = Instance.new("Model")
	model.Name = "MuzzleFlash"
	local function part(shape: Enum.PartType, transparency: number): Part
		local piece = Instance.new("Part")
		piece.Anchored = true
		piece.CanCollide = false
		piece.CanQuery = false
		piece.CanTouch = false
		piece.CastShadow = false
		piece.Material = Enum.Material.Neon
		piece.Color = FLASH_COLOR
		piece.Shape = shape
		piece.Transparency = transparency
		piece.Parent = model
		table.insert(flashParts, piece)
		return piece
	end
	part(Enum.PartType.Ball, 0.25).Color = Color3.new(1, 1, 1)
	for _ = 1, 3 do
		part(Enum.PartType.Block, 0.4)
	end
	part(Enum.PartType.Ball, 0.8) -- a soft glow round it all
	local light = Instance.new("PointLight")
	light.Color = FLASH_COLOR
	light.Range = 4 -- just the arms and gun, not the room
	light.Shadows = false
	light.Parent = flashParts[1]
	flashLight = light
	return model
end

-- Places the flash at the muzzle, or hides it once its time is up.
local function showFlash(camera: Camera, muzzle: CFrame)
	local config = if shownGun then GunConfig.guns[shownGun] else nil
	local style = config and FLASHES[config.name]
	local t = if style then (os.clock() - flashShownAt) / style.time else 1
	if not style or t >= 1 then
		if flashModel then
			flashModel.Parent = nil
		end
		return
	end
	flashModel = flashModel or makeFlash()
	local size = style.size * flashScale * (1 - 0.4 * t)
	local at = muzzle * CFrame.Angles(0, 0, flashRoll)
	local core, glow = flashParts[1], flashParts[5]
	core.Size = Vector3.one * size * 0.35
	core.CFrame = at * CFrame.new(0, 0, -size * 0.12)
	for petal = 2, 4 do
		local piece = flashParts[petal]
		piece.Size = Vector3.new(size * 0.09, size * 0.35, size)
		piece.CFrame = at * CFrame.Angles(0, 0, math.rad(60 * petal)) * CFrame.new(0, 0, -size * 0.45)
	end
	glow.Size = Vector3.one * size * 0.8
	glow.CFrame = at * CFrame.new(0, 0, -size * 0.25)
	if flashLight then
		flashLight.Brightness = 0.8 * (1 - t) -- soft: rapid fire mustn't strobe
	end
	flashModel.Parent = camera
end

-- Holds that sat too close to the eye: the whole gun and arms move out by this much, so they look as far off as the
-- Longscope's.
local VIEW_REACH: { [string]: CFrame } = {
	["Energy Pistol"] = CFrame.new(0.04, -0.02, -0.3),
}

local GunView = {}

local function grips(): (any, any)
	if isSidearm then
		return SIDEARM_RIGHT, SIDEARM_LEFT
	end
	local right = { wrist = Vector3.new(PRIMARY_RIGHT.x * viewScale, PRIMARY_RIGHT.y * viewScale, length * RIGHT_GRIP_Z) }
	right.along, right.thumb = PRIMARY_RIGHT.along, PRIMARY_RIGHT.thumb
	local left = { wrist = Vector3.new(PRIMARY_LEFT.x * viewScale, PRIMARY_LEFT.y * viewScale, length * leftGrip) }
	left.along, left.thumb = PRIMARY_LEFT.along, PRIMARY_LEFT.thumb
	if gripShift then
		right.wrist += gripShift.right
		left.wrist += gripShift.left
	end
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
	layerAt = nil
	viewScale = VIEW_SCALES[GunConfig.guns[gunId].name] or 1
	leftGrip = LEFT_GRIPS[GunConfig.guns[gunId].name] or LEFT_GRIP_Z
	gripShift = GRIP_SHIFTS[GunConfig.guns[gunId].name]
	length = if isSidearm then SIDEARM_LENGTH else PRIMARY_LENGTH
	barrelRise = 0
	modelShift = Vector3.zero
	view = makeModel(GunConfig.guns[gunId].name) or makeBlock()
	lever = nil
	table.clear(leverParts)
	codeReload, codeReloadAt, codeReloading, codePose = nil, nil, false, nil
	codeTurn, spareShown, smearFrame = CFrame.identity, false, nil
	table.clear(codeParts)
	table.clear(spareParts)
	local coded = CODE_RELOADS[GunConfig.guns[gunId].name]
	if coded and view:IsA("Model") then
		local perMetre = coded.perMetre * MODEL_SCALE * viewScale
		local middle = coded.middle
		codeReload = {
			reload = coded.reload,
			perMetre = perMetre,
			-- Where the handoff's origin is from the spot the model turns about.
			origin = modelShift + Vector3.new(middle.Y, -middle.Z, middle.X) * perMetre,
		}
		local pivot = view:GetPivot()
		for _, part in view:GetDescendants() do
			local swaps, slides = part.Name:find("^Mag_") ~= nil, part.Name:find("^Bolt_") ~= nil
			if part:IsA("BasePart") and (swaps or slides) then
				table.insert(codeParts, { part = part, rest = pivot:ToObjectSpace(part.CFrame), slides = slides })
			end
		end
		for _, moving in table.clone(codeParts) do
			if not moving.slides then
				local copy = moving.part:Clone()
				copy.Name = "Spare"
				copy.Transparency = 1
				copy.Parent = view
				table.insert(spareParts, { part = copy, rest = moving.rest })
			end
		end
	end
	local levered = LEVERS[GunConfig.guns[gunId].name]
	if levered and view:IsA("Model") then
		local scale = MODEL_SCALE * viewScale
		lever = { pivot = levered.pivot * scale, swing = levered.swing, slide = levered.slide * scale }
		local middle = view:GetPivot()
		for _, part in view:GetDescendants() do
			local swings, slides = part.Name:find("^Lever_") ~= nil, part.Name:find("^Bolt_") ~= nil
			if part:IsA("BasePart") and (swings or slides) then
				table.insert(leverParts, { part = part, rest = middle:ToObjectSpace(part.CFrame), slides = slides })
			end
		end
	end
	-- The hold that puts the sight's back end straight in front of the eye.
	scopeAim = nil
	local scope = SCOPES[GunConfig.guns[gunId].name]
	local glass = scope and view:FindFirstChild(scope.part, true)
	if scope and glass and glass:IsA("BasePart") then
		local sight = view:GetPivot():ToObjectSpace(glass.CFrame)
		local back = sight.Position + Vector3.new(0, 0, glass.Size.Z / 2)
		local forward = CFrame.new(0, 0, -length * (1 - 1 / viewScale) / 2)
		scopeAim = CFrame.new(-back.X, -back.Y, -scope.eye - back.Z) * forward:Inverse()
	end
	clips = ArmClips[GunConfig.guns[gunId].name]
	firedAt = nil
	keyedReloadAt = nil
	reloadAt = nil
	-- Swapping guns has no animation: the new gun is just there, in its hold, with nothing blending in.
	snapAt = nil
	shownFrame = nil
	shownBase = nil
	shownSnap = nil
	blendFrom = nil
	shownKind = nil
	held = HIP
	kick, kickSpeed = 0, 0
	settle, settleSpeed, settleGoal = 0, 0, 0
	layerAt = nil
	layerShown = CFrame.identity
	reloadShown, handShown = CFrame.identity, Vector3.zero
	removeSmears()
	table.clear(history) -- or the motion blur would streak from the old gun's spot
end

-- Snaps the fingers of the free hand, on guns that leave one free. True if it snapped.
function GunView.snap(): boolean
	if clips and clips.snap then
		snapAt = os.clock()
		return true
	end
	return false
end

-- Where bullets leave the gun on screen, or nil while it's hidden.
function GunView.muzzle(): Vector3?
	if not view or not view.Parent then
		return nil
	end
	return view:GetPivot() * (modelShift + Vector3.new(0, barrelRise, -length / 2))
end

function GunView.kick()
	local config = if shownGun then GunConfig.guns[shownGun] else nil
	local viewKick = (config and VIEW_KICKS[config.name]) or DEFAULT_KICK
	if viewKick.settle then
		settleGoal = math.min(settleGoal + viewKick.settle.perShot, 1)
	end
	if viewKick.auto then
		kickSpeed += AUTO_SHOVE * math.sqrt(viewKick.stiff)
		kickRoll = if math.random() < 0.5 then -1 else 1
	else
		kick = 0
		kickSpeed = 0
		kickRoll = if viewKick.sides and math.random() < 0.5 then -1 else 1
	end
	shot = Loosen.shot(math.random)
	if viewKick.loose then
		-- Further from the usual shot, by that many times.
		local loose = viewKick.loose
		shot = {
			up = 1 + (shot.up - 1) * loose,
			back = 1 + (shot.back - 1) * loose,
			roll = 1 + (shot.roll - 1) * loose,
			yaw = shot.yaw * loose,
			speed = shot.speed,
		}
	end
	firedAt = os.clock()
	flashShownAt = firedAt
	flashRoll = math.random() * math.pi * 2
	flashScale = 0.85 + math.random() * 0.3
	-- A gun that reloads after every shot starts its reload's keys now, and they carry the kick.
	local keyed = config and RELOADS[config.name]
	if keyed and keyed.lead and config.autoReload and not clips then
		keyedReloadAt = firedAt
	end
end

-- The frame to show. Reloading beats everything, then a shot, then idle. Nothing plays for putting the gun away or
-- bringing it back: those are to be reworked.
local function clipFrame(reloading: boolean, sprinting: boolean): (any, string)
	if reloading and not reloadAt then
		reloadClip = ArmClip.pickReload(clips, math.random())
	end
	reloadAt = if reloading then reloadAt or os.clock() else nil
	-- A reload keyed in code plays over the idle clip, not the old reload clip.
	if reloadAt and not codeReload then
		local elapsed = os.clock() - reloadAt
		local sync = RELOAD_SYNC[GunConfig.guns[shownGun :: string].name]
		if sync and elapsed < sync[#sync][1] then
			for index = 2, #sync do
				local from, to = sync[index - 1], sync[index]
				if elapsed < to[1] then
					elapsed = from[2] + (elapsed - from[1]) / (to[1] - from[1]) * (to[2] - from[2])
					break
				end
			end
		end
		elapsed = Loosen.tempo(elapsed, #reloadClip.frames / reloadClip.fps, looseLife + os.clock())
		local frame = ArmClip.sampleAt(reloadClip, elapsed)
		if frame then
			return frame, "reload"
		end
	end
	if firedAt then
		local frame = ArmClip.sampleAt(clips.fire, (os.clock() - firedAt) * shot.speed)
		if frame then
			return frame, "fire"
		end
		firedAt = nil
	end
	-- Sprinting holds the idle clip and lets the code bob carry it, the same as the Longscope, instead of the
	-- Blender run clip.
	return ArmClip.sampleAt(clips.idle, os.clock()), "idle"
end

-- The snap frame to lay over the clip, if one is playing.
-- The snap plays a little slower than exported, and eases on and off the hand instead of popping.
local SNAP_SPEED = 0.8
local SNAP_EASE_IN = 0.1
local SNAP_EASE_OUT = 0.16

-- The snap's pose, and how much of it shows (0 to 1).
local function snapFrame(): (any, number)
	if not snapAt then
		return nil, 0
	end
	local elapsed = (os.clock() - snapAt) * SNAP_SPEED
	local length = (#clips.snap.frames - 1) / clips.snap.fps
	local frame = ArmClip.sampleAt(clips.snap, math.min(elapsed, length))
	local after = elapsed - length
	if not frame or after > SNAP_EASE_OUT then
		snapAt = nil
		return nil, 0
	end
	local weight = math.clamp(elapsed / SNAP_EASE_IN, 0, 1)
	if after > 0 then
		weight = 1 - after / SNAP_EASE_OUT
	end
	return frame, weight * weight * (3 - 2 * weight)
end

-- With a card out, the gun is gone at once and the hands play the deck flourish and hold the deck. Using the card
-- crushes it in the right hand, and then the gun is back at once.
-- Returns true while the card has the screen.
local function showCard(camera: Camera, cardOut: boolean, cardSway: CFrame): boolean
	local now = os.clock()
	if cardOut and crushAt then
		cardAt, crushAt = nil, nil -- another card came out mid-crush
	end
	if not cardOut then
		if not cardAt then
			return false
		end
		if not crushAt and CardInHand.used ~= cardUsed then
			crushAt = now
			GunAudio.playCardCrush()
		end
		if not crushAt or now - crushAt >= CardFlourish.CRUSH then
			cardAt, crushAt = nil, nil
			GunAudio.stopCards()
			shownFrame, shownBase, shownSnap = nil, nil, nil
			smearFrame = nil
			CardView.hide()
			ViewArms.clearBlur()
			return false
		end
	end
	if not cardAt then
		cardAt = now
		GunAudio.playCards()
		cardUsed = CardInHand.used
		cardTurns, turns = CardInHand.turns, 0
		cardLife = math.random() * 100
	end
	local elapsed = (crushAt or now) - (cardAt :: number)
	if CardInHand.turns ~= cardTurns then
		cardTurns = CardInHand.turns
		-- Turning to another card skips what's left of the flourish and flips the next one over.
		turns += 1
		turnAt = now
		GunAudio.playCardSkip() -- on every turn, whether or not it cuts the flourish short
		if elapsed < CardFlourish.LENGTH then
			cardAt = now - CardFlourish.LENGTH
			CardView.snap()
			elapsed = CardFlourish.LENGTH
		end
	end
	if view and view.Parent then
		view.Parent = nil
		hideSmears()
		table.clear(history)
	end
	local held = camera.CFrame * cardSway
	local crush = if crushAt then CardFlourish.crush(elapsed, now - crushAt, turns) else nil
	local pose = if crush
		then crush.pose
		elseif turns > 0 then CardFlourish.turn(turns, now - turnAt)
		else CardFlourish.at(CardFlourish.tempo(elapsed, cardLife + now))
	local rightMoved
	pose, rightMoved = CardFlourish.sway(pose, cardLife + now)
	if crush then
		crush.palm = rightMoved * crush.palm
	end
	ViewArms.holdCards(pose.right, pose.left, pose.fingers)
	CardView.show(camera, held, pose.cards, crush, CardFlourish.top(turns), if crush then nil else pose.bends)
	ViewArms.place(camera, held)
	ViewArms.blur(camera, held)
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
	local goal = if aiming then scopeAim or AIMED else HIP
	local keyedReload = if shownGun then RELOADS[GunConfig.guns[shownGun].name] else nil
	local shotKeyed = keyedReload ~= nil and keyedReload.lead ~= nil
	if reloading and not clips and (not keyedReload or (shotKeyed and not keyedReloadAt)) then
		goal *= RELOAD_DIP
	end
	local config = if shownGun then GunConfig.guns[shownGun] else nil
	local viewKick = (config and VIEW_KICKS[config.name]) or DEFAULT_KICK
	local ease = 1 - math.exp(-dt * (if config and config.aimFov then (if aiming then SCOPE_IN_EASE else AIM_EASE) else EASE))
	held = held:Lerp(goal, ease)
	if scopeAim then
		local whole = (HIP.Position - scopeAim.Position).Magnitude
		scopeShare = math.clamp(1 - (held.Position - scopeAim.Position).Magnitude / whole, 0, 1)
	else
		scopeShare = 0
	end
	showScope(if clips then 0 else scopeShare)
	local keyedKick = keyedReloadAt ~= nil and keyedReload ~= nil and keyedReload.lead ~= nil
	local rising = viewKick.rise and firedAt and os.clock() - firedAt < viewKick.rise and not keyedKick
	if rising then
		local u = (os.clock() - (firedAt :: number)) / viewKick.rise
		kick = 1 - (1 - u) ^ 3
		kickSpeed = 0
	else
		local step = math.min(dt, 1 / 30)
		kickSpeed += (-kick * viewKick.stiff - kickSpeed * viewKick.damp) * step
		kick += kickSpeed * step
	end
	if keyedKick then
		kick, kickSpeed = 0, 0 -- the reload's keys carry this shot's kick
	end
	-- No two shots kick quite alike: each climbs, shoves, rolls and twists a little more or less.
	local climb = viewKick.up * shot.up * kick
	local recoil = CFrame.new(0, -viewKick.drop * kick, viewKick.back * shot.back * kick)
		* CFrame.Angles(
			math.rad(climb),
			math.rad(climb * shot.yaw + (viewKick.left or 0) * kick),
			math.rad(viewKick.roll * shot.roll * kickRoll * kick)
		)
	local slow = viewKick.settle
	if slow and config then
		-- Still spraying while the next shot is due; a beat after that the gun starts home.
		if not firedAt or os.clock() - firedAt > 60 / config.rpm * 1.6 then
			settleGoal = 0
		end
		local step = math.min(dt, 1 / 30)
		settleSpeed += ((settleGoal - settle) * slow.stiff - settleSpeed * slow.damp) * step
		settle += settleSpeed * step
		recoil = CFrame.new(0, -slow.drop * settle, slow.back * settle) * CFrame.Angles(math.rad(slow.up * settle), 0, 0) * recoil
	else
		settle, settleSpeed, settleGoal = 0, 0, 0
	end
	local sway = swayAndBob(dt, camera, aiming, sprinting)
	-- A gun with clips kicks the whole view, so the arms holding it go too, and its reload layer turns it round
	-- the gun's hold.
	local layer = CFrame.identity
	if clips and keyedReload and keyedReload.layer and config then
		if reloading and not layerAt then
			layerAt = os.clock()
		end
		local elapsed = if layerAt then os.clock() - layerAt else math.huge
		local layerLength = keyedReload.keys[#keyedReload.keys].at * config.reload / keyedReload.length
		if elapsed < layerLength then
			local turnBy = reloadPose(keyedReload, elapsed, config.reload)
			layer = CFrame.new(HIP.Position) * turnBy * CFrame.new(-HIP.Position)
		elseif not reloading then
			layerAt = nil
		end
	else
		layerAt = nil
	end
	-- A touch of smoothing, so a corner between two keys never shows as a step.
	layerShown = layerShown:Lerp(layer, 1 - math.exp(-dt * 30))
	local reach = (config and VIEW_REACH[config.name]) or CFrame.identity
	-- The hold always drifts a little, and in full through a reload, which never goes quite the same way twice.
	local playing = reloadAt ~= nil or keyedReloadAt ~= nil
	if playing and not loosePlaying then
		looseLife = math.random() * 100
	end
	loosePlaying = playing
	looseShare += ((if playing then 1 else 0) - looseShare) * (1 - math.exp(-dt * LOOSE_EASE))
	local loose = Loosen.drift(HIP.Position, idleLife, idleSize + (1 - math.min(idleSize, 1)) * looseShare)
	-- Tucked in when there's a wall in the way.
	local tucked = tuck(camera, dt, if cardOut then CARD_REACH else WALL_REACH)
	local tip = CFrame.new(0, -WALL_DROP * tucked, WALL_BACK * tucked)
		* CFrame.new(HIP.Position)
		* CFrame.Angles(WALL_PITCH * tucked, 0, 0)
		* CFrame.new(-HIP.Position)
	local base = camera.CFrame * reach * tip * sway * loose * (if clips then recoil * layerShown else CFrame.identity)
	if showCard(camera, cardOut, CFrame.new(0, -CARD_DROP * tucked, CARD_BACK * tucked) * sway) then
		if flashModel then
			flashModel.Parent = nil
		end
		return
	end
	if clips then
		local frame, kind = clipFrame(reloading, sprinting)
		if kind ~= shownKind then
			-- A shot or swap starts at once, unless the gun is still settling from the last clip: then it blends
			-- in quickly from where the gun is, so it can't jump.
			local settling = blendFrom ~= nil
			blendFrom = if shownBase and (not SNAPPY[kind] or settling) then shownBase else nil
			blendLength = if SNAPPY[kind] then SNAP_BLEND elseif shownKind == "reload" then RELOAD_BLEND else CLIP_BLEND
			blendAt = os.clock()
			shownKind = kind
		end
		if blendFrom then
			local t = (os.clock() - blendAt) / blendLength
			if t >= 1 then
				blendFrom = nil
			else
				frame = ArmClip.blendFrames(blendFrom, frame, t * t * (3 - 2 * t))
			end
		end
		local snap, snapWeight = snapFrame()
		if snap and snapWeight < 1 then
			-- Only the snapping hand's bones, part of the way from where the clip has them.
			local partBones = {}
			for name in snap.bones do
				partBones[name] = frame.bones[name] or snap.bones[name]
			end
			snap = { gun = snap.gun, bones = ArmClip.blendBones(partBones, snap.bones, snapWeight) }
		end
		local whole = if snap then ArmClip.overlay(frame, snap) else frame
		shownFrame, shownBase, shownSnap = whole, frame, snap
		local nudged = config and CLIP_NUDGES[config.name]
		local moved: { [string]: CFrame }? = nil
		local viewKick = config and VIEW_KICKS[config.name]
		local stillLeft = viewKick ~= nil and viewKick.stillLeft == true
		local palms = if nudged or codeReload or stillLeft or (viewKick ~= nil and viewKick.wrist ~= nil)
			then SoldierPose.clipPalms(clips.meshOffset, whole.bones)
			else nil
		if nudged and palms then
			local nudgedPalms = {}
			for side, by in nudged do
				nudgedPalms[side] = whole.gun * CFrame.new(by) * whole.gun:Inverse() * palms[side]
			end
			moved = nudgedPalms
		end
		-- A kick that breaks at the wrist: the gun and the hand on it flip up about the wrist, more than the arm does.
		wristFlip = CFrame.identity
		if viewKick and viewKick.wrist and palms then
			local placed = moved or {}
			local hand = placed.Right or palms.Right
			local snap = viewKick.wrist * kick
			wristFlip = CFrame.new(hand.Position)
				* CFrame.Angles(math.rad(snap * shot.up), math.rad(snap * 0.3), 0)
				* CFrame.new(-hand.Position)
			placed.Right = wristFlip * hand
			moved = placed
		end
		if stillLeft and palms then
			-- The whole view kicks with the shot, so the left hand is moved back by as much to stay put.
			local placed = moved or {}
			placed.Left = layerShown:Inverse() * recoil:Inverse() * layerShown * (placed.Left or palms.Left)
			moved = placed
		end
		-- A reload keyed in code takes the left hand off wherever the clip has it.
		codePose, codeTurn = nil, CFrame.identity
		if codeReload and config and palms then
			if reloading and not codeReloading then
				codeReloadAt = os.clock()
			end
			codeReloading = reloading
			local reload = codeReload.reload
			local at = if codeReloadAt then (os.clock() - codeReloadAt) * reload.SOUND / config.reload else math.huge
			if at >= reload.LENGTH or (not reloading and at < reload.SOUND * 0.95) then
				codeReloadAt = nil -- done, or cut short
			else
				local pose = reload.at(at)
				local per, origin = codeReload.perMetre, codeReload.origin
				codePose = pose
				-- The gun turns in the right hand, which goes round with it, and so does the left hand's rest.
				codeTurn = CFrame.new(origin + pose.gun.Position * per) * pose.gun.Rotation * CFrame.new(-origin)
				local turned = whole.gun * codeTurn * whole.gun:Inverse()
				local placed = moved or {}
				placed.Right = turned * (placed.Right or palms.Right)
				local rest = turned * (placed.Left or palms.Left)
				local onGun = whole.gun * CFrame.new(origin + pose.palm.Position * per) * pose.palm.Rotation
				placed.Left = rest:Lerp(onGun, pose.weight)
				if pose.rightWeight > 0 then
					-- The right hand comes off the grip.
					local away = whole.gun * CFrame.new(origin + pose.right.Position * per) * pose.right.Rotation
					placed.Right = placed.Right:Lerp(away, pose.rightWeight)
						+ whole.gun.Rotation * (pose.rightSwing * per)
				end
				moved = placed
			end
		end
		clipPalms = moved
		-- Fingers with their own shape go with the gun, unless the hand has come off it.
		local shaped = config and CLIP_FINGERS[config.name]
		local fingers: { [string]: { [string]: { Vector3 } } }? = nil
		if shaped and not (codePose and codePose.rightWeight > 0.5) then
			local turn = (whole.gun * codeTurn).Rotation
			local turnedFingers = {}
			for side, digits in shaped do
				turnedFingers[side] = {}
				for digit, aims in digits do
					local turnedAims = table.create(#aims)
					for joint, aim in aims do
						turnedAims[joint] = turn * aim
					end
					turnedFingers[side][digit] = turnedAims
				end
			end
			fingers = turnedFingers
		end
		-- And digits shaped by their own palm, which is wherever the hand is: resting on the gun, or holding
		-- something in a coded reload.
		local palmShaped = config and PALM_FINGERS[config.name]
		if palmShaped and palms then
			local shapedFingers = fingers or {}
			local holding = if codePose then codePose.weight else 0
			for side, digits in palmShaped do
				local palm = (clipPalms and clipPalms[side] or palms[side]).Rotation
				shapedFingers[side] = shapedFingers[side] or {}
				for digit, shapes in digits do
					local aims = table.create(#shapes.rest)
					for joint, rest in shapes.rest do
						aims[joint] = palm * rest:Lerp(shapes.held[joint], holding).Unit
					end
					shapedFingers[side][digit] = aims
				end
			end
			fingers = shapedFingers
		end
		ViewArms.showFrame(clips.meshOffset, whole.bones, clipPalms, fingers)
		-- Reloading and scoping still move the whole hold, on top of the clip.
		shown = held * HIP:Inverse() * wristFlip * frame.gun * codeTurn
		-- What the blur trails: the clip's pose with a coded reload's turn of the gun and its moved hands.
		smearFrame = { gun = wristFlip * whole.gun * codeTurn, bones = whole.bones, palms = clipPalms }
		if codeReload then
			-- Where the magazine and bolt are in the gun, so the blur's copies can put theirs there too.
			local per, origin = codeReload.perMetre, codeReload.origin
			local mag = if codePose then codePose.mag else CFrame.identity
			smearFrame.mag = CFrame.new(origin + mag.Position * per) * mag.Rotation * CFrame.new(-origin)
			smearFrame.bolt = if codePose then codePose.bolt * per else 0
		end
	else
		local now = os.clock()
		-- A gun drawn bigger moves forward by its extra length, so its stock stays clear of the camera.
		local forward = CFrame.new(0, 0, -length * (1 - 1 / viewScale) / 2)
		local reloadGun, reloadHand, spin = CFrame.identity, Vector3.zero, 0
		leverOpen = 0
		-- A keyed reload plays to its last key, even if the reload ends first.
		if keyedReloadAt and keyedReload and config and not reloading then
			local lead = keyedReload.lead or 0
			local last = lead + (keyedReload.keys[#keyedReload.keys].at - lead) * config.reload / keyedReload.length
			if now - keyedReloadAt >= last then
				keyedReloadAt = nil
			end
		elseif not keyedReload then
			keyedReloadAt = nil
		end
		-- A reload keyed from the shot (the Longscope's flip) only plays after a shot, not when the gun comes out
		-- empty and reloads.
		if reloading and keyedReload and not keyedReload.lead and not keyedReloadAt then
			keyedReloadAt = now
		end
		if keyedReloadAt and keyedReload and config then
			local lead = keyedReload.lead or 0
			local last = lead + (keyedReload.keys[#keyedReload.keys].at - lead) * config.reload / keyedReload.length
			local at = Loosen.tempo(now - keyedReloadAt, last, looseLife + now)
			reloadGun, reloadHand, spin, leverOpen = reloadPose(keyedReload, at, config.reload)
			-- A touch of smoothing on the way back to ready, so a corner between two keys never shows as a step. The
			-- clicks before that stay sharp.
			local smooth = if now - keyedReloadAt >= (keyedReload.smoothFrom or 0) then 1 - math.exp(-dt * 25) else 1
			reloadShown = reloadShown:Lerp(reloadGun, smooth)
			handShown = handShown:Lerp(reloadHand, smooth)
			reloadGun, reloadHand = reloadShown, handShown
		else
			reloadShown, handShown = CFrame.identity, Vector3.zero
		end
		local right, left = grips()
		-- The hands go by the gun before its spin: the right stays put with its finger in the trigger guard while the
		-- gun spins round it, and the left lets go and catches it.
		local hand = held * forward * recoil * reloadGun * (turn or CFrame.identity)
		-- The spin turns round the trigger guard, just ahead of the hand on the grip.
		local pivot = right.wrist - (if gripShift then gripShift.right else Vector3.zero)
		shown = held * forward * recoil * reloadGun
			* CFrame.new(pivot) * CFrame.Angles(spin, 0, 0) * CFrame.new(-pivot)
			* (turn or CFrame.identity)
		if reloadHand ~= Vector3.zero then
			left = table.clone(left)
			left.wrist += reloadHand
		end
		if lever and leverOpen > 0 then
			-- The right hand is in the lever's loop and rides it round.
			local hinge = CFrame.Angles(lever.swing * leverOpen, 0, 0)
			right = {
				wrist = lever.pivot + hinge * (right.wrist - lever.pivot),
				along = hinge * right.along,
				thumb = hinge * right.thumb,
			}
		end
		ViewArms.pose(shown, right, left, config and SHOULDERS[config.name], config and THUMB_WRAPS[config.name], hand, hand)
	end
	view:PivotTo(base * shown)
	if lever and leverOpen > 0 then
		local middle = base * shown
		local swung = middle * CFrame.new(lever.pivot) * CFrame.Angles(lever.swing * leverOpen, 0, 0) * CFrame.new(-lever.pivot)
		local slid = middle * CFrame.new(0, 0, lever.slide * leverOpen)
		for _, moving in leverParts do
			moving.part.CFrame = (if moving.slides then slid else swung) * moving.rest
		end
	end
	if codeReload and codePose and clips then
		-- The magazine goes with the hand and the bolt carrier slides back, from where the gun's turn left them.
		local pose, per, origin = codePose, codeReload.perMetre, codeReload.origin
		local middle = base * shown
		local swapped = middle * CFrame.new(origin + pose.mag.Position * per) * pose.mag.Rotation * CFrame.new(-origin)
		local slid = middle * CFrame.new(0, 0, pose.bolt * per)
		for _, moving in codeParts do
			moving.part.CFrame = (if moving.slides then slid else swapped) * moving.rest
		end
		local spare = pose.spare
		if spare then
			local second = middle * CFrame.new(origin + spare.Position * per) * spare.Rotation * CFrame.new(-origin)
			for _, moving in spareParts do
				moving.part.CFrame = second * moving.rest
			end
		end
	end
	if spareShown ~= (codePose ~= nil and codePose.spare ~= nil) then
		spareShown = not spareShown
		for _, moving in spareParts do
			moving.part.Transparency = if spareShown then 0 else 1
		end
	end
	view.Parent = camera
	local pivot = view:GetPivot()
	showFlash(camera, pivot * CFrame.new(modelShift + Vector3.new(0, barrelRise, -length / 2)))
	ViewArms.place(camera, base)
	if not clips and scopeShare >= SCOPE_SHOW_FROM then
		-- Looking through the scope: the gun and arms would only block it.
		view.Parent = nil
		ViewArms.hide()
		hideSmears()
		if flashModel then
			flashModel.Parent = nil
		end
		return
	end
	if clips and smearFrame then
		drawSmear(camera, smearFrame, base, base * held * HIP:Inverse())
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
	ViewArms.clearBlur()
	ViewArms.hide()
	showScope(0)
	if flashModel then
		flashModel.Parent = nil
	end
end

return GunView
