-- The ability card in the player's hand. Pressing a card's key pulls it out, and clicking uses it.
local CardHand = {}

function CardHand.new(): { [string]: any }
	return { slot = nil, waitForRelease = false }
end

-- A key press: pulls out a ready card, swaps to it, or puts away the one already held.
function CardHand.press(hand: any, slot: number, ready: boolean)
	if hand.slot == slot then
		hand.slot = nil
	elseif ready then
		hand.slot = slot
	end
end

-- A click: uses the held card, skipping whatever is left of the animation. Returns the slot used.
function CardHand.click(hand: any): number?
	local slot = hand.slot
	if slot then
		hand.slot = nil
		hand.waitForRelease = true
	end
	return slot
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
