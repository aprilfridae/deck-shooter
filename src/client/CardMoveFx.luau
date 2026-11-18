-- What the world and the speakers do at each moment of a card's use in first person (GunView plays the hands):
-- `started` when the card is used, `release` when a card leaves the hand (a thrown card, or Split's copy), and
-- `impact` when the hand hits something (Bulwark's slap). Each card that does anything of its own is listed here;
-- the rest are crushed, with the crush sound.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CardFlourish = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("CardFlourish"))
local CardThrowFx = require(script.Parent.CardThrowFx)
local FlashFx = require(script.Parent.FlashFx)
local GunAudio = require(script.Parent.GunAudio)
local RewindFx = require(script.Parent.RewindFx)
local SplitFx = require(script.Parent.SplitFx)

local CardMoveFx = {}

-- Plays `sound` `delay` seconds from now, if the same use is still going.
local current = 0
local function later(delay: number, sound: () -> ())
	local use = current
	task.delay(delay, function()
		if use == current then
			sound()
		end
	end)
end

function CardMoveFx.started(cardId: string?)
	current += 1
	if cardId == "switchback" or cardId == "flashpoint" or cardId == "bulwark" then
		GunAudio.stopCards() -- nothing is crushed
	elseif cardId == "split" then
		GunAudio.stopCards()
		later(0.42, GunAudio.playCardCrush) -- the hand closes on the card left after the copy goes
	elseif cardId == "rewind" then
		GunAudio.stopCards()
		RewindFx.windUp(CardFlourish.REWIND_SNAP)
		later(CardFlourish.REWIND_SNAP - 0.06, GunAudio.playCardCrush)
	else
		GunAudio.playCardCrush()
	end
end

-- A card has left the hand: `card` is where it was and how it was turned, `size` its size, `look` the camera.
function CardMoveFx.release(cardId: string?, card: CFrame, size: Vector3, look: CFrame)
	if cardId == "switchback" then
		CardThrowFx.release(card, size, look)
	elseif cardId == "flashpoint" then
		FlashFx.release(card, size, look)
	elseif cardId == "split" then
		SplitFx.release(card, size, look)
	end
end

-- The hand hit something. The view isn't shaken: the camera keeps any turn given to it, so it would move the aim.
function CardMoveFx.impact(cardId: string?)
	if cardId == "bulwark" then
		GunAudio.playLand(true) -- the hard landing's thud, until Bulwark has its own (docs/sound-list.md)
	end
end

return CardMoveFx
