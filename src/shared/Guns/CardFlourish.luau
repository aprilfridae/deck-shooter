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

local CardFlourish = {
	COUNT = COUNT,
	HALF = HALF,
	LENGTH = LENGTH,
	CARD_SIZE = CARD_SIZE,
}

export type Pose = { cards: { CFrame }, right: CFrame, left: CFrame }

-- Every card and what each hand holds, relative to the camera, after elapsed seconds. It holds its end.
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
	return { cards = cards, right = frameOf(sample(RIGHT_HAND, at)), left = frameOf(sample(LEFT_HAND, at)) }
end

return CardFlourish
