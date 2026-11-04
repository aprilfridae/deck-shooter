-- Each player's guns, shared by the gun and ability servers.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weapon = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("Weapon"))

local loadouts: { [Player]: Weapon.Loadout } = {}

return loadouts
