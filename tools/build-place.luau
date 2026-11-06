--[[
	Builds a playable place file of the game: the code from this repo, plus the place content
	(models, lighting and its effects) that lives in the Fridae Studios group's place.

	  lune run tools/build-place [base.rbxl]

	With a base place (the group's place saved as a file), the base is kept and only the code
	Rojo manages is replaced. Without one, the code build gets the models and lighting effects from
	the local working copies in assets/models/ (exported from the place; git ignores them).
	Writes build/SplitDeck.rbxl.
]]
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local CODE_BUILD = "build/SplitDeck-code.rbxl"
local OUTPUT = "build/SplitDeck.rbxl"

-- Every instance default.project.json syncs, as service and path below it.
local CODE = {
	{ "ReplicatedStorage", { "CardCore" } },
	{ "ReplicatedStorage", { "Movement" } },
	{ "ReplicatedStorage", { "Guns" } },
	{ "ServerScriptService", { "CardCoreServer" } },
	{ "StarterPlayer", { "StarterPlayerScripts", "CardCoreClient" } },
	{ "StarterPlayer", { "StarterCharacterScripts", "Health" } },
}
local PROPERTIES = {
	{ "Workspace", "Gravity" },
	{ "Workspace", "StreamingEnabled" },
	{ "StarterPlayer", "CameraMode" },
}
-- Place content for a build without a base: model file, service, then path of the parent.
local LOCAL_CONTENT = {
	{ "assets/models/GunModels.rbxm", "ReplicatedStorage", {} },
	{ "assets/models/ColorGrading.rbxm", "Lighting", {} },
	{ "assets/models/Bloom.rbxm", "Lighting", {} },
}
-- The group place's lighting, read from it on 2026-11-05. Only used without a base.
local LIGHTING = {
	LightingStyle = roblox.Enum.LightingStyle.Soft,
	PrioritizeLightingQuality = false,
	Ambient = roblox.Color3.fromRGB(128, 128, 128),
	OutdoorAmbient = roblox.Color3.fromRGB(128, 128, 128),
	Brightness = 1.98125,
	ClockTime = 14,
	GeographicLatitude = 41.7333,
	EnvironmentDiffuseScale = 0,
	EnvironmentSpecularScale = 0,
	GlobalShadows = false,
	FogColor = roblox.Color3.fromRGB(191, 191, 191),
	FogEnd = 100000,
}

local function find(root: any, path: { string }): any
	local current = root
	for _, name in path do
		current = current and current:FindFirstChild(name)
	end
	return current
end

fs.writeDir("build")
local built = process.exec("rojo", { "build", "-o", CODE_BUILD })
if not built.ok then
	error("rojo build failed:\n" .. built.stderr)
end
local code = roblox.deserializePlace(fs.readFile(CODE_BUILD))

local basePath = process.args[1]
local place
if basePath then
	place = roblox.deserializePlace(fs.readFile(basePath))
	for _, entry in CODE do
		local service, path = entry[1], entry[2]
		local parentPath = table.clone(path)
		local name = table.remove(parentPath)
		local parent = find(place:GetService(service), parentPath)
		if not parent then
			error(`the base place has no {service}.{table.concat(parentPath, ".")}`)
		end
		local old = parent:FindFirstChild(name)
		if old then
			old:Destroy()
		end
		find(code:GetService(service), path):Clone().Parent = parent
	end
	for _, entry in PROPERTIES do
		local service, property = entry[1], entry[2]
		place:GetService(service)[property] = code:GetService(service)[property]
	end
	print(`Took the place content from {basePath}`)
else
	place = code
	for _, entry in LOCAL_CONTENT do
		local file, service, parentPath = entry[1], entry[2], entry[3]
		if fs.isFile(file) then
			local parent = find(place:GetService(service), parentPath)
			for _, root in roblox.deserializeModel(fs.readFile(file)) do
				local old = parent:FindFirstChild(root.Name)
				if old then
					old:Destroy()
				end
				root.Parent = parent
			end
		else
			print(`Missing {file}, so the build has no {service} content from it`)
		end
	end
	local lighting = place:GetService("Lighting")
	for property, value in LIGHTING do
		lighting[property] = value
	end
	print("Took the place content from assets/models/")
end

fs.writeFile(OUTPUT, roblox.serializePlace(place))
fs.removeFile(CODE_BUILD)
print(`Wrote {OUTPUT}`)
