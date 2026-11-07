-- Applies the mouse sensitivity settings. Longscope's setting multiplies the normal one while scoped.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local PlayerSettings = require(script.Parent.PlayerSettings)

local player = Players.LocalPlayer

local function apply()
	local settings = PlayerSettings.get()
	local scoped = player:GetAttribute("AimFov") ~= nil
	UserInputService.MouseDeltaSensitivity = settings.sensitivity * (if scoped then settings.scopeSensitivity else 1)
end

PlayerSettings.changed:Connect(apply)
player:GetAttributeChangedSignal("AimFov"):Connect(apply)
apply()
