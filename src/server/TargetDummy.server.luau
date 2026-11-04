-- A standing target with real health, so guns can be tested alone. Remove with the test room.
local Players = game:GetService("Players")

local GunTargets = require(script.Parent.GunTargets)

local RESPAWN_SECONDS = 3
local POSITION = CFrame.new(-20, 3.2, 10)

local function spawnDummy()
	local description = Instance.new("HumanoidDescription")
	local dummy = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	dummy.Name = "TargetDummy"
	dummy:PivotTo(POSITION)
	dummy.Parent = workspace

	local target = GunTargets.add(dummy, nil)
	if not target then
		dummy:Destroy()
		return
	end
	target.humanoid.Died:Connect(function()
		task.wait(RESPAWN_SECONDS)
		dummy:Destroy()
		spawnDummy()
	end)
end

spawnDummy()
