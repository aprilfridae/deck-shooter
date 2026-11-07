-- The three volume groups every sound belongs to.
local SoundService = game:GetService("SoundService")

local PlayerSettings = require(script.Parent.PlayerSettings)

local function group(name: string): SoundGroup
	local soundGroup = Instance.new("SoundGroup")
	soundGroup.Name = name
	soundGroup.Parent = SoundService
	return soundGroup
end

local SoundGroups = {
	music = group("Music"),
	game = group("Game"),
	menu = group("Menu"),
}

local function apply()
	local settings = PlayerSettings.get()
	SoundGroups.music.Volume = settings.music
	SoundGroups.game.Volume = settings.game
	SoundGroups.menu.Volume = settings.menu
end

PlayerSettings.changed:Connect(apply)
apply()

return SoundGroups
