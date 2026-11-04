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

return Input
