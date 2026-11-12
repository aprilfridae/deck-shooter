-- The ability card in the player's hand. The cards key pulls one out, right click turns to the next, and clicking
-- uses it. So does pressing the held card's key again. Only a weapon key or another card's key takes a card out of
-- the hand unused.
local CardHand = {}

function CardHand.new(): { [string]: any }
	-- used counts the cards used so far, and turns the times the held card was changed for another. lastUsed is the
	-- slot of the last card used, so the view can tell which card's animation to play.
	return { slot = nil, waitForRelease = false, used = 0, turns = 0, lastUsed = nil }
end

-- A click: uses the held card, skipping whatever is left of the animation. Returns the slot used.
function CardHand.click(hand: any): number?
	local slot = hand.slot
	if slot then
		hand.slot = nil
		hand.lastUsed = slot
		hand.waitForRelease = true
		hand.used += 1
	end
	return slot
end

-- A key press: pulls out a ready card or swaps to it. The key of the card already held uses it, the same as a
-- click (River, 2026-11-12: "if i press a number twice it uses the card"). Returns the slot used, if one was.
function CardHand.press(hand: any, slot: number, ready: boolean): number?
	if hand.slot == slot then
		return CardHand.click(hand)
	elseif ready then
		if hand.slot then
			hand.turns += 1
		end
		hand.slot = slot
	end
	return nil
end

-- The cards key: pulls out the first ready card. With a card already out it uses that card. ready is whether each
-- slot's card is. Returns the slot used, if one was.
function CardHand.open(hand: any, ready: { boolean }): number?
	if hand.slot then
		return CardHand.click(hand)
	end
	for slot, isReady in ready do
		if isReady then
			hand.slot = slot
			break
		end
	end
	return nil
end

-- Turns to the next ready card after the held one, round and round.
function CardHand.cycle(hand: any, ready: { boolean })
	local slot = hand.slot
	if not slot then
		return
	end
	for step = 1, #ready - 1 do
		local nextSlot = (slot - 1 + step) % #ready + 1
		if ready[nextSlot] then
			hand.slot = nextSlot
			hand.turns += 1
			return
		end
	end
end

function CardHand.putAway(hand: any)
	hand.slot = nil
end

-- The gun stays quiet with a card out, and until the click that used a card is let go.
function CardHand.blocksFire(hand: any, fireHeld: boolean): boolean
	if hand.slot then
		return true
	end
	if hand.waitForRelease and not fireHeld then
		hand.waitForRelease = false
	end
	return hand.waitForRelease
end

return CardHand
