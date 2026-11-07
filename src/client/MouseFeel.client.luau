-- Applies the mouse sensitivity settings. Longscope's setting multiplies the normal one while scoped.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local PlayerSettings = require(script.Parent.PlayerSettings)

local player = Players.LocalPlayer
local SCOPE_FOV = 40 -- aiming this tight is looking through a scope; iron sights keep the normal feel

local function apply()
	local settings = PlayerSettings.get()
	local aimFov = player:GetAttribute("AimFov")
	local scoped = aimFov ~= nil and aimFov <= SCOPE_FOV
	UserInputService.MouseDeltaSensitivity = settings.sensitivity * (if scoped then settings.scopeSensitivity else 1)
end

PlayerSettings.changed:Connect(apply)
player:GetAttributeChangedSignal("AimFov"):Connect(apply)
apply()
