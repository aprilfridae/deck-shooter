-- The player's settings: volumes, mouse, field of view and keys. Saved with their profile.
-- Keys are Enum.KeyCode or Enum.UserInputType names.
export type Settings = {
	music: number,
	game: number,
	menu: number,
	sensitivity: number,
	scopeSensitivity: number,
	fieldOfView: number,
	radio: number, -- 1 on, 0 off
	keys: { [string]: string },
}

local Settings = {}

-- Listed in this order on the Settings panel.
Settings.actions = {
	-- No sprint key: moving is always sprinting. Crouch is also the slide key, and River wanted it on Left Shift
	-- (2026-11-11); it was C, with Left Ctrl as the second.
	{ id = "crouch", label = "CROUCH", key = "LeftShift" },
	{ id = "crouchAlt", label = "CROUCH 2", key = "C" },
	{ id = "jump", label = "JUMP", key = "Space" },
	{ id = "reload", label = "RELOAD", key = "R" },
	{ id = "primary", label = "PRIMARY", key = "One" },
	{ id = "sidearm", label = "SIDEARM", key = "Two" },
	{ id = "slot1", label = "CARD 1", key = "Three" },
	{ id = "slot2", label = "CARD 2", key = "Four" },
	{ id = "slot3", label = "CARD 3", key = "Five" },
	{ id = "fire", label = "FIRE", key = "MouseButton1" },
	{ id = "aim", label = "AIM", key = "MouseButton2" },
	{ id = "radioNext", label = "RADIO NEXT", key = "Period" },
	{ id = "radioPrevious", label = "RADIO BACK", key = "Comma" },
	{ id = "radioToggle", label = "RADIO ON OFF", key = "M" },
}

local RANGES = {
	music = { 0, 1, 1 },
	game = { 0, 1, 1 },
	menu = { 0, 1, 1 },
	sensitivity = { 0.1, 3, 1 },
	scopeSensitivity = { 0.1, 2, 1 },
	fieldOfView = { 60, 100, 80 },
	radio = { 0, 1, 1 },
}

-- Roblox moves the player with W, A, S and D, and B, N, T, Y, P and O are test keys (P is the view from behind in
-- the test room, O turns it to the front). Slash opens chat.
local RESERVED = { W = true, A = true, S = true, D = true, B = true, N = true, T = true, Y = true, P = true, O = true, Slash = true }

local DIGITS = {
	Zero = "0",
	One = "1",
	Two = "2",
	Three = "3",
	Four = "4",
	Five = "5",
	Six = "6",
	Seven = "7",
	Eight = "8",
	Nine = "9",
}

local LABELS = {
	LeftShift = "L SHIFT",
	RightShift = "R SHIFT",
	LeftControl = "L CTRL",
	RightControl = "R CTRL",
	LeftAlt = "L ALT",
	RightAlt = "R ALT",
	MouseButton1 = "MOUSE 1",
	MouseButton2 = "MOUSE 2",
}

local BINDABLE: { [string]: boolean } = {}
for _, name in {
	"Space", "Tab", "Return", "BackSpace", "CapsLock", "Up", "Down", "Left", "Right", "Insert", "Delete",
	"Home", "End", "PageUp", "PageDown", "Comma", "Period", "Semicolon", "Quote", "Minus", "Equals",
	"LeftBracket", "RightBracket", "BackSlash", "Backquote",
} do
	BINDABLE[name] = true
end
for name in DIGITS do
	BINDABLE[name] = true
	BINDABLE[`Keypad{name}`] = true
end
for name in LABELS do
	BINDABLE[name] = true
end
for code = string.byte("A"), string.byte("Z") do
	BINDABLE[string.char(code)] = true
end
for number = 1, 12 do
	BINDABLE[`F{number}`] = true
end
for name in RESERVED do
	BINDABLE[name] = nil
end

local function defaultKeys(): { [string]: string }
	local keys = {}
	for _, action in Settings.actions do
		keys[action.id] = action.key
	end
	return keys
end

function Settings.new(): Settings
	return {
		music = RANGES.music[3],
		game = RANGES.game[3],
		menu = RANGES.menu[3],
		sensitivity = RANGES.sensitivity[3],
		scopeSensitivity = RANGES.scopeSensitivity[3],
		fieldOfView = RANGES.fieldOfView[3],
		radio = RANGES.radio[3],
		keys = defaultKeys(),
	}
end

local function cleanKeys(raw: any): { [string]: string }
	local keys = defaultKeys()
	if type(raw) ~= "table" then
		return keys
	end
	-- A save from when sprint had a key. If it still has that time's defaults, crouch moves to the new ones;
	-- either way Left Shift is free again once sprint is gone.
	if raw.sprint ~= nil then
		raw = table.clone(raw)
		if raw.sprint == "LeftShift" and raw.crouch == "C" and raw.crouchAlt == "LeftControl" then
			raw.crouch, raw.crouchAlt = nil, nil
		end
	end
	local used = {}
	for _, action in Settings.actions do
		local key = raw[action.id]
		if type(key) == "string" and BINDABLE[key] then
			keys[action.id] = key
		end
		if used[keys[action.id]] then
			return defaultKeys()
		end
		used[keys[action.id]] = true
	end
	return keys
end

-- Returns a full, legal set of settings. Each bad value takes its default.
function Settings.clean(raw: any): Settings
	local settings = Settings.new()
	if type(raw) ~= "table" then
		return settings
	end
	for field, range in RANGES do
		local value = raw[field]
		if type(value) == "number" and value >= range[1] and value <= range[2] then
			settings[field] = value
		end
	end
	settings.keys = cleanKeys(raw.keys)
	return settings
end

-- Lays changes made before the save arrived over the saved settings.
function Settings.merge(saved: Settings, changes: { [string]: any }): Settings
	local merged = table.clone(saved)
	for field, value in changes do
		merged[field] = value
	end
	return Settings.clean(merged)
end

function Settings.range(field: string): (number, number)
	local range = RANGES[field]
	return range[1], range[2]
end

-- Returns new keys with the action on this key, or nil if that can't be done.
-- An action already on the key takes the old key, so nothing is left unbound.
function Settings.rebind(keys: { [string]: string }, action: string, keyName: string): { [string]: string }?
	if keys[action] == nil or not BINDABLE[keyName] then
		return nil
	end
	local result = table.clone(keys)
	for other, key in keys do
		if key == keyName then
			result[other] = keys[action]
		end
	end
	result[action] = keyName
	return result
end

function Settings.keyLabel(keyName: string): string
	return DIGITS[keyName] or LABELS[keyName] or string.upper(keyName)
end

return Settings
