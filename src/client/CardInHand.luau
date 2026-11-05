-- The one card hand this player has, shared by the abilities and guns scripts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CardHand = require(ReplicatedStorage:WaitForChild("CardCore"):WaitForChild("CardHand"))

return CardHand.new()
