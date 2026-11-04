-- The only module that reads keys, so touch and controller can be added later.
local UserInputService = game:GetService("UserInputService")

local Input = {}

function Input.read(): { sprint: boolean, crouch: boolean, jump: boolean }
	if UserInputService:GetFocusedTextBox() then
		return { sprint = false, crouch = false, jump = false }
	end
	return {
		sprint = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift),
		crouch = UserInputService:IsKeyDown(Enum.KeyCode.C)
			or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl),
		jump = UserInputService:IsKeyDown(Enum.KeyCode.Space),
	}
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
	return {
		fire = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1),
		aim = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2),
		reload = UserInputService:IsKeyDown(Enum.KeyCode.R),
		primary = UserInputService:IsKeyDown(Enum.KeyCode.One),
		sidearm = UserInputService:IsKeyDown(Enum.KeyCode.Two),
		nextClass = UserInputService:IsKeyDown(Enum.KeyCode.B),
		nextRifle = UserInputService:IsKeyDown(Enum.KeyCode.N),
	}
end

return Input
