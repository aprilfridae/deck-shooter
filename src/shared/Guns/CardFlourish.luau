-- The deck flourish played when a card comes out: the deck springs from the right hand to the left, the left hand
-- tips it over and slides the top half off, the right hand takes that half, spins it, fans it open, then closes it
-- back onto the rest. To finish, the left thumb flips the top card across and the right hand catches it.
-- Everything is worked out on a stage: a flat plane in front of the camera, tilted to face it. On the stage x runs
-- right, z runs down the screen and y comes toward the player. A card lying on it is upright with its face showing,
-- and the hands stay behind the cards, with only thumbs and fingertips coming round to the front.
local STAGE = CFrame.new(0, -0.36, -1.4) * CFrame.Angles(math.rad(63), 0, 0) -- far and low enough to leave most of the screen clear

local COUNT = 32 -- cards in the deck
local HALF = COUNT / 2 -- cards in the half the right hand takes, which is the top one
local THICKNESS = 0.003 -- of one card, so the deck is about 0.1 thick
local CARD_SIZE = Vector3.new(0.28, 0.002, 0.448) -- sized to the soldier's hands
local CHOSEN = HALF -- the card that ends in the right hand: the top one
local HALF_HEIGHT = HALF * THICKNESS

local SPRING_FROM = 0.1 -- the first card leaves the right hand
local SPRING_TO = 0.9 -- the last one leaves
local FLIGHT = 0.25 -- seconds each card is in the air
local BOW = math.rad(40) -- how far round the deck is bent in the right hand before it springs, end to end
local BOW_TIME = 0.08 -- seconds the hand takes to bend it
local STRIPS = 4 -- pieces a bent card is shown in, along its length
local FLIGHT_RISE = 0.07
local SLIDE_AT = 1.85 -- the top half starts to slide off
local CUT_AT = 2.2 -- the right hand has it
local JOINED_AT = 4.75 -- and the halves are one deck again
local FLIP_AT = 4.95 -- the left thumb flips the top card off
local CAUGHT_AT = 5.25 -- and the right hand has it: a quick flick, as it is in real life
local LENGTH = 5.7
local SPEED = 1.6 -- how much faster than its keys the whole flourish plays
local LANDED_AT = SPRING_TO + FLIGHT -- the last card is in the left hand
local CRUSH = 0.4 -- seconds the right hand takes to crush its card, once it's used
local BURST_AT = 0.16 -- into the crush, the card is gone
-- A card that is thrown, not crushed (Switchback). It is an overhand throw with the card on edge, from River's
-- own video (2026-11-12): the right hand turns the card upright, lifts it up beside the head, then chops down
-- and forward and lets go.
-- River then had it made "smoother and more swaggy": it takes its time, every part eases in and out and runs
-- into the next, the card twirls in the fingers on the way up, the hand sweeps out in a curve and flicks across as
-- it lets go, and it hangs out there a beat with a little bounce before coming home.
local THROW = 0.7 -- seconds the whole throw takes
local THROW_BACK = 0.17 -- the hand is up and cocked by now
local THROW_RELEASE = 0.22 -- and the card leaves it now: CardAim.THROW_WINDUP is the same moment
local THROW_HANG = 0.16 -- how long the hand stays out after letting go
local THROW_SWEEP = Vector3.new(0.09, 0.03, 0) -- how far out the chop curves on its way through
local THROW_FLICK = math.rad(-22) -- the wrist's turn across as it lets go
local THROW_TWIRL = math.rad(360) -- the card's spin in the fingers on the way up
local THROW_BOUNCE = 0.035 -- how far the hand gives as the card leaves it
local THROW_DRAW = Vector3.new(0.1, 0.34, 0.16) -- where the hand lifts to, from where it was: right, up, toward you
-- Where the card is as it leaves the hand, from the camera: just right of and under the crosshair, an arm's length
-- out. And how it is turned there: on its edge, long side pointing the way you look. The world's card starts from
-- exactly this, so the throw is one motion.
local THROW_LEAVES = Vector3.new(0.1, -0.1, -1.15)
local THROW_AIMED = CFrame.Angles(0, 0, math.rad(90))
local THROW_COCK = math.rad(50) -- how far the hand tips back at the top
local THROW_SNAP = math.rad(-75) -- and how far it chops through

local FAN_PIVOT = Vector3.new(0.05, 0, 0.13) -- on the card, under the right thumb
local FAN_TOP = -60 -- degrees the top card leans
local FAN_BOTTOM = 125 -- and the bottom card
local FAN_GAP = 0.0012 -- extra space between fanned cards, so they don't flicker
local FAN_AT = 3.55 -- the fan snaps open
local FAN_RIPPLE = 0.09 -- seconds the fan's bottom card opens behind its top one
local FLIP_LEAD = 0.1 -- the flip's rounded corner starts this long before FLIP_AT, so the card leaves the deck smoothly

-- Weight. Whatever lands in a hand knocks it down and it rings back, and the cards in it go with it.
local SINK = Vector3.new(0, -1, 0.3) -- the way a hand gives, relative to the camera
local CATCH = Vector3.new(0.7, -0.6, 0.2) -- and the way the right hand gives when the flipped card slaps into it

-- A gentler ease than smooth: it starts and stops with no jolt at all.
local function smoother(share: number): number
	return share * share * share * (share * (share * 6 - 15) + 10)
end

local function smooth(share: number): number
	return share * share * (3 - 2 * share)
end

-- A knock: a dip that rings out, `since` seconds after something lands. It eases in, so nothing jumps.
local function knock(since: number): number
	if since < 0 then
		return 0
	end
	return math.exp(-since * 8) * math.sin(since * 17) * smooth(math.min(since / 0.1, 1))
end

type Key = { at: number, x: number, y: number, z: number, yaw: number, pitch: number, roll: number }

local function key(at: number, x: number, y: number, z: number, yaw: number, pitch: number?, roll: number?): Key
	return { at = at, x = x, y = y, z = z, yaw = yaw, pitch = pitch or 0, roll = roll or 0 }
end

-- A key as a frame on the stage, relative to the camera.
local function frameOf(k: Key): CFrame
	return STAGE
		* CFrame.new(k.x, k.y, k.z)
		* CFrame.Angles(0, math.rad(k.yaw), 0)
		* CFrame.Angles(math.rad(k.pitch), 0, 0)
		* CFrame.Angles(0, 0, math.rad(k.roll))
end

-- A key again at another time, moved by an offset along its own card: x to the card's right, y off its face.
local function again(at: number, from: Key, x: number?, y: number?, z: number?, turns: number?): Key
	local moved = STAGE:ToObjectSpace(frameOf(from) * CFrame.new(x or 0, y or 0, z or 0)).Position
	return key(at, moved.X, moved.Y, moved.Z, from.yaw + (turns or 0) * 360, from.pitch, from.roll)
end

local RIGHT_DECK = key(0, 0.42, 0.2, -0.12, 20, 0, 55) -- in the right hand before it springs, facing the left hand
local PILE = key(0, -0.27, 0, 0.04, -12, 0, 5) -- where it lands, in the left hand
local TIPPED = key(0, -0.2, 0.08, 0.02, -12, 0, -32) -- tipped toward the right hand
local ASIDE = key(0, -0.34, 0.06, 0.04, -12, 0, -32) -- the left hand's half, out of the fan's way
local FINAL = key(0, -0.12, 0.04, 0.03, -12, 0, 0)
local SPUN = key(0, 0.32, 0.18, -0.04, 15, 0, 0) -- the right hand's half after its spin
local FANNED = key(0, 0.26, 0.2, -0.06, 0, 0, 0)
local HELD = key(0, 0.5, 0.16, -0.02, 12, 0, 0) -- the card the right hand ends up holding
local WAITING = key(0, 0.3, -0.02, 0.3, 10, 0, 0) -- where the right hand rests, low and out of the way

-- The bottom half, which never leaves the left hand.
local LEFT_HALF: { Key } = {
	again(0, PILE),
	again(1.15, PILE),
	again(1.6, TIPPED),
	again(CUT_AT, TIPPED),
	again(2.6, ASIDE),
	again(4.3, ASIDE),
	again(4.65, FINAL),
	again(LENGTH, FINAL),
}
-- The top half from when it slides off: the right hand takes it, spins it twice as it turns face up, fans it, then
-- drops it back on.
local FACE_DOWN = CFrame.Angles(0, 0, math.pi)

-- The same, turned face down.
local function over(k: Key): Key
	return key(k.at, k.x, k.y, k.z, k.yaw, k.pitch, k.roll + 180)
end

local RIGHT_HALF: { Key } = {
	again(SLIDE_AT, TIPPED, 0, HALF_HEIGHT),
	again(CUT_AT, TIPPED, 0.2, HALF_HEIGHT, 0.24),
	key(2.5, 0.12, 0.16, -0.02, -5, 0, -15),
	again(3.0, SPUN, 0, 0, 0, 2), -- two full turns
	again(3.2, SPUN, 0, 0, 0, 2),
	again(3.65, FANNED, 0, 0, 0, 2),
	again(4.1, FANNED, 0, 0, 0, 2),
	key(4.45, -0.04, 0.34, 0.01, 720 + FINAL.yaw),
	again(JOINED_AT, FINAL, 0, HALF_HEIGHT, 0, 2),
	again(LENGTH, FINAL, 0, HALF_HEIGHT, 0, 2),
}
-- The top card's flip across to the right hand, turning face up on the way.
local TOP = over(again(0, FINAL, 0, (COUNT - 1) * THICKNESS))
local FLIP: { Key } = {
	again(FLIP_AT, TOP),
	key(FLIP_AT + 0.14, 0.2, 0.4, -0.08, 0, 0, 90),
	key(CAUGHT_AT, HELD.x, HELD.y, HELD.z, HELD.yaw, 0, 0),
	key(LENGTH, HELD.x, HELD.y, HELD.z, HELD.yaw, 0, 0),
}
-- How far open the fan is, from 0 to 1, in a key's x.
local FAN: { Key } = {
	key(3.2, 0, 0, 0, 0),
	key(FAN_AT, 1, 0, 0, 0),
	key(4.1, 1, 0, 0, 0),
	key(4.4, 0, 0, 0, 0),
}

-- How far along a move is. A practised hand: it's off at once and settles softly, without quite stopping, so one
-- move runs on into the next.
local function eased(share: number): number
	return 0.25 * share + 0.35 * smooth(share) + 0.4 * (1 - (1 - share) ^ 2)
end

-- Moments around a time, and how much each counts. Blending them rounds off the corner at every key.
local TAPS = { { -0.1, 1 }, { -0.05, 2 }, { 0, 3 }, { 0.05, 2 }, { 0.1, 1 } }

-- Where a keyed thing is at a time, easing in and out of every key.
local function sample(keys: { Key }, at: number): Key
	if at <= keys[1].at then
		return keys[1]
	end
	for index = 2, #keys do
		local to = keys[index]
		if at <= to.at then
			local from = keys[index - 1]
			local share = eased((at - from.at) / (to.at - from.at))
			local function mix(name: string): number
				return (from :: any)[name] + ((to :: any)[name] - (from :: any)[name]) * share
			end
			return key(at, mix("x"), mix("y"), mix("z"), mix("yaw"), mix("pitch"), mix("roll"))
		end
	end
	return keys[#keys]
end

-- The same, with its corners rounded off.
local function flowing(keys: { Key }, at: number): Key
	local sum, total = key(at, 0, 0, 0, 0), 0
	for _, tap in TAPS do
		local there = sample(keys, at + tap[1])
		for _, name in { "x", "y", "z", "yaw", "pitch", "roll" } do
			(sum :: any)[name] += (there :: any)[name] * tap[2]
		end
		total += tap[2]
	end
	return key(at, sum.x / total, sum.y / total, sum.z / total, sum.yaw / total, sum.pitch / total, sum.roll / total)
end

-- Where a hand sits on a card, as its palm on the card's frame: the point `along` up its fingers from the wrist and
-- `out` from its palm, and `across` toward its thumb, goes on the card at `at`, with its fingers running one way and
-- its palm facing another.
local function grip(side: string, at: Vector3, along: number, out: number, fingers: Vector3, palm: Vector3, across: number?): CFrame
	local y = fingers.Unit
	local facing = (palm - y * palm:Dot(y)).Unit
	local x = if side == "Right" then facing else -facing
	local z = x:Cross(y)
	return CFrame.fromMatrix(at - y * along - facing * out + z * (across or 0), x, y, z)
end

local UP = Vector3.yAxis
-- The left hand cradles its cards from behind: fingers across the back and up the right edge, thumb at the top left.
local LEFT_GRIP = grip("Left", Vector3.new(CARD_SIZE.X / 2, 0, 0.02), 0.5, 0.1, Vector3.new(0.94, 0, -0.34), UP)
-- The right hand before the spring: behind the deck, fingers hooked over its top edge.
local SPRING_GRIP = grip("Right", Vector3.new(0, 0, -CARD_SIZE.Z / 2), 0.55, 0.1, -Vector3.zAxis, UP)
-- The right hand on its half: behind it, reaching up from below, with the thumb round on its face.
local CARD_GRIP = grip("Right", FAN_PIVOT, 0.38, 0.1, Vector3.new(-0.26, 0, -0.97), UP, 0.12) -- the same, on one card
local PINCH_GRIP = grip("Right", FAN_PIVOT, 0.38, 0.1, Vector3.new(-0.26, 0, -0.97), UP, 0.12)
-- The same as it comes for its half: leaning in from the right, so its wrist and arm stay clear of the left arm.
local SWOOP_GRIP = grip("Right", FAN_PIVOT, 0.38, 0.1, Vector3.new(-0.53, 0, -0.85), UP, 0.12)

type HandKey = { at: number, frame: CFrame }

local function held(at: number, on: Key, by: CFrame, back: number?): HandKey
	return { at = at, frame = frameOf(on) * by * CFrame.new(0, -(back or 0), 0) }
end

-- The right hand. It lets its half spin without turning with it.
local RIGHT_HAND: { HandKey } = {
	held(0, RIGHT_DECK, SPRING_GRIP),
	held(1.05, RIGHT_DECK, SPRING_GRIP),
	held(1.45, WAITING, PINCH_GRIP),
	-- Out to the right of the deck, not under it, and low and back, so the half slides down over its fingers and
	-- it closes up onto it from beyond its edge.
	held(SLIDE_AT, again(0, TIPPED, 0.45, HALF_HEIGHT - 0.09, 0.3), SWOOP_GRIP, 0.1),
	held(CUT_AT, RIGHT_HALF[2], SWOOP_GRIP),
	held(2.5, RIGHT_HALF[3], PINCH_GRIP),
	held(3.0, SPUN, PINCH_GRIP),
	held(3.2, SPUN, PINCH_GRIP),
	held(3.65, FANNED, PINCH_GRIP),
	held(4.1, FANNED, PINCH_GRIP),
	held(4.45, again(0, RIGHT_HALF[8], 0, 0, 0, -2), PINCH_GRIP),
	held(JOINED_AT, WAITING, PINCH_GRIP),
	held(4.85, WAITING, PINCH_GRIP),
	held(5.2, HELD, CARD_GRIP),
	held(LENGTH, HELD, CARD_GRIP),
}

local function handAt(keys: { HandKey }, at: number): CFrame
	if at <= keys[1].at then
		return keys[1].frame
	end
	for index = 2, #keys do
		local to = keys[index]
		if at <= to.at then
			local from = keys[index - 1]
			return from.frame:Lerp(to.frame, eased((at - from.at) / (to.at - from.at)))
		end
	end
	return keys[#keys].frame
end

-- The same, with its corners rounded off.
local function handFlowing(keys: { HandKey }, at: number): CFrame
	local frame, total = CFrame.identity, 0
	for _, tap in TAPS do
		total += tap[2]
		frame = frame:Lerp(handAt(keys, at + tap[1]), tap[2] / total)
	end
	return frame
end

local RIGHT_DECK_FRAME = frameOf(RIGHT_DECK)
local RISE = STAGE:VectorToWorldSpace(Vector3.new(0, FLIGHT_RISE, 0))

-- How far up the squared deck a card sits. The left hand's half is the bottom one.
local function height(index: number): number
	return if index > HALF then index - HALF - 1 else HALF + index - 1
end

-- A card during the spring. They leave the face of the right hand's deck one by one and land from the bottom up.
-- Also returns whose it is: 1 in the right hand, down to 0 in the left.
-- Last, how far the card is bent: the deck is bowed toward the palm while it's squeezed, and each card snaps straight
-- as it leaves, whipping a little past flat.
local function sprung(index: number, at: number, pile: CFrame): (CFrame, number, number)
	local up = height(index)
	-- No two cards fly quite alike: each leaves a hair early or late, climbs its own height and flutters on the way.
	local odd, other = math.sin(index * 12.9898), math.sin(index * 78.233)
	local leaves = SPRING_FROM + (SPRING_TO - SPRING_FROM) * up / (COUNT - 1) + 0.01 * odd
	local share = math.clamp((at - leaves) / FLIGHT, 0, 1)
	local from = RIGHT_DECK_FRAME * CFrame.new(0, (COUNT - 1 - up) * THICKNESS, 0)
	local to = pile * CFrame.new(0, up * THICKNESS, 0)
	local arc = math.sin(share * math.pi)
	local flying = from:Lerp(to, smooth(share)) * CFrame.Angles(math.rad(7) * other * arc, math.rad(11) * odd * arc, 0)
	local bend = BOW * smooth(math.clamp(at / BOW_TIME, 0, 1)) * math.cos(share * math.pi * 1.5) * (1 - share)
	return flying + RISE * (arc * (1 + 0.25 * other)), 1 - smooth(share), bend
end

-- A card of the right hand's half, turned about the thumb by how far the fan is open.
local function fanned(half: CFrame, index: number, open: number): CFrame
	local along = 1 - (index - 1) / (HALF - 1)
	local angle = math.rad(FAN_TOP + (FAN_BOTTOM - FAN_TOP) * along) * open
	return half
		* CFrame.new(FAN_PIVOT)
		* CFrame.Angles(0, angle, 0)
		* CFrame.new(-FAN_PIVOT)
		* CFrame.new(0, (index - 1) * (THICKNESS + FAN_GAP * open), 0)
end

-- Finger shapes. Each is every digit's three joints as directions from the palm: y runs along the fingers, the
-- thumb's side is -z, and the palm faces +x on the right hand and -x on the left.
type Shape = { [string]: { Vector3 } }
type Hands = { Right: Shape, Left: Shape }
type FingerKey = { at: number, shape: Shape }

local FINGERS = { "Indice", "DedoMedio", "Anular", "Menique" }
local SPREADS = { -1, -0.3, 0.3, 1 } -- how far each finger leans when the hand spreads
local LAGS = { Pulgar = 0, Indice = 0, DedoMedio = 0.025, Anular = 0.05, Menique = 0.075 } -- seconds behind, so moves ripple

-- A direction from a hand: toward what its palm faces, along its fingers, and out to its thumb's side.
local function aim(sign: number, facing: number, along: number, thumbward: number): Vector3
	return Vector3.new(sign * facing, along, -thumbward).Unit
end

-- root and tip are the ways the thumb's first and last joints point, as { facing, along, thumbward }. spread fans
-- the fingers out. Each of bends is one finger's degrees at the knuckle, then at each joint after it, first finger
-- first; fingers left out copy the one before.
local function shape(side: string, root: { number }, tip: { number }, spread: number, ...: { number }): Shape
	local sign = if side == "Right" then 1 else -1
	local bends = { ... }
	local first, last = aim(sign, root[1], root[2], root[3]), aim(sign, tip[1], tip[2], tip[3])
	local digits: Shape = { Pulgar = { first, first:Lerp(last, 0.5).Unit, last } }
	for index, bone in FINGERS do
		local aims, angle = {}, 0
		for joint, bend in bends[math.min(index, #bends)] do
			angle += math.rad(bend)
			aims[joint] = Vector3.new(sign * math.sin(angle), math.cos(angle), SPREADS[index] * spread).Unit
		end
		digits[bone] = aims
	end
	return digits
end

local LEFT_OPEN = shape("Left", { 0.3, 0.6, 0.7 }, { 0.3, 0.8, 0.5 }, 0.12, { 8, 14, 12 }) -- waiting under the falling cards
-- The hand lies at a slant, so the first finger's joint falls short of the card's edge: it reaches out past the edge
-- before it curls round, where the others can fold straight over.
local LEFT_HOLD = shape("Left", { 1, 0.3, 0.1 }, { 0.3, 0.8, -0.5 }, 0.04, { 5, 40, 70 }, { 5, 62, 45 }, { 5, 80, 25 })
local LEFT_LIFT = shape("Left", { 1, 0.2, 0.3 }, { 0.9, 0.4, 0.2 }, 0.04, { 5, 80, 10 }) -- thumb up to let the other half land
local LEFT_HALVED = shape("Left", { 0.9, 0.5, 0.1 }, { 0.15, 0.85, -0.5 }, 0.04, { 5, 80, 40 }) -- on half a deck
-- Its fingers drop off the deck's edge so the top half can slide out over them, and its thumb pushes it.
local LEFT_RELEASE = shape("Left", { 1, 0.4, -0.2 }, { 0.2, 0.8, -0.8 }, 0.06, { 5, 20, 10 })
local LEFT_PUSH = shape("Left", { 1, 0.4, -0.2 }, { 0.2, 0.8, -0.8 }, 0.04, { 5, 70, 15 }) -- its thumb slides the top half off

local RIGHT_BOWED = shape("Right", { 0.9, 0.3, 0 }, { 0.5, 0.2, -0.8 }, 0.04, { 10, 52, 22 }) -- the deck squeezed against the fingers
local RIGHT_SQUEEZED = shape("Right", { 0.8, 0.4, -0.2 }, { 0.3, 0.3, -0.9 }, 0.02, { 18, 58, 28 }) -- the last cards leaving
local RIGHT_LOOSE = shape("Right", { 0.4, 0.6, 0.6 }, { 0.4, 0.8, 0.3 }, 0.1, { 10, 16, 12 })
local RIGHT_REACH = shape("Right", { 0.85, 0.5, 0.2 }, { 0.6, 0.8, 0 }, 0.06, { 0, 125, 50 }) -- thumb up, ready to pinch
local RIGHT_PINCH = shape("Right", { 0.7, 0.7, 0 }, { 0, 0.95, -0.3 }, 0.04, { 0, 130, 50 }) -- thumb on the face, fingers folded under
local RIGHT_UNFOLD = shape("Right", { 0.8, 0.5, 0.2 }, { 0.6, 0.7, 0.1 }, 0.15, { -30, 50, 30 }) -- fingers dropping back to open
local RIGHT_HOLD = shape("Right", { 0.7, 0.7, 0 }, { 0, 0.95, -0.3 }, 0.1, { 5, 3, 3 }) -- thumb on the face, fingers flat behind
local RIGHT_SPIN = shape("Right", { 0.9, 0.35, 0.3 }, { 0.75, 0.6, 0.2 }, 0.32, { -4, 4, 6 }, { 0, 4, 6 }, { 3, 6, 6 }, { 8, 8, 8 }) -- thumb off, letting the half turn
local RIGHT_FAN = shape("Right", { 0.7, 0.7, 0 }, { 0, 0.95, -0.3 }, 0.36, { 5, 3, 3 }) -- thumb on the pivot, fingers wide behind
local RIGHT_CATCH = shape("Right", { 0.9, 0.4, 0.2 }, { 0.7, 0.6, 0.1 }, 0.14, { 8, 4, 4 }) -- open for the flipped card
-- Thumb down on one card. The two fingers behind the card lie flat, or they poke through it; the two beside it curl.
local RIGHT_CARD = shape("Right", { 0.7, 0.7, 0 }, { 0, 0.95, -0.3 }, 0.08, { 3, 2, 2 }, { 3, 4, 4 }, { 7, 18, 14 }, { 12, 32, 24 })
local RIGHT_FIST = shape("Right", { 0.6, 0.7, -0.2 }, { 0.1, 0.6, -0.8 }, 0.02, { 60, 95, 70 })
local RIGHT_REST = shape("Right", { 0.5, 0.7, 0.4 }, { 0.4, 0.85, 0.1 }, 0.08, { 12, 18, 14 })

local RIGHT_FINGERS: { FingerKey } = {
	{ at = 0, shape = RIGHT_BOWED },
	{ at = SPRING_FROM, shape = RIGHT_BOWED },
	{ at = SPRING_TO, shape = RIGHT_SQUEEZED },
	{ at = 1.2, shape = RIGHT_LOOSE },
	{ at = SLIDE_AT, shape = RIGHT_REACH },
	{ at = CUT_AT, shape = RIGHT_PINCH },
	{ at = 2.45, shape = RIGHT_PINCH },
	{ at = 2.55, shape = RIGHT_UNFOLD },
	{ at = 2.7, shape = RIGHT_SPIN },
	{ at = 2.9, shape = RIGHT_SPIN },
	{ at = 3.1, shape = RIGHT_HOLD },
	{ at = 3.2, shape = RIGHT_HOLD },
	{ at = 3.65, shape = RIGHT_FAN },
	{ at = 4.1, shape = RIGHT_FAN },
	{ at = 4.4, shape = RIGHT_HOLD },
	{ at = 4.5, shape = RIGHT_SPIN },
	{ at = 4.9, shape = RIGHT_REST },
	{ at = 4.95, shape = RIGHT_REST },
	{ at = 5.15, shape = RIGHT_CATCH },
	{ at = 5.32, shape = RIGHT_CARD },
}
local LEFT_FINGERS: { FingerKey } = {
	{ at = 0, shape = LEFT_OPEN },
	{ at = 0.9, shape = LEFT_OPEN },
	{ at = 1.25, shape = LEFT_HOLD },
	{ at = SLIDE_AT - 0.25, shape = LEFT_HOLD },
	{ at = SLIDE_AT - 0.05, shape = LEFT_RELEASE },
	{ at = 2.45, shape = LEFT_RELEASE }, -- the right hand has lifted its half clear
	{ at = 2.7, shape = LEFT_HALVED },
	{ at = 4.3, shape = LEFT_HALVED },
	{ at = 4.5, shape = LEFT_LIFT },
	{ at = 4.75, shape = LEFT_LIFT },
	{ at = FLIP_AT, shape = LEFT_HOLD },
	{ at = 5.03, shape = LEFT_PUSH },
	{ at = 5.12, shape = LEFT_LIFT },
	{ at = 5.4, shape = LEFT_HOLD },
}

-- One hand's fingers at a time, each finger a touch behind the one before it.
local function fingersAt(keys: { FingerKey }, at: number): Shape
	local digits: Shape = {}
	for bone, lag in LAGS do
		local when = at - lag
		local aims = keys[#keys].shape[bone]
		if when <= keys[1].at then
			aims = keys[1].shape[bone]
		else
			for index = 2, #keys do
				local to = keys[index]
				if when <= to.at then
					local from = keys[index - 1]
					local share = smooth((when - from.at) / (to.at - from.at))
					local before, after = from.shape[bone], to.shape[bone]
					aims = {}
					for joint, direction in before do
						aims[joint] = direction:Lerp(after[joint], share).Unit
					end
					break
				end
			end
		end
		digits[bone] = aims
	end
	return digits
end

local CardFlourish = {
	COUNT = COUNT,
	STRIPS = STRIPS,
	HALF = HALF,
	CHOSEN = CHOSEN,
	LENGTH = LENGTH / SPEED, -- seconds it takes to play
	CARD_SIZE = CARD_SIZE,
	CRUSH = CRUSH,
	BURST_AT = BURST_AT,
	THROW = THROW,
}

-- sides is whose each card is: 0 in the left hand, 1 in the right, and between on its way across.
-- bends is how far round each card is bent along its length, in radians end to end, toward its face. None means flat.
export type Pose = {
	cards: { CFrame },
	sides: { number },
	right: CFrame,
	left: CFrame,
	fingers: Hands,
	bends: { number }?,
}

-- How far along a stretch of time a moment is, eased, from 0 to 1.
local function through(at: number, from: number, to: number): number
	return smooth(math.clamp((at - from) / (to - from), 0, 1))
end

-- A slow wander between -1 and 1 that never repeats itself. Each `which` wanders its own way.
local function wander(life: number, which: number): number
	return 0.55 * math.sin(life * 2.1 + which * 1.3)
		+ 0.3 * math.sin(life * 4.9 + which * 2.9)
		+ 0.15 * math.sin(life * 9.7 + which * 4.1)
end

local SWAY_MOVE = 0.012 -- studs a hand drifts
local SWAY_TURN = math.rad(3) -- and how far its wrist rolls
local TEMPO = 0.035 -- seconds the flourish runs ahead of or behind itself

-- How a hand at `palm` has drifted and turned about itself.
local function drift(palm: Vector3, life: number, which: number): CFrame
	local move = Vector3.new(wander(life, which), wander(life, which + 1), wander(life, which + 2)) * SWAY_MOVE
	local turn = CFrame.Angles(
		wander(life, which + 3) * SWAY_TURN,
		wander(life, which + 4) * SWAY_TURN,
		wander(life, which + 5) * SWAY_TURN
	)
	return CFrame.new(palm + move) * turn * CFrame.new(-palm)
end

-- Every card, each hand's palm and how its fingers sit, relative to the camera, after elapsed seconds. It holds its
-- end.
-- Cards 1 to HALF are the right hand's half, bottom up, and card CHOSEN is the one that ends in the right hand.
function CardFlourish.at(elapsed: number): Pose
	local at = math.clamp(elapsed * SPEED, 0, LENGTH)
	local cards = table.create(COUNT)
	local sides = table.create(COUNT, 0)
	local bends: { number }? = nil
	-- The left hand sinks as the deck piles into it, jumps as the top half is pulled off and flicked, and is knocked
	-- down when the half is dropped back on.
	local piled = smooth(math.clamp((at - SPRING_FROM - FLIGHT) / (SPRING_TO - SPRING_FROM), 0, 1))
	local loaded = piled - smooth(math.clamp((at - LANDED_AT) / 0.4, 0, 1))
	local dropped = SINK * (0.045 * knock(at - JOINED_AT + 0.03))
	local leftGive = SINK
			* (0.022 * loaded + 0.035 * knock(at - LANDED_AT + 0.04) - 0.014 * knock(at - CUT_AT) - 0.012 * knock(at - FLIP_AT))
		+ dropped
	-- The right hand kicks as the deck springs out of it, and takes the weight of the half, its spin stopping, the
	-- fan snapping open and the flipped card.
	local rightGive = SINK * (0.02 * knock(at - CUT_AT) + 0.022 * knock(at - 3.0) + 0.016 * knock(at - FAN_AT))
		- SINK * (0.012 * math.sin(piled * math.pi))
		+ CATCH * (0.035 * knock(at - CAUGHT_AT + 0.04))
	local leftHalf = frameOf(flowing(LEFT_HALF, at)) + leftGive
	if at < SPRING_TO + FLIGHT then
		local bent = table.create(COUNT, 0)
		for index = 1, COUNT do
			cards[index], sides[index], bent[index] = sprung(index, at, leftHalf)
		end
		bends = bent
	else
		local rightHalf = if at < SLIDE_AT
			then leftHalf * CFrame.new(0, HALF_HEIGHT, 0)
			else frameOf(flowing(RIGHT_HALF, at)) + rightGive + dropped
		local fanning = at > 3.1 and at < 4.6
		local taken = math.min(through(at, SLIDE_AT, CUT_AT), 1 - through(at, 4.45, JOINED_AT))
		for index = 1, HALF do
			-- The fan ripples open from its top card, and each card overshoots and springs back.
			local when = at - FAN_RIPPLE * (HALF - index) / (HALF - 1)
			local open = if fanning then flowing(FAN, when).x + 0.09 * knock(when - FAN_AT + 0.03) else 0
			cards[index] = fanned(rightHalf, index, open)
			sides[index] = taken
			cards[HALF + index] = leftHalf * CFrame.new(0, (index - 1) * THICKNESS, 0)
		end
	end
	-- Every card shows its back, until the flip turns the chosen one face up.
	for index, frame in cards do
		cards[index] = frame * FACE_DOWN
	end
	if at > FLIP_AT - FLIP_LEAD then
		cards[CHOSEN] = frameOf(flowing(FLIP, at)) + rightGive
		sides[CHOSEN] = through(at, FLIP_AT, CAUGHT_AT)
	end
	return {
		cards = cards,
		sides = sides,
		right = handFlowing(RIGHT_HAND, at) + rightGive,
		left = leftHalf * LEFT_GRIP,
		fingers = { Right = fingersAt(RIGHT_FINGERS, at), Left = fingersAt(LEFT_FINGERS, at) },
		bends = bends,
	}
end

-- Where the pieces of a bent card go: an arc along its length with its two ends where they'd be flat and its middle
-- pushed out toward its face. Piece 1 is at the card's -Z end.
function CardFlourish.strips(frame: CFrame, bend: number): { CFrame }
	local pieces = table.create(STRIPS)
	local length = CARD_SIZE.Z
	for piece = 1, STRIPS do
		local along = (piece - 0.5) / STRIPS - 0.5
		if math.abs(bend) < 1e-4 then
			pieces[piece] = frame * CFrame.new(0, 0, along * length)
		else
			local radius, angle = length / bend, bend * along
			pieces[piece] = frame
				* CFrame.new(0, radius * (math.cos(angle) - math.cos(bend / 2)), radius * math.sin(angle))
				* CFrame.Angles(angle, 0, 0)
		end
	end
	return pieces
end

local ended: Pose? = nil

-- The pose the flourish ends on. Nothing changes it.
local function final(): Pose
	local pose = ended or CardFlourish.at(LENGTH)
	ended = pose
	return pose
end

local TOP_FRAME = frameOf(TOP) -- the chosen card back on top of the deck
local TURN_FINGERS: { FingerKey } = { -- the right thumb lifts to let the next card land, then comes down on it
	{ at = FLIP_AT, shape = RIGHT_CARD },
	{ at = 5.1, shape = RIGHT_CATCH },
	{ at = 5.32, shape = RIGHT_CARD },
}

-- The card that's face up on top in the right hand after the held card has been turned `turns` times. Each turn
-- takes the next card down the deck, and after HALF of them they start again.
function CardFlourish.top(turns: number): number
	return CHOSEN - turns % HALF
end

-- Turning to the next card: the flourish is done, the held card has been changed `turns` times, the last of them
-- `since` seconds ago. The left thumb flips the deck's top card across, and it lands face up on the cards the right
-- hand already holds.
function CardFlourish.turn(turns: number, since: number): Pose
	local done = final()
	local over = turns % HALF
	local at = FLIP_AT - FLIP_LEAD + math.clamp(since, 0, 10) * SPEED
	local leftGive = SINK * (-0.012 * knock(at - FLIP_AT))
	local rightGive = CATCH * (0.035 * knock(at - CAUGHT_AT + 0.04))
	local cards = table.create(COUNT)
	local sides = table.create(COUNT, 0)
	for index, frame in done.cards do
		cards[index] = frame + leftGive
	end
	sides[CHOSEN - over] = through(at, FLIP_AT, CAUGHT_AT)
	for under = 0, over - 1 do
		sides[CHOSEN - under] = 1
		cards[CHOSEN - under] = done.cards[CHOSEN] * CFrame.new(0, under * THICKNESS, 0) + rightGive
	end
	-- A card's own y turns over with it, so the one offset starts it lower in the deck and lands it on top.
	cards[CHOSEN - over] = frameOf(flowing(FLIP, at)) * CFrame.new(0, over * THICKNESS, 0) + rightGive
	return {
		cards = cards,
		sides = sides,
		right = done.right + rightGive,
		left = done.left + leftGive,
		fingers = { Right = fingersAt(TURN_FINGERS, at), Left = fingersAt(LEFT_FINGERS, at) },
	}
end

-- The pose with life in it: each hand drifts and rolls a little on its own, never the same way twice, and its cards
-- go with it. life is any clock that keeps running. Also returns how the right hand moved.
function CardFlourish.sway(pose: Pose, life: number): (Pose, CFrame)
	local left, right = drift(pose.left.Position, life, 1), drift(pose.right.Position, life, 7)
	local cards = table.create(COUNT)
	for index, frame in pose.cards do
		local side = pose.sides[index]
		cards[index] = (if side <= 0 then left elseif side >= 1 then right else left:Lerp(right, side)) * frame
	end
	return {
		cards = cards,
		sides = pose.sides,
		right = right * pose.right,
		left = left * pose.left,
		fingers = pose.fingers,
		bends = pose.bends,
	},
		right
end

-- The flourish's time with its tempo loosened: it runs a touch ahead of itself and behind, differently every time.
-- It starts and ends on time.
function CardFlourish.tempo(elapsed: number, life: number): number
	local length = LENGTH / SPEED
	return elapsed + TEMPO * wander(life, 13) * through(elapsed, 0, 0.3) * (1 - through(elapsed, length - 0.5, length))
end

-- thrown is set when the card is being thrown, not crushed: it leaves the hand whole, with no fist and no burst.
export type Crush = { pose: Pose, crushed: number, palm: Vector3, card: number, thrown: boolean? }

-- The card being used: `since` seconds ago, with the flourish `elapsed` seconds in. Wherever things were, the right
-- hand snatches its card and closes into a fist around it, and the rest of the deck squares up in the left.
-- crushed is how far gone the card is, from 0 to 1, palm is the middle of the fist and card is the one crushed.
-- turns is how many times the held card had been changed. The cards under it in the right hand go back to the deck.
function CardFlourish.crush(elapsed: number, since: number, turns: number?): Crush
	local turned = turns or 0
	local chosen = CardFlourish.top(turned)
	local pose = if turned > 0 then CardFlourish.turn(turned, 10) else CardFlourish.at(elapsed)
	local final = final()
	local grab = smooth(math.clamp(since / 0.12, 0, 1))
	local fist = smooth(math.clamp((since - 0.06) / (BURST_AT - 0.06), 0, 1))
	pose.right = pose.right:Lerp(final.right, grab) + SINK * (0.04 * knock(since - BURST_AT + 0.03)) -- the fist jolts shut
	pose.left = pose.left:Lerp(final.left, grab)
	local holding: Shape = {}
	for bone, aims in pose.fingers.Left do
		local settled = {}
		for joint, direction in aims do
			settled[joint] = direction:Lerp(final.fingers.Left[bone][joint], grab).Unit
		end
		holding[bone] = settled
	end
	pose.fingers.Left = holding
	local palm = (pose.right * CFrame.new(0.06, 0.32, 0)).Position
	for index, frame in pose.cards do
		local to = final.cards[index]
		if index == chosen then
			to = final.cards[CHOSEN] -- held up in the right hand
		elseif index == CHOSEN then
			to = TOP_FRAME
		end
		pose.cards[index] = frame:Lerp(to, grab) -- the deck snaps shut out of the fist's way
		pose.sides[index] += ((if index == chosen then 1 else 0) - pose.sides[index]) * grab
	end
	local card = pose.cards[chosen]
	pose.cards[chosen] = card - card.Position + card.Position:Lerp(palm, fist)
	local digits: Shape = {}
	for bone, aims in pose.fingers.Right do
		local closed = {}
		for joint, direction in aims do
			local open = direction:Lerp(final.fingers.Right[bone][joint], grab)
			closed[joint] = open:Lerp(RIGHT_FIST[bone][joint], fist).Unit
		end
		digits[bone] = closed
	end
	pose.fingers.Right = digits
	return { pose = pose, crushed = fist, palm = palm, card = chosen }
end

-- The card being thrown: like crush, but the right hand lifts the card on its edge and chops it forward, and the card leaves it
-- whole at THROW_RELEASE. crushed is 0 while the card is in the hand and 1 once it has gone.
function CardFlourish.throw(elapsed: number, since: number, turns: number?): Crush
	local turned = turns or 0
	local chosen = CardFlourish.top(turned)
	local pose = if turned > 0 then CardFlourish.turn(turned, 10) else CardFlourish.at(elapsed)
	local final = final()
	local grab = smoother(math.clamp(since / THROW_BACK, 0, 1))
	-- The chop starts just before the lift has finished, so the hand never stops at the top.
	local whipFrom = THROW_BACK * 0.8
	local whip = smoother(math.clamp((since - whipFrom) / (THROW_RELEASE + 0.07 - whipFrom), 0, 1))
	-- How far the card has come onto its line: all the way at the moment it leaves the hand.
	local aimed = smoother(math.clamp((since - whipFrom) / (THROW_RELEASE - whipFrom), 0, 1))
	local homeFrom = THROW_RELEASE + THROW_HANG
	local home = smoother(math.clamp((since - homeFrom) / (THROW - homeFrom), 0, 1))
	local settled = pose.right:Lerp(final.right, grab)

	-- The card as it would sit in the still hand, before the throw moves it.
	local resting = pose.cards[chosen]:Lerp(final.cards[CHOSEN], grab)
	-- The chop carries the card to the point it leaves from, so the hand goes by however far the card has to.
	local reach = THROW_LEAVES - resting.Position
	local offset = THROW_DRAW * (grab - whip)
		+ reach * (whip - home)
		+ THROW_SWEEP * math.sin(math.pi * whip) -- out and round, not straight down the middle
		+ SINK * (THROW_BOUNCE * knock(since - THROW_RELEASE)) -- the hand gives as the card goes
	-- Turned about the camera's own axes, at the hand: tipped back then chopped forward. The wrist isn't rolled:
	-- that twisted the hand inward (River, 2026-11-12). The card turns onto its edge in the fingers instead.
	local tip = THROW_COCK * (grab - whip) + THROW_SNAP * (whip - home)
	local at = settled.Position + offset
	local flick = THROW_FLICK * (whip - home)
	local right = CFrame.new(at) * CFrame.Angles(tip, flick, 0) * settled.Rotation
	local carried = right * settled:Inverse() -- how the hand moved: the card in it goes the same way
	pose.right = right
	pose.left = pose.left:Lerp(final.left, grab)
	local holding: Shape = {}
	for bone, aims in pose.fingers.Left do
		local held = {}
		for joint, direction in aims do
			held[joint] = direction:Lerp(final.fingers.Left[bone][joint], grab).Unit
		end
		holding[bone] = held
	end
	pose.fingers.Left = holding
	local digits: Shape = {}
	for bone, aims in pose.fingers.Right do
		local held = {}
		for joint, direction in aims do
			held[joint] = direction:Lerp(final.fingers.Right[bone][joint], grab).Unit
		end
		digits[bone] = held
	end
	pose.fingers.Right = digits
	for index, frame in pose.cards do
		if index ~= chosen then
			local to = if index == CHOSEN then TOP_FRAME else final.cards[index]
			-- A card that was under the thrown one in the right hand is put straight back on the deck. Eased
			-- there, it could be seen sliding across to the left hand under the throw (River's clip, 2026-11-12).
			pose.cards[index] = if pose.sides[index] > 0.5 then to else frame:Lerp(to, grab)
			pose.sides[index] *= if pose.sides[index] > 0.5 then 0 else 1 - grab
		end
	end
	pose.sides[chosen] += (1 - pose.sides[chosen]) * grab
	-- The thrown card: it spins once on its own face on the way up, then comes onto its edge, pointing straight
	-- down the throw, at the very point the world's card carries on from. So what leaves the hand is aimed.
	local card = carried * resting * CFrame.Angles(0, THROW_TWIRL * grab, 0)
	pose.cards[chosen] = CFrame.new(card.Position:Lerp(THROW_LEAVES, aimed)) * card.Rotation:Lerp(THROW_AIMED, aimed)
	local palm = (pose.right * CFrame.new(0.06, 0.32, 0)).Position
	return { pose = pose, crushed = if since >= THROW_RELEASE then 1 else 0, palm = palm, card = chosen, thrown = true }
end

return CardFlourish
