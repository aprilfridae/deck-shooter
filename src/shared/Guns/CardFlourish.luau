-- The deck flourish played when a card comes out: the deck springs from the right hand to the left, the left hand
-- tips it over and slides the top half off, the right hand takes that half, spins it, fans it open, then closes it
-- back onto the rest.
-- Everything is worked out on a stage: a flat plane in front of the camera, tilted to face it. On the stage x runs
-- right, z runs down the screen and y comes toward the player. A card lying on it is upright with its face showing,
-- and the hands stay behind the cards, with only thumbs and fingertips coming round to the front.
local STAGE = CFrame.new(0, -0.25, -1.05) * CFrame.Angles(math.rad(63), 0, 0)

local COUNT = 32 -- cards in the deck
local HALF = COUNT / 2 -- cards in the half the right hand takes, which is the top one
local THICKNESS = 0.003 -- of one card, so the deck is about 0.1 thick
local CARD_SIZE = Vector3.new(0.28, 0.002, 0.448) -- sized to the soldier's hands
local HALF_HEIGHT = HALF * THICKNESS

local SPRING_FROM = 0.1 -- the first card leaves the right hand
local SPRING_TO = 0.9 -- the last one leaves
local FLIGHT = 0.25 -- seconds each card is in the air
local FLIGHT_RISE = 0.07
local SLIDE_AT = 1.85 -- the top half starts to slide off
local CUT_AT = 2.2 -- the right hand has it
local JOINED_AT = 4.75 -- and the halves are one deck again
local LENGTH = 5.4

local FAN_PIVOT = Vector3.new(0.05, 0, 0.13) -- on the card, under the right thumb
local FAN_TOP = -60 -- degrees the top card leans
local FAN_BOTTOM = 125 -- and the bottom card
local FAN_GAP = 0.0012 -- extra space between fanned cards, so they don't flicker

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
-- The top half from when it slides off: the right hand takes it, spins it once as it turns face up, fans it, then
-- drops it back on.
local RIGHT_HALF: { Key } = {
	again(SLIDE_AT, TIPPED, 0, HALF_HEIGHT),
	again(CUT_AT, TIPPED, 0.14, HALF_HEIGHT, 0.24),
	key(2.5, 0.12, 0.16, -0.02, -5, 0, -15),
	again(3.0, SPUN, 0, 0, 0, 1),
	again(3.2, SPUN, 0, 0, 0, 1),
	again(3.65, FANNED, 0, 0, 0, 1),
	again(4.1, FANNED, 0, 0, 0, 1),
	key(4.45, -0.04, 0.34, 0.01, 360 + FINAL.yaw),
	again(JOINED_AT, FINAL, 0, HALF_HEIGHT, 0, 1),
	again(LENGTH, FINAL, 0, HALF_HEIGHT, 0, 1),
}
-- How far open the fan is, from 0 to 1, in a key's x.
local FAN: { Key } = {
	key(3.2, 0, 0, 0, 0),
	key(3.65, 1, 0, 0, 0),
	key(4.1, 1, 0, 0, 0),
	key(4.4, 0, 0, 0, 0),
}

local function smooth(share: number): number
	return share * share * (3 - 2 * share)
end

-- Where a keyed thing is at a time, easing in and out of every key.
local function sample(keys: { Key }, at: number): Key
	if at <= keys[1].at then
		return keys[1]
	end
	for index = 2, #keys do
		local to = keys[index]
		if at <= to.at then
			local from = keys[index - 1]
			local share = smooth((at - from.at) / (to.at - from.at))
			local function mix(name: string): number
				return (from :: any)[name] + ((to :: any)[name] - (from :: any)[name]) * share
			end
			return key(at, mix("x"), mix("y"), mix("z"), mix("yaw"), mix("pitch"), mix("roll"))
		end
	end
	return keys[#keys]
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
local PINCH_GRIP = grip("Right", FAN_PIVOT, 0.38, 0.1, Vector3.new(-0.26, 0, -0.97), UP, 0.12)

type HandKey = { at: number, frame: CFrame }

local function held(at: number, on: Key, by: CFrame, back: number?): HandKey
	return { at = at, frame = frameOf(on) * by * CFrame.new(0, -(back or 0), 0) }
end

-- The right hand. It lets its half spin without turning with it.
local RIGHT_HAND: { HandKey } = {
	held(0, RIGHT_DECK, SPRING_GRIP),
	held(1.05, RIGHT_DECK, SPRING_GRIP),
	held(1.45, WAITING, PINCH_GRIP),
	held(SLIDE_AT, RIGHT_HALF[2], PINCH_GRIP, 0.2),
	held(CUT_AT, RIGHT_HALF[2], PINCH_GRIP),
	held(2.5, RIGHT_HALF[3], PINCH_GRIP),
	held(3.0, SPUN, PINCH_GRIP),
	held(3.2, SPUN, PINCH_GRIP),
	held(3.65, FANNED, PINCH_GRIP),
	held(4.1, FANNED, PINCH_GRIP),
	held(4.45, again(0, RIGHT_HALF[8], 0, 0, 0, -1), PINCH_GRIP),
	held(JOINED_AT, WAITING, PINCH_GRIP),
	held(LENGTH, WAITING, PINCH_GRIP),
}

local function handAt(keys: { HandKey }, at: number): CFrame
	if at <= keys[1].at then
		return keys[1].frame
	end
	for index = 2, #keys do
		local to = keys[index]
		if at <= to.at then
			local from = keys[index - 1]
			return from.frame:Lerp(to.frame, smooth((at - from.at) / (to.at - from.at)))
		end
	end
	return keys[#keys].frame
end

local RIGHT_DECK_FRAME = frameOf(RIGHT_DECK)
local PILE_FRAME = frameOf(PILE)
local RISE = STAGE:VectorToWorldSpace(Vector3.new(0, FLIGHT_RISE, 0))

-- How far up the squared deck a card sits. The left hand's half is the bottom one.
local function height(index: number): number
	return if index > HALF then index - HALF - 1 else HALF + index - 1
end

-- A card during the spring. They leave the face of the right hand's deck one by one and land from the bottom up.
local function sprung(index: number, at: number): CFrame
	local up = height(index)
	local leaves = SPRING_FROM + (SPRING_TO - SPRING_FROM) * up / (COUNT - 1)
	local share = math.clamp((at - leaves) / FLIGHT, 0, 1)
	local from = RIGHT_DECK_FRAME * CFrame.new(0, (COUNT - 1 - up) * THICKNESS, 0)
	local to = PILE_FRAME * CFrame.new(0, up * THICKNESS, 0)
	local flying = from:Lerp(to, smooth(share))
	return flying + RISE * math.sin(share * math.pi)
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
local LEFT_HOLD = shape("Left", { 1, 0.3, 0.1 }, { 0.3, 0.8, -0.5 }, 0.04, { 5, 80, 25 })
local LEFT_LIFT = shape("Left", { 1, 0.2, 0.3 }, { 0.9, 0.4, 0.2 }, 0.04, { 5, 80, 10 }) -- thumb up to let the other half land
local LEFT_HALVED = shape("Left", { 0.9, 0.5, 0.1 }, { 0.15, 0.85, -0.5 }, 0.04, { 5, 80, 40 }) -- on half a deck
local LEFT_PUSH = shape("Left", { 1, 0.4, -0.2 }, { 0.2, 0.8, -0.8 }, 0.04, { 5, 70, 15 }) -- its thumb slides the top half off

local RIGHT_BOWED = shape("Right", { 0.9, 0.3, 0 }, { 0.5, 0.2, -0.8 }, 0.04, { 12, 68, 30 }) -- the deck squeezed against the fingers
local RIGHT_SQUEEZED = shape("Right", { 0.8, 0.4, -0.2 }, { 0.3, 0.3, -0.9 }, 0.02, { 25, 75, 40 }) -- the last cards leaving
local RIGHT_LOOSE = shape("Right", { 0.4, 0.6, 0.6 }, { 0.4, 0.8, 0.3 }, 0.1, { 10, 16, 12 })
local RIGHT_REACH = shape("Right", { 0.85, 0.5, 0.2 }, { 0.6, 0.8, 0 }, 0.06, { 0, 125, 50 }) -- thumb up, ready to pinch
local RIGHT_PINCH = shape("Right", { 0.7, 0.7, 0 }, { 0, 0.95, -0.3 }, 0.04, { 0, 130, 50 }) -- thumb on the face, fingers folded under
local RIGHT_UNFOLD = shape("Right", { 0.8, 0.5, 0.2 }, { 0.6, 0.7, 0.1 }, 0.15, { -30, 50, 30 }) -- fingers dropping back to open
local RIGHT_HOLD = shape("Right", { 0.7, 0.7, 0 }, { 0, 0.95, -0.3 }, 0.1, { 5, 3, 3 }) -- thumb on the face, fingers flat behind
local RIGHT_SPIN = shape("Right", { 0.9, 0.35, 0.3 }, { 0.75, 0.6, 0.2 }, 0.32, { -4, 4, 6 }, { 0, 4, 6 }, { 3, 6, 6 }, { 8, 8, 8 }) -- thumb off, letting the half turn
local RIGHT_FAN = shape("Right", { 0.7, 0.7, 0 }, { 0, 0.95, -0.3 }, 0.36, { 5, 3, 3 }) -- thumb on the pivot, fingers wide behind
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
}
local LEFT_FINGERS: { FingerKey } = {
	{ at = 0, shape = LEFT_OPEN },
	{ at = 0.9, shape = LEFT_OPEN },
	{ at = 1.25, shape = LEFT_HOLD },
	{ at = SLIDE_AT, shape = LEFT_HOLD },
	{ at = CUT_AT, shape = LEFT_PUSH },
	{ at = 2.6, shape = LEFT_HALVED },
	{ at = 4.3, shape = LEFT_HALVED },
	{ at = 4.5, shape = LEFT_LIFT },
	{ at = 4.75, shape = LEFT_LIFT },
	{ at = 4.95, shape = LEFT_HOLD },
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
	HALF = HALF,
	LENGTH = LENGTH,
	CARD_SIZE = CARD_SIZE,
}

export type Pose = { cards: { CFrame }, right: CFrame, left: CFrame, fingers: Hands }

-- Every card, each hand's palm and how its fingers sit, relative to the camera, after elapsed seconds. It holds its
-- end.
-- Cards 1 to HALF are the right hand's half, bottom up, and card HALF ends face up on top of the deck.
function CardFlourish.at(elapsed: number): Pose
	local at = math.clamp(elapsed, 0, LENGTH)
	local cards = table.create(COUNT)
	local leftHalf = frameOf(sample(LEFT_HALF, at))
	if at < SPRING_TO + FLIGHT then
		for index = 1, COUNT do
			cards[index] = sprung(index, at)
		end
	else
		local rightHalf = if at < SLIDE_AT
			then leftHalf * CFrame.new(0, HALF_HEIGHT, 0)
			else frameOf(sample(RIGHT_HALF, at))
		local open = sample(FAN, at).x
		for index = 1, HALF do
			cards[index] = fanned(rightHalf, index, open)
			cards[HALF + index] = leftHalf * CFrame.new(0, (index - 1) * THICKNESS, 0)
		end
	end
	return {
		cards = cards,
		right = handAt(RIGHT_HAND, at),
		left = leftHalf * LEFT_GRIP,
		fingers = { Right = fingersAt(RIGHT_FINGERS, at), Left = fingersAt(LEFT_FINGERS, at) },
	}
end

return CardFlourish
