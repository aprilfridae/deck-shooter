-- The radio: your own music in the Outpost and on maps (docs/specs/radio.md). It's personal: it runs here on
-- the client only, and nobody else hears it. It starts after PLAY on the title screen, shuffles through
-- RadioTracks, and keeps going through travel, death and respawn. Next, previous and on/off are keys from the
-- settings; the volume is the Music slider.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local MenuState = require(Guns:WaitForChild("MenuState"))
local Radio = require(Guns:WaitForChild("Radio"))
local RadioTracks = require(Guns:WaitForChild("RadioTracks"))
local Input = require(script.Parent.Input)
local PlayerSettings = require(script.Parent.PlayerSettings)
local RadioHud = require(script.Parent.RadioHud)
local SoundGroups = require(script.Parent.SoundGroups)

local VOLUME = 0.5 -- under the guns and footsteps at the same slider setting
local FADE_IN_SECONDS = 1.2 -- the first track, as the menu music goes
local START_DELAY = 0.8 -- after PLAY, so the menu music has faded
local LOAD_TIMEOUT = 10 -- seconds a track gets to load before it's skipped
local RETRY_SECONDS = 30 -- once every track has failed, how long before trying again
local BARS_EVERY = 1 / 20

local player = Players.LocalPlayer
local state = Radio.new(#RadioTracks)
local random = Random.new()
local hud = RadioHud.new()
hud:setVisible(false)

local sound = Instance.new("Sound")
sound.Name = "Radio"
sound.SoundGroup = SoundGroups.music
sound.Volume = VOLUME
sound.Parent = SoundService

local started = false -- PLAY has been pressed and the first track asked for
local startAt: number? = nil
local on = PlayerSettings.get().radio ~= 0
local loadingSince: number? = nil -- when the current track was asked for, until it has loaded
local failures = 0 -- tracks in a row that wouldn't load
local previous = { next = false, previous = false, toggle = false }

local function roll(n: number): number
	return random:NextInteger(1, n)
end

local function play(index: number?)
	if not index then
		return
	end
	local track = RadioTracks[index]
	sound:Stop()
	sound.SoundId = track.sound
	sound.TimePosition = 0
	sound:Play()
	loadingSince = os.clock()
	hud:show(track.title, track.artist)
end

local function nextTrack()
	play(Radio.next(state, roll))
end

local function setOn(value: boolean)
	if value == on then
		return
	end
	on = value
	if not started then
		return
	end
	if on then
		local index = Radio.current(state)
		if index then
			sound:Resume()
			hud:show(RadioTracks[index].title, RadioTracks[index].artist)
		else
			nextTrack()
		end
	else
		sound:Pause()
		loadingSince = nil
		hud:showOff()
	end
end

sound.Ended:Connect(function()
	if on then
		failures = 0
		nextTrack()
	end
end)

-- The saved choice can arrive after the radio has started.
PlayerSettings.changed:Connect(function()
	setOn(PlayerSettings.get().radio ~= 0)
end)

local function alive(): boolean
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local barsWaited = 0
RunService.RenderStepped:Connect(function(dt: number)
	local titleUp = MenuState.isOpen(MenuState.shared)
	hud:setVisible(started and not titleUp and alive())
	if not started then
		if titleUp then
			return
		end
		startAt = startAt or os.clock() + START_DELAY
		if os.clock() < startAt then
			return
		end
		started = true
		if on then
			sound.Volume = 0
			TweenService:Create(sound, TweenInfo.new(FADE_IN_SECONDS), { Volume = VOLUME }):Play()
			nextTrack()
		else
			hud:showOff()
		end
	end

	local keys = Input.readRadio()
	if keys.toggle and not previous.toggle then
		PlayerSettings.set({ radio = if on then 0 else 1 })
		PlayerSettings.send()
	elseif on and keys.next and not previous.next then
		failures = 0
		nextTrack()
	elseif on and keys.previous and not previous.previous then
		failures = 0
		play(Radio.previous(state, sound.TimePosition))
	end
	previous = keys

	-- A track that won't load (still in moderation, or taken down) is skipped. If none will, wait and retry.
	if on and loadingSince then
		if sound.IsLoaded then
			loadingSince = nil
			failures = 0
		elseif os.clock() - loadingSince > LOAD_TIMEOUT then
			failures += 1
			if failures < #RadioTracks then
				nextTrack()
			else
				failures = 0
				loadingSince = os.clock() + RETRY_SECONDS - LOAD_TIMEOUT
			end
		end
	end

	barsWaited += dt
	if barsWaited >= BARS_EVERY then
		hud:update(barsWaited, if on and sound.IsPlaying then sound.PlaybackLoudness else 0)
		barsWaited = 0
	end
end)
