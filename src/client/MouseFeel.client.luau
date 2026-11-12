-- Applies the mouse sensitivity settings. Scoped, the view turns exactly as far for the same mouse movement as
-- it does unscoped, times the Longscope setting: at 1 the two are the same. (Until 2026-11-10 the mouse also
-- slowed by the zoom, to cover the same share of the screen; River wanted the turn itself to match.)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local PlayerSettings = require(script.Parent.PlayerSettings)

local player = Players.LocalPlayer

local function apply()
	local settings = PlayerSettings.get()
	local aimFov = player:GetAttribute("AimFov")
	local scale = if aimFov then settings.scopeSensitivity else 1
	UserInputService.MouseDeltaSensitivity = settings.sensitivity * scale
end

PlayerSettings.changed:Connect(apply)
player:GetAttributeChangedSignal("AimFov"):Connect(apply)
apply()
