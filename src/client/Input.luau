-- The only module that reads keys, so touch and controller can be added later.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local MenuState = require(Guns:WaitForChild("MenuState"))
local Zones = require(Guns:WaitForChild("Zones"))
local PlayerSettings = require(script.Parent.PlayerSettings)

local player = Players.LocalPlayer

local Input = {}

local function pressed(keyName: string): boolean
	if string.sub(keyName, 1, 5) == "Mouse" then
		return UserInputService:IsMouseButtonPressed(Enum.UserInputType[keyName])
	end
	return UserInputService:IsKeyDown(Enum.KeyCode[keyName])
end

function Input.read(): { sprint: boolean, crouch: boolean, jump: boolean }
	if UserInputService:GetFocusedTextBox() then
		return { sprint = false, crouch = false, jump = false }
	end
	local keys = PlayerSettings.get().keys
	return MenuState.filter(MenuState.shared, {
		sprint = pressed(keys.sprint),
		crouch = pressed(keys.crouch) or pressed(keys.crouchAlt),
		jump = pressed(keys.jump),
	})
end

function Input.readGun(): { [string]: boolean }
	if UserInputService:GetFocusedTextBox() then
		return {
			fire = false,
			aim = false,
			reload = false,
			primary = false,
			sidearm = false,
			nextClass = false,
			nextRifle = false,
		}
	end
	-- Guns and cards are off in the Outpost.
	local keys = PlayerSettings.get().keys
	return Zones.filter(Zones.of(player), MenuState.filter(MenuState.shared, {
		fire = pressed(keys.fire),
		aim = pressed(keys.aim),
		reload = pressed(keys.reload),
		primary = pressed(keys.primary),
		sidearm = pressed(keys.sidearm),
		nextClass = UserInputService:IsKeyDown(Enum.KeyCode.B),
		nextRifle = UserInputService:IsKeyDown(Enum.KeyCode.N),
	}))
end

-- The radio's keys work everywhere but the title screen.
function Input.readRadio(): { next: boolean, previous: boolean, toggle: boolean }
	if UserInputService:GetFocusedTextBox() or MenuState.isOpen(MenuState.shared) then
		return { next = false, previous = false, toggle = false }
	end
	local keys = PlayerSettings.get().keys
	return {
		next = pressed(keys.radioNext),
		previous = pressed(keys.radioPrevious),
		toggle = pressed(keys.radioToggle),
	}
end

function Input.readAbility(): { [string]: boolean }
	if UserInputService:GetFocusedTextBox() then
		return { slot1 = false, slot2 = false, slot3 = false, use = false, cycle = false, testDeck = false, testTier = false }
	end
	local keys = PlayerSettings.get().keys
	return Zones.filter(Zones.of(player), MenuState.filter(MenuState.shared, {
		slot1 = pressed(keys.slot1),
		slot2 = pressed(keys.slot2),
		slot3 = pressed(keys.slot3),
		use = pressed(keys.fire),
		cycle = pressed(keys.aim), -- with a card out there's no aiming, so the aim key turns to the next card
		testDeck = UserInputService:IsKeyDown(Enum.KeyCode.T),
		testTier = UserInputService:IsKeyDown(Enum.KeyCode.Y),
	}))
end

return Input
