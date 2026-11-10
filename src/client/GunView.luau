-- The gun held in view, with the arms holding it. Uses the model in ReplicatedStorage.GunModels named after the gun,
local Palette = require(game:GetService("ReplicatedStorage"):WaitForChild("Guns"):WaitForChild("Palette"))
-- or a grey block if that model hasn't been imported.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmClip = require(ReplicatedStorage.Guns.ArmClip)
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
local VIEW_SCALES: { [string]: number } = { Longscope = 1.35 }
-- Where the left hand holds a gun, as a share of its length from the middle, where the usual spot is out of reach.
-- Too far forward and the arm locks straight with the shoulder sliding into view.
local LEFT_GRIPS: { [string]: number } = { Longscope = 0 }
local leftGrip = LEFT_GRIP_Z
-- Where a gun's own shape needs the hands moved, in studs. The Longscope's pistol grip sits behind its trigger,
-- further back and lower than the usual hold, and its fore-end is shallow, so the left hand comes up to meet it.
local GRIP_SHIFTS: { [string]: { right: Vector3, left: Vector3 } } = {
	Longscope = { right = Vector3.new(0, -0.09, 0.56), left = Vector3.new(0, 0.08, 0) },
}
local gripShift: { right: Vector3, left: Vector3 }? = nil
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
-- Guns that sank too low sprinting: their own lean, and how much of the footstep dip they take.
local SPRINT_HOLDS: { [string]: CFrame } = {
	["Energy Pistol"] = CFrame.new(0.02, -0.02, 0.03) * CFrame.Angles(math.rad(-2), math.rad(3), math.rad(2)),
	M57 = CFrame.new(0.03, -0.03, 0.05) * CFrame.Angles(math.rad(-3), math.rad(4), math.rad(3)),
}
local BOB_DIPS: { [string]: number } = { ["Energy Pistol"] = 0.5, M57 = 0.7 }
local EASE = 11
-- Breathing: standing still, the gun rises and settles with the chest and the hands drift a little. Running
-- leaves the player winded, so the breaths come bigger and quicker for a few seconds after.
local BREATH_SECONDS = 3.8 -- one breath at rest
local BREATH_LIFT = 0.014 -- studs the gun rises on the in-breath
local BREATH_BACK = 0.006 -- and how far it draws in toward the chest
local BREATH_PITCH = 0.4 -- degrees the muzzle tips up
local BREATH_ROLL = 0.3
local DRIFT_TURN = 0.22 -- degrees the hands wander, slower than the breath
local DRIFT_MOVE = 0.004
local BREATH_MOVING = 0.3 -- the share left while walking, where the bob takes over
local BREATH_AIMED = 0.35
local WINDED_SIZE = 1.9 -- how much bigger, and
local WINDED_SPEED = 1.5 -- how much quicker, the breaths are right after a sprint
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
	M57 = {
		back = 0.066, drop = 0.011, up = 1.5, roll = 0.9, stiff = 315, damp = 27.8, auto = true,
		-- A slower layer under the shot kicks: each shot pushes it further (up to 1), and once firing stops it
		-- eases home on its own soft spring, so the gun takes its time getting back to its shooting position.
		settle = { back = 0.08, drop = 0.035, up = 2.4, perShot = 0.3, stiff = 28, damp = 10.5 },
	},
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
	-- reload-assault-v4.wav: a rattle from 0.09s, the mag clicks out at 0.42s, slams in at 0.64s, and the charge is
	-- pulled at 0.86s and lets go at 0.93s. The M57 has a reload clip, so this layers on top of it: the whole hold,
	-- arms and all, turns round the gun with a jolt on each hit. Only the gun's turn is used.
	M57 = {
		length = 0.985,
		layer = true,
		keys = {
			key(0, CFrame.identity, Vector3.zero),
			key(0.2, tilt(-3, 0, -4, 0, -0.05, 0), Vector3.zero), -- dips to wind up, taking its time
			key(0.34, tilt(14, -6, 4, -0.03, 0.02, 0), Vector3.zero), -- rolls the mag well toward the hand
			key(0.42, tilt(15, -6, 3, -0.03, 0.01, 0), Vector3.zero, "in"),
			key(0.46, tilt(17, -7, -3, -0.03, -0.05, 0), Vector3.zero, "out"), -- mag out: jolts down
			key(0.53, tilt(15, -6, 3, -0.03, 0.01, 0), Vector3.zero),
			key(0.6, tilt(16, -6, 1, -0.03, -0.03, 0), Vector3.zero), -- winds up for the new one
			key(0.64, tilt(15, -6, 2, -0.03, -0.01, 0), Vector3.zero, "in"),
			key(0.68, tilt(12, -5, 8, -0.03, 0.06, 0), Vector3.zero, "out"), -- mag in: bumps up hard
			key(0.77, tilt(15, -6, 3, -0.03, 0.01, 0), Vector3.zero),
			key(0.93, tilt(17, -7, 2, -0.04, 0, 0), Vector3.zero, "in"), -- the slap
			key(0.96, tilt(18, -7, -1, -0.045, -0.02, 0), Vector3.zero, "out"),
			key(0.985, tilt(17, -7, 1, -0.04, 0, 0), Vector3.zero, "in"),
			key(1.04, tilt(-6, 2.5, 4, 0.015, 0.04, 0), Vector3.zero, "out"), -- let go: heaves back up past ready
			-- then its weight takes over: it sinks past ready, hangs low a moment, and is lifted back up slowly
			key(1.24, tilt(-5, 2, 3.2, 0.012, 0.03, 0), Vector3.zero, "out"),
			key(1.62, tilt(-1, 0.5, -5, 0.004, -0.09, 0.02), Vector3.zero),
			key(1.86, tilt(0, 0.3, -5.5, 0.002, -0.1, 0.02), Vector3.zero),
			key(2.34, tilt(0.5, -0.1, 0.8, 0, 0.008, 0), Vector3.zero),
			key(2.7, CFrame.identity, Vector3.zero),
		},
	},
	-- gun-sniper-base.wav, from the shot: the blast, a rising click from 1s peaking at 1.04s, a clunk at 1.32s and a
	-- whirr to 1.6s. The gun spins once backwards round the trigger finger while the blast rings out, the left hand
	-- drives the cell home on the click, and pushes the gun back to ready through the clunk and whirr.
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
		smoothFrom = 1.31, -- seconds in: the return to ready gets a touch more smoothing on top
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
			key(0.68, tilt(9, -3, -8, -0.01, 0.25, 0.02), Vector3.new(0, -0.04, 0), "flow"), -- both hands drop with the weight straight away
			key(0.79, tilt(14, -5, 0, -0.04, 0.12, 0.03), Vector3.new(0, -0.2, 0.15), "flow"), -- then sinks back down
			-- CLICK: the gun tips to show the cell slot, the hand pulls back to load up, then drives the cell in on
			-- the sound and the gun bumps up off the hit and settles.
			key(0.86, tilt(18, -6, 2, -0.06, 0, 0.03), Vector3.new(0, -0.4, 0.32), "flow"),
			key(0.98, tilt(20, -6, -2, -0.06, -0.04, 0.02), Vector3.new(0, -0.42, 0.36), "flow"), -- holds there, loaded, sagging under the hand
			key(1.03, tilt(18, -6, 2, -0.06, 0, 0.03), Vector3.new(0.02, -0.02, 0.24), "in"), -- CLICK: drives the cell in
			key(1.08, tilt(12, -5, 15, -0.05, 0.17, 0.1), Vector3.new(0.02, 0.06, 0.24), "out"), -- and the hit shoves the gun up and back
			key(1.15, tilt(21, -7, -3, -0.07, -0.05, 0.02), Vector3.new(0.02, -0.03, 0.24)), -- drops back past
			key(1.22, tilt(20, -7, 1, -0.07, -0.01, 0.03), Vector3.new(0.02, -0.01, 0.24), "flow"),
			-- CLICK release: a small wind-up further into the tilt, then the left hand drives forward and pushes the gun
			-- with it as it eases back round to ready, and it settles.
			key(1.31, tilt(24, -8, -1, -0.08, -0.03, 0.05), Vector3.new(0.02, -0.02, 0.3), "flow"),
			key(1.5, tilt(3, -1, 3, -0.01, 0.04, -0.14), Vector3.new(0, 0, -0.06), "flow"), -- the hand shoves it forward as it turns back
			key(1.64, tilt(-1, 0.3, -0.5, 0.002, -0.006, 0.015), Vector3.zero, "flow"), -- and it rocks back a touch
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

-- A reload with a lead counts from the shot before it, and only the part after the lead stretches.
local function reloadPose(reload: any, elapsed: number, reloadTime: number): (CFrame, Vector3, number)
	local lead = reload.lead or 0
	local at = if elapsed < lead then elapsed else lead + (elapsed - lead) * reload.length / reloadTime
	local keys = reload.keys
	for index = 2, #keys do
		local to = keys[index]
		if at < to.at then
			local from = keys[index - 1]
			local u = (at - from.at) / (to.at - from.at)
			if to.ease == "flow" then
				return flowing(keys, index, u), flowHand(keys, index, u), spinAt(reload, at)
			end
			u = eased(to.ease, u)
			return from.gun:Lerp(to.gun, u), from.hand:Lerp(to.hand, u), spinAt(reload, at)
		end
	end
	return CFrame.identity, Vector3.zero, 0
end

-- Equipping a gun posed in code: it swings in from below and to the right.
local EQUIP_TIME = 0.45
local EQUIP_FROM = CFrame.new(0.6, -1.2, 0.3) * CFrame.Angles(math.rad(-40), math.rad(25), math.rad(-30))
-- Scoping in and out is quick on a gun that can scope.
local AIM_EASE = 24 -- lowering a scoped gun
local SCOPE_IN_EASE = 13 -- raising it to the eye, about a quarter of a second
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
local settle, settleSpeed, settleGoal = 0, 0, 0
local shown = HIP
local clips: any = nil
local firedAt: number? = nil
local reloadAt: number? = nil
local reloadClip: any = nil
local equipAt: number? = nil
local keyedReloadAt: number? = nil -- when a keyed reload started, or the shot that starts it
local layerAt: number? = nil -- when a clip gun's reload layer started; it plays to its end even if the reload ends first
local layerShown = CFrame.identity
local reloadShown, handShown = CFrame.identity, Vector3.zero -- a code-posed gun's reload, smoothed
local holsterAt: number? = nil
local snapAt: number? = nil
local cardAt: number? = nil
local cardUsed = 0 -- how many cards had been used when this one came out
local crushAt: number? = nil -- when the card in hand was used
local shownFrame: any = nil -- what's on screen, with any snap laid over it
local shownBase: any = nil
local shownSnap: any = nil
local smears: { any } = {}
local smearShown = false
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

local breathPhase = 0
local winded = 0

-- The slow rise and fall of breathing, with a little wander in the hands.
local function breathing(dt: number, aiming: boolean, running: boolean): CFrame
	winded = math.clamp(winded + (if running then WINDED_GAIN else -WINDED_FADE) * dt, 0, 1)
	breathPhase += dt * (1 + (WINDED_SPEED - 1) * winded) * 2 * math.pi / BREATH_SECONDS
	-- In quicker than out, with a rest at the bottom, like a real breath.
	local breath = math.sin(breathPhase) + 0.22 * math.sin(2 * breathPhase + 1.1)
	local late = math.sin(breathPhase - 0.5) -- the tilt trails the lift, so it reads as weight
	local size = (1 + (WINDED_SIZE - 1) * winded)
		* (1 - (1 - BREATH_MOVING) * math.min(bobWeight, 1))
		* (if aiming then BREATH_AIMED else 1)
	local clock = os.clock()
	local driftX = math.sin(clock * 0.83) + 0.6 * math.sin(clock * 1.37 + 2)
	local driftY = math.sin(clock * 0.61 + 1) + 0.6 * math.sin(clock * 1.13 + 4)
	return CFrame.new(driftX * DRIFT_MOVE * size, (breath * BREATH_LIFT + driftY * DRIFT_MOVE) * size, breath * BREATH_BACK * size)
		* CFrame.Angles(
			math.rad((late * BREATH_PITCH + driftY * DRIFT_TURN) * size),
			math.rad(driftX * DRIFT_TURN * size),
			math.rad(late * BREATH_ROLL * size)
		)
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

	return CFrame.new(swayAngles.Y * SWAY_MOVE, swayAngles.X * SWAY_MOVE, 0)
		* CFrame.Angles(swayAngles.X, swayAngles.Y, swayAngles.Y * 0.6)
		* bob
		* breathing(dt, aiming, running)
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
	view = makeModel(GunConfig.guns[gunId].name) or makeBlock()
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
	holsterAt = nil
	equipAt = nil
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
	return view:GetPivot() * Vector3.new(0, barrelRise, -length / 2)
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
		kickRoll = 1
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
		local frame = ArmClip.sampleAt(reloadClip, elapsed)
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

-- With a card out, the gun drops, then the hands play the deck flourish and hold the deck. Using the card crushes it
-- in the right hand before the gun comes back.
-- Returns true while the card has the screen.
local function showCard(camera: Camera, cardOut: boolean, cardSway: CFrame): boolean
	local now = os.clock()
	local drop = if clips then #clips.holster.frames / clips.holster.fps else 0
	if cardOut and crushAt then
		cardAt, crushAt = nil, nil -- another card came out mid-crush
	end
	if not cardOut then
		if not cardAt then
			return false
		end
		if not crushAt and CardInHand.used ~= cardUsed and now - cardAt >= drop then
			crushAt = now
		end
		if not crushAt or now - crushAt >= CardFlourish.CRUSH then
			cardAt, holsterAt, crushAt = nil, nil, nil
			equipAt = now
			shownFrame, shownBase, shownSnap = nil, nil, nil
			CardView.hide()
			return false
		end
	end
	if not cardAt then
		cardAt = now
		holsterAt = cardAt
		cardUsed = CardInHand.used
	end
	local elapsed = (crushAt or now) - (cardAt :: number) - drop
	if elapsed < 0 then
		return false
	end
	if view and view.Parent then
		view.Parent = nil
		hideSmears()
		table.clear(history)
	end
	local held = camera.CFrame * cardSway
	local crush = if crushAt then CardFlourish.crush(elapsed, now - crushAt) else nil
	local pose = if crush then crush.pose else CardFlourish.at(elapsed)
	ViewArms.holdCards(pose.right, pose.left, pose.fingers)
	CardView.show(camera, held, pose.cards, crush)
	ViewArms.place(camera, held)
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
	local recoil = CFrame.new(0, -viewKick.drop * kick, viewKick.back * kick)
		* CFrame.Angles(math.rad(viewKick.up * kick), 0, math.rad(viewKick.roll * kickRoll * kick))
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
	local base = camera.CFrame * reach * sway * (if clips then recoil * layerShown else CFrame.identity)
	if showCard(camera, cardOut, sway) then
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
			reloadGun, reloadHand, spin = reloadPose(keyedReload, now - keyedReloadAt, config.reload)
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
		local hand = held * forward * equip * recoil * reloadGun * (turn or CFrame.identity)
		-- The spin turns round the trigger guard, just ahead of the hand on the grip.
		local pivot = right.wrist - (if gripShift then gripShift.right else Vector3.zero)
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
	local pivot = view:GetPivot()
	showFlash(camera, pivot * CFrame.new(0, barrelRise, -length / 2))
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
	showScope(0)
	if flashModel then
		flashModel.Parent = nil
	end
end

return GunView
