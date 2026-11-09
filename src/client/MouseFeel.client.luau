-- Applies the mouse sensitivity settings. While scoped, the mouse slows by the zoom, so a mouse movement moves the
-- crosshair across the same amount of the screen as it does unscoped. Longscope's setting multiplies on top.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local PlayerSettings = require(script.Parent.PlayerSettings)

local player = Players.LocalPlayer

-- How much a zoomed view shrinks things on screen against the player's normal view.
local function zoomScale(fov: number, normalFov: number): number
	return math.tan(math.rad(fov) / 2) / math.tan(math.rad(normalFov) / 2)
end

local function apply()
	local settings = PlayerSettings.get()
	local aimFov = player:GetAttribute("AimFov")
	local scale = if aimFov then zoomScale(aimFov, settings.fieldOfView) * settings.scopeSensitivity else 1
	UserInputService.MouseDeltaSensitivity = settings.sensitivity * scale
end

PlayerSettings.changed:Connect(apply)
player:GetAttributeChangedSignal("AimFov"):Connect(apply)
apply()
