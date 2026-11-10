-- The deck flourish played when a card comes out: the deck springs from the right hand to the left, the left hand
-- tips it over and slides the top half off, the right hand takes that half, spins it, fans it open, then closes it
-- back onto the rest. To finish, the left thumb flips the top card across and the right hand catches it.
-- Everything is worked out on a stage: a flat plane in front of the camera, tilted to face it. On the stage x runs
-- right, z runs down the screen and y comes toward the player. A card lying on it is upright with its face showing,
-- and the hands stay behind the cards, with only thumbs and fingertips coming round to the front.
local STAGE = CFrame.new(0, -0.25, -1.05) * CFrame.Angles(math.rad(63), 0, 0)

local COUNT = 32 -- cards in the deck
local HALF = COUNT / 2 -- cards in the half the right hand takes, which is the top one
local THICKNESS = 0.003 -- of one card, so the deck is about 0.1 thick
local CARD_SIZE = Vector3.new(0.28, 0.002, 0.448) -- sized to the soldier's hands
local CHOSEN = 1 -- the card that ends in the right hand: the bottom of the right hand's half, until that turns over
local HALF_HEIGHT = HALF * THICKNESS

local SPRING_FROM = 0.1 -- the first card leaves the right hand
local SPRING_TO = 0.9 -- the last one leaves
local FLIGHT = 0.25 -- seconds each card is in the air
local FLIGHT_RISE = 0.07
local SLIDE_AT = 1.85 -- the top half starts to slide off
local CUT_AT = 2.2 -- the right hand has it
local JOINED_AT = 4.75 -- and the halves are one deck again
local FLIP_AT = 4.95 -- the left thumb flips the top card off
local CAUGHT_AT = 5.45 -- and the right hand has it
local LENGTH = 5.9
local CRUSH = 0.5 -- seconds the right hand takes to crush its card, once it's used
local BURST_AT = 0.2 -- into the crush, the card is gone

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
-- The top half from when it slides off: the right hand takes it, spins it once as it turns face up, fans it, then
-- drops it back on.
-- The same, turned face down.
local function over(k: Key): Key
	return key(k.at, k.x, k.y, k.z, k.yaw, k.pitch, k.roll + 180)
end

local RIGHT_HALF: { Key } = {
	again(SLIDE_AT, TIPPED, 0, HALF_HEIGHT),
	again(CUT_AT, TIPPED, 0.14, HALF_HEIGHT, 0.24),
	key(2.5, 0.12, 0.16, -0.02, -5, 0, -15),
	again(3.0, SPUN, 0, 0, 0, 1),
	again(3.2, SPUN, 0, 0, 0, 1),
	again(3.65, FANNED, 0, 0, 0, 1),
	again(4.1, FANNED, 0, 0, 0, 1),
	key(4.45, -0.04, 0.34, 0.01, 360 + FINAL.yaw),
	over(again(JOINED_AT, FINAL, 0, (COUNT - 1) * THICKNESS, 0, 1)), -- it lands face down
	over(again(LENGTH, FINAL, 0, (COUNT - 1) * THICKNESS, 0, 1)),
}
-- The top card's flip across to the right hand, turning face up on the way.
local TOP = over(again(0, FINAL, 0, (COUNT - 1) * THICKNESS))
local FLIP: { Key } = {
	again(FLIP_AT, TOP),
	key(5.2, 0.2, 0.4, -0.08, 0, 0, 90),
	key(CAUGHT_AT, HELD.x, HELD.y, HELD.z, HELD.yaw, 0, 0),
	key(LENGTH, HELD.x, HELD.y, HELD.z, HELD.yaw, 0, 0),
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

-- How far along a move is. It only half slows into each key, so one move runs on into the next.
local function eased(share: number): number
	return (share + smooth(share)) / 2
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
	held(5.0, WAITING, PINCH_GRIP),
	held(5.35, HELD, CARD_GRIP),
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
local function sprung(index: number, at: number, pile: CFrame): CFrame
	local up = height(index)
	local leaves = SPRING_FROM + (SPRING_TO - SPRING_FROM) * up / (COUNT - 1)
	local share = math.clamp((at - leaves) / FLIGHT, 0, 1)
	local from = RIGHT_DECK_FRAME * CFrame.new(0, (COUNT - 1 - up) * THICKNESS, 0)
	local to = pile * CFrame.new(0, up * THICKNESS, 0)
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
local RIGHT_CATCH = shape("Right", { 0.9, 0.4, 0.2 }, { 0.7, 0.6, 0.1 }, 0.14, { 8, 4, 4 }) -- open for the flipped card
local RIGHT_CARD = shape("Right", { 0.7, 0.7, 0 }, { 0, 0.95, -0.3 }, 0.1, { 3, 2, 2 }) -- thumb down on one card
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
	{ at = 5.05, shape = RIGHT_REST },
	{ at = 5.35, shape = RIGHT_CATCH },
	{ at = 5.52, shape = RIGHT_CARD },
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
	{ at = FLIP_AT, shape = LEFT_HOLD },
	{ at = 5.05, shape = LEFT_PUSH },
	{ at = 5.2, shape = LEFT_LIFT },
	{ at = 5.55, shape = LEFT_HOLD },
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
	CHOSEN = CHOSEN,
	LENGTH = LENGTH,
	CARD_SIZE = CARD_SIZE,
	CRUSH = CRUSH,
	BURST_AT = BURST_AT,
}

export type Pose = { cards: { CFrame }, right: CFrame, left: CFrame, fingers: Hands }

-- Every card, each hand's palm and how its fingers sit, relative to the camera, after elapsed seconds. It holds its
-- end.
-- Cards 1 to HALF are the right hand's half, bottom up, and card CHOSEN is the one that ends in the right hand.
function CardFlourish.at(elapsed: number): Pose
	local at = math.clamp(elapsed, 0, LENGTH)
	local cards = table.create(COUNT)
	local leftHalf = frameOf(flowing(LEFT_HALF, at))
	if at < SPRING_TO + FLIGHT then
		for index = 1, COUNT do
			cards[index] = sprung(index, at, leftHalf)
		end
	else
		local rightHalf = if at < SLIDE_AT
			then leftHalf * CFrame.new(0, HALF_HEIGHT, 0)
			else frameOf(flowing(RIGHT_HALF, at))
		local open = flowing(FAN, at).x
		for index = 1, HALF do
			cards[index] = fanned(rightHalf, index, open)
			cards[HALF + index] = leftHalf * CFrame.new(0, (index - 1) * THICKNESS, 0)
		end
		if at > FLIP_AT then
			cards[CHOSEN] = frameOf(flowing(FLIP, at))
		end
	end
	return {
		cards = cards,
		right = handFlowing(RIGHT_HAND, at),
		left = leftHalf * LEFT_GRIP,
		fingers = { Right = fingersAt(RIGHT_FINGERS, at), Left = fingersAt(LEFT_FINGERS, at) },
	}
end

local ended: Pose? = nil

export type Crush = { pose: Pose, crushed: number, palm: Vector3 }

-- The card being used: `since` seconds ago, with the flourish `elapsed` seconds in. Wherever things were, the right
-- hand snatches its card and closes into a fist around it, and the rest of the deck squares up in the left.
-- crushed is how far gone the card is, from 0 to 1, and palm is the middle of the fist.
function CardFlourish.crush(elapsed: number, since: number): Crush
	local pose = CardFlourish.at(elapsed)
	local final = ended or CardFlourish.at(LENGTH)
	ended = final
	local grab = smooth(math.clamp(since / 0.12, 0, 1))
	local fist = smooth(math.clamp((since - 0.06) / (BURST_AT - 0.06), 0, 1))
	pose.right = pose.right:Lerp(final.right, grab)
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
		pose.cards[index] = frame:Lerp(final.cards[index], grab) -- the deck snaps shut out of the fist's way
	end
	local card = pose.cards[CHOSEN]
	pose.cards[CHOSEN] = card - card.Position + card.Position:Lerp(palm, fist)
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
	return { pose = pose, crushed = fist, palm = palm }
end

return CardFlourish
