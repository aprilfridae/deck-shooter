-- The deck flourish played when a card comes out: the deck springs from the right hand to the left, squares up on
-- its edge, cuts in two, the right half spins and fans open, then closes back onto the left half.
-- Everything is worked out on a stage: a flat plane in front of the camera, tilted to face it. On the stage x runs
-- right, z runs down the screen and y comes toward the player. A card lying on it is upright with its face showing.
local STAGE = CFrame.new(0, -0.4, -1.0) * CFrame.Angles(math.rad(63), 0, 0)

local COUNT = 32 -- cards in the deck
local HALF = COUNT / 2 -- cards in the half the right hand takes
local THICKNESS = 0.0022 -- of one card, so the deck is about 0.07 thick
local CARD_SIZE = Vector3.new(0.2, 0.002, 0.32)

local SPRING_FROM = 0.1 -- the first card leaves the right hand
local SPRING_TO = 0.9 -- the last one leaves
local FLIGHT = 0.25 -- seconds each card is in the air
local FLIGHT_RISE = 0.05
local CUT_AT = 2.2 -- the halves come apart
local JOINED_AT = 4.75 -- and are one deck again
local LENGTH = 5.4

local FAN_PIVOT = Vector3.new(0.02, 0, 0.11) -- on the card, near the thumb
local FAN_TOP = -70 -- degrees the top card leans
local FAN_BOTTOM = 150 -- and the bottom card
local FAN_GAP = 0.0012 -- extra space between fanned cards, so they don't flicker

type Key = { at: number, x: number, y: number, z: number, yaw: number, pitch: number, roll: number, lift: number }

local function key(at: number, x: number, y: number, z: number, yaw: number, pitch: number?, roll: number?, lift: number?): Key
	return { at = at, x = x, y = y, z = z, yaw = yaw, pitch = pitch or 0, roll = roll or 0, lift = lift or 0 }
end

local function again(at: number, from: Key): Key
	return key(at, from.x, from.y, from.z, from.yaw, from.pitch, from.roll, from.lift)
end

-- The deck in the right hand before it springs, and the pile it lands in.
local RIGHT_DECK = key(0, 0.27, 0.14, -0.1, 25, 0, 60)
local PILE = key(0, -0.2, 0, 0.05, -20, 0, 8)
local ON_EDGE = key(0, -0.03, 0.08, 0, -25, 0, 112)
local FINAL = key(0, -0.06, 0.03, 0.02, -25, 0, 0)

-- The whole deck until the cut, by its bottom card.
local DECK: { Key } = {
	again(0, PILE),
	again(1.15, PILE),
	again(1.6, ON_EDGE),
	key(1.9, -0.02, 0.085, -0.01, -21, 0, 107),
	again(CUT_AT, ON_EDGE),
}
-- The half the left hand keeps. lift is how far it sits above the frame it follows.
local LEFT_HALF: { Key } = {
	key(CUT_AT, ON_EDGE.x, ON_EDGE.y, ON_EDGE.z, ON_EDGE.yaw, 0, ON_EDGE.roll, HALF * THICKNESS),
	key(2.6, -0.2, 0.08, 0.02, -20, 0, 112, HALF * THICKNESS),
	key(4.3, -0.2, 0.08, 0.02, -20, 0, 112, HALF * THICKNESS),
	again(4.65, FINAL),
	again(LENGTH, FINAL),
}
-- The half the right hand takes: it opens off the deck, spins once as it turns face up, fans, then drops back on.
local RIGHT_HALF: { Key } = {
	again(CUT_AT, ON_EDGE),
	key(2.5, 0.06, 0.1, -0.02, -10, 0, 95),
	key(3.0, 0.2, 0.12, -0.04, 400, 0, 0),
	key(3.2, 0.2, 0.12, -0.04, 400, 0, 0),
	key(3.65, 0.13, 0.14, -0.07, 360, 0, 0),
	key(4.1, 0.13, 0.14, -0.07, 360, 0, 0),
	key(4.45, 0, 0.13, 0, 335, 0, 0, HALF * THICKNESS),
	key(JOINED_AT, FINAL.x, FINAL.y, FINAL.z, 335, 0, 0, HALF * THICKNESS),
	key(LENGTH, FINAL.x, FINAL.y, FINAL.z, 335, 0, 0, HALF * THICKNESS),
}
-- How far open the fan is, from 0 to 1, in a key's x.
local FAN: { Key } = {
	key(3.2, 0, 0, 0, 0),
	key(3.65, 1, 0, 0, 0),
	key(4.1, 1, 0, 0, 0),
	key(4.4, 0, 0, 0, 0),
}
-- What each hand holds on to. A hand reaches in from the side its yaw gives: 45 is from the lower left, 135 from
-- the lower right.
local LEFT_HAND: { Key } = {
	key(0, -0.2, 0, 0.05, 45),
	key(1.15, -0.2, 0, 0.05, 45),
	key(1.6, -0.05, 0.08, 0, 60, 0, 25),
	key(CUT_AT, -0.05, 0.08, 0, 60, 0, 25),
	key(2.6, -0.22, 0.08, 0.02, 55, 0, 25),
	key(4.3, -0.22, 0.08, 0.02, 55, 0, 25),
	key(4.65, -0.06, 0.03, 0.02, 50),
	key(LENGTH, -0.06, 0.03, 0.02, 50),
}
local RIGHT_HAND: { Key } = {
	key(0, 0.25, 0.14, -0.1, 150, 0, -25),
	key(1.0, 0.25, 0.14, -0.1, 150, 0, -25),
	key(1.6, 0, 0.1, 0, 135),
	key(CUT_AT, 0, 0.1, 0, 135),
	key(2.5, 0.07, 0.1, -0.02, 135),
	key(3.0, 0.2, 0.12, -0.04, 135),
	key(3.2, 0.2, 0.12, -0.04, 135),
	key(3.65, 0.15, 0.14, 0.02, 150),
	key(4.1, 0.15, 0.14, 0.02, 150),
	key(4.45, 0.02, 0.13, 0, 135),
	key(JOINED_AT, -0.04, 0.07, 0.02, 135),
	key(LENGTH, 0, 0.07, 0.03, 135),
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
			return key(at, mix("x"), mix("y"), mix("z"), mix("yaw"), mix("pitch"), mix("roll"), mix("lift"))
		end
	end
	return keys[#keys]
end

-- A key as a frame on the stage, relative to the camera.
local function frameOf(k: Key): CFrame
	return STAGE
		* CFrame.new(k.x, k.y, k.z)
		* CFrame.Angles(0, math.rad(k.yaw), 0)
		* CFrame.Angles(math.rad(k.pitch), 0, 0)
		* CFrame.Angles(0, 0, math.rad(k.roll))
		* CFrame.new(0, k.lift, 0)
end

local RIGHT_DECK_FRAME = frameOf(RIGHT_DECK)
local PILE_FRAME = frameOf(PILE)
local RISE = STAGE:VectorToWorldSpace(Vector3.new(0, FLIGHT_RISE, 0))

-- A card during the spring. Card 1 leaves first, from the top of the right hand's deck, and lands at the bottom.
local function sprung(index: number, at: number): CFrame
	local leaves = SPRING_FROM + (SPRING_TO - SPRING_FROM) * (index - 1) / (COUNT - 1)
	local share = math.clamp((at - leaves) / FLIGHT, 0, 1)
	local from = RIGHT_DECK_FRAME * CFrame.new(0, (COUNT - index) * THICKNESS, 0)
	local to = PILE_FRAME * CFrame.new(0, (index - 1) * THICKNESS, 0)
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
-- thumb's side is -z, and a hand closes toward +x on the right and -x on the left.
type Shape = { [string]: { Vector3 } }
type Hands = { Right: Shape, Left: Shape }
type FingerKey = { at: number, shape: Hands }

local FINGERS = { "Indice", "DedoMedio", "Anular", "Menique" }
local SPREADS = { -1, -0.3, 0.3, 1 } -- how far each finger leans when the hand spreads
local LAGS = { Pulgar = 0, Indice = 0, DedoMedio = 0.025, Anular = 0.05, Menique = 0.075 } -- seconds behind, so moves ripple
local THUMB_OVER = Vector3.new(0.5, 0.85, 0.1).Unit -- where a curled thumb's tip heads

-- bends is degrees at the knuckle, then each joint after it.
local function finger(sign: number, bends: { number }, lean: number): { Vector3 }
	local aims, angle = {}, 0
	for joint, bend in bends do
		angle += math.rad(bend)
		aims[joint] = Vector3.new(sign * math.sin(angle), math.cos(angle), lean).Unit
	end
	return aims
end

-- across is 0 with the thumb out to the side and 1 with it over the palm. curl is 0 to 1.
local function thumb(sign: number, across: number, curl: number): { Vector3 }
	local root = Vector3.new(across * 0.9, 0.5, -(1 - across) * 0.8 - 0.1).Unit
	local aims = { root, root:Lerp(THUMB_OVER, curl * 0.6).Unit, root:Lerp(THUMB_OVER, curl).Unit }
	for joint, aim in aims do
		aims[joint] = Vector3.new(aim.X * sign, aim.Y, aim.Z)
	end
	return aims
end

-- One shape for both hands. Fingers left out copy the one before.
local function shape(across: number, curl: number, spread: number, ...: { number }): Hands
	local bends = { ... }
	local hands = {}
	for name, sign in { Right = 1, Left = -1 } do
		local digits = { Pulgar = thumb(sign, across, curl) }
		for index, bone in FINGERS do
			digits[bone] = finger(sign, bends[math.min(index, #bends)], SPREADS[index] * spread)
		end
		hands[name] = digits
	end
	return hands :: any
end

local CUP = shape(0.15, 0.2, 0.12, { 15, 20, 15 }) -- open under the falling cards
local DEALER = shape(0.35, 0.8, 0.05, { 8, 8, 55 }) -- the deck lying in the hand
local BOWED = shape(0.7, 0.3, 0.05, { 25, 30, 25 }) -- squeezing the deck into a bow
local SQUEEZED = shape(0.9, 0.5, 0.03, { 45, 50, 35 }) -- the last cards leaving
local LOOSE = shape(0.3, 0.2, 0.1, { 12, 15, 10 })
local EDGE = shape(0.8, 0.2, 0.04, { 22, 14, 10 }) -- pinching the deck stood on its edge
local CUT = shape(0.3, 0.1, 0.08, { 2, 3, 3 }, { 28, 18, 12 }) -- the thumb lifts and the first finger kicks out
local SPLAY = shape(0.1, 0, 0.3, { 0, 5, 5 }, { 8, 8, 5 }, { 14, 10, 8 }, { 20, 12, 10 }) -- letting the half spin
local FLAT = shape(0.4, 0.7, 0.06, { 10, 12, 40 })
local THUMB_BACK = shape(0.05, 0.1, 0.1, { 10, 10, 20 }) -- wound up to push the fan
local FANNED = shape(0.75, 0.6, 0.28, { 4, 4, 2 }, { 6, 5, 3 }, { 8, 6, 4 }, { 10, 8, 5 }) -- thumb across, fingers wide behind
local CLOSING = shape(0.6, 0.4, 0.05, { 35, 40, 30 }) -- sweeping the fan shut

local RIGHT_FINGERS: { FingerKey } = {
	{ at = 0, shape = BOWED },
	{ at = SPRING_FROM, shape = BOWED },
	{ at = SPRING_TO, shape = SQUEEZED },
	{ at = 1.08, shape = LOOSE },
	{ at = 1.35, shape = CUP },
	{ at = 1.6, shape = EDGE },
	{ at = CUT_AT - 0.05, shape = EDGE },
	{ at = 2.35, shape = CUT },
	{ at = 2.5, shape = EDGE },
	{ at = 2.72, shape = SPLAY },
	{ at = 3.0, shape = FLAT },
	{ at = 3.2, shape = THUMB_BACK },
	{ at = 3.65, shape = FANNED },
	{ at = 4.1, shape = FANNED },
	{ at = 4.4, shape = CLOSING },
	{ at = JOINED_AT, shape = EDGE },
	{ at = 5.05, shape = LOOSE },
	{ at = LENGTH, shape = BOWED },
}
local LEFT_FINGERS: { FingerKey } = {
	{ at = 0, shape = CUP },
	{ at = 1.0, shape = CUP },
	{ at = 1.2, shape = DEALER },
	{ at = 1.6, shape = EDGE },
	{ at = CUT_AT - 0.05, shape = EDGE },
	{ at = 2.35, shape = CUT },
	{ at = 2.6, shape = EDGE },
	{ at = 3.25, shape = EDGE },
	{ at = 3.5, shape = BOWED },
	{ at = 3.8, shape = EDGE },
	{ at = 4.3, shape = EDGE },
	{ at = 4.6, shape = CUP },
	{ at = 4.85, shape = DEALER },
	{ at = LENGTH, shape = DEALER },
}

-- One hand's fingers at a time, each finger a touch behind the one before it.
local function fingersAt(keys: { FingerKey }, side: string, at: number): Shape
	local digits = {}
	for bone, lag in LAGS do
		local when = at - lag
		local aims = (keys[#keys].shape :: any)[side][bone]
		if when <= keys[1].at then
			aims = (keys[1].shape :: any)[side][bone]
		else
			for index = 2, #keys do
				local to = keys[index]
				if when <= to.at then
					local from = keys[index - 1]
					local share = smooth((when - from.at) / (to.at - from.at))
					local before, after = (from.shape :: any)[side][bone], (to.shape :: any)[side][bone]
					aims = {}
					for joint, aim in before do
						aims[joint] = aim:Lerp(after[joint], share).Unit
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

-- Every card, what each hand holds and how its fingers sit, relative to the camera, after elapsed seconds. It holds
-- its end.
-- Cards 1 to HALF are the right hand's half, bottom up, and card HALF ends face up on top of the deck.
function CardFlourish.at(elapsed: number): Pose
	local at = math.clamp(elapsed, 0, LENGTH)
	local cards = table.create(COUNT)
	if at < SPRING_TO + FLIGHT then
		for index = 1, COUNT do
			cards[index] = sprung(index, at)
		end
	else
		local leftHalf, rightHalf
		if at < CUT_AT then
			rightHalf = frameOf(sample(DECK, at))
			leftHalf = rightHalf * CFrame.new(0, HALF * THICKNESS, 0)
		else
			leftHalf = frameOf(sample(LEFT_HALF, at))
			rightHalf = frameOf(sample(RIGHT_HALF, at))
		end
		local open = sample(FAN, at).x
		for index = 1, HALF do
			cards[index] = fanned(rightHalf, index, open)
			cards[HALF + index] = leftHalf * CFrame.new(0, (index - 1) * THICKNESS, 0)
		end
	end
	return {
		cards = cards,
		right = frameOf(sample(RIGHT_HAND, at)),
		left = frameOf(sample(LEFT_HAND, at)),
		fingers = { Right = fingersAt(RIGHT_FINGERS, "Right", at), Left = fingersAt(LEFT_FINGERS, "Left", at) },
	}
end

return CardFlourish
