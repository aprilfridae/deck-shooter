-- The only module that reads keys, so touch and controller can be added later.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local MenuState = require(ReplicatedStorage:WaitForChild("Guns"):WaitForChild("MenuState"))

local Input = {}

function Input.read(): { sprint: boolean, crouch: boolean, jump: boolean }
	if UserInputService:GetFocusedTextBox() then
		return { sprint = false, crouch = false, jump = false }
	end
	return MenuState.filter(MenuState.shared, {
		sprint = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift),
		crouch = UserInputService:IsKeyDown(Enum.KeyCode.C)
			or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl),
		jump = UserInputService:IsKeyDown(Enum.KeyCode.Space),
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
	return MenuState.filter(MenuState.shared, {
		fire = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1),
		aim = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2),
		reload = UserInputService:IsKeyDown(Enum.KeyCode.R),
		primary = UserInputService:IsKeyDown(Enum.KeyCode.One),
		sidearm = UserInputService:IsKeyDown(Enum.KeyCode.Two),
		nextClass = UserInputService:IsKeyDown(Enum.KeyCode.B),
		nextRifle = UserInputService:IsKeyDown(Enum.KeyCode.N),
	})
end

function Input.readAbility(): { [string]: boolean }
	if UserInputService:GetFocusedTextBox() then
		return { slot1 = false, slot2 = false, slot3 = false, use = false, testDeck = false, testTier = false }
	end
	return MenuState.filter(MenuState.shared, {
		slot1 = UserInputService:IsKeyDown(Enum.KeyCode.Three),
		slot2 = UserInputService:IsKeyDown(Enum.KeyCode.Four),
		slot3 = UserInputService:IsKeyDown(Enum.KeyCode.Five),
		use = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1),
		testDeck = UserInputService:IsKeyDown(Enum.KeyCode.T),
		testTier = UserInputService:IsKeyDown(Enum.KeyCode.Y),
	})
end

return Input
