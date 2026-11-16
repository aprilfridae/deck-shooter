-- A body killed by a gun glitches away, like dust blowing off in the wind but digital. The body is hidden and a
-- frozen copy of it takes its place, posed as it died. The copy flashes white, then flickers between cyan and white
-- and tears sideways at random heights, with thin scanlines flashing across it, while its parts go one by one,
-- loosely from the top down. Each part blinks for a moment, then collapses flat and wide like an old screen
-- switching off, and leaves as a puff of particles: squares that tear into bands as they go (GlitchPixel) and fine
-- square dust, both drifting away from the shot and up. A headshot's head goes at once. Everyone sees it. Your own
-- body waits a moment first, so the soul sees it drop before it goes. Timings and textures are in KillFx.
-- The server says which body died and who did it with DeathBurst, which also starts the coin burst.
-- To look at it slowly, set the number attribute KillFxSpeed on workspace (0.1 plays it at a tenth of the speed)
-- and clear it afterwards. KillConfirm reads it too.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Guns = ReplicatedStorage:WaitForChild("Guns")
local Palette = require(Guns:WaitForChild("Palette"))
local KillFx = require(Guns:WaitForChild("KillFx"))
local Perf = require(script.Parent.Perf)

local PIXELS = 90 -- glitching squares a whole body leaves as, on a fast machine
local MOTES = 2 -- specks of dust for each square
local HEAD_PIXELS = 2 -- a headshot's head leaves as this many times its share
local WIND = 16 -- studs a second gained each second away from the shot
local MOTE_WIND = 24 -- the dust is lighter and goes faster
local LIFT = 5 -- and up
local SCANLINES = 2 -- flashed across the body on each tear
local SCANLINE_WIDTH = 1.4 -- studs wider than the body
local LINGER = 1.1 -- seconds the last particles take to clear after the body has gone
local LIGHT_BRIGHTNESS = 2
local LIGHT_RANGE = 10
local HOT = Color3.new(1, 1, 1)
local COOL = Palette.DataCyan
-- What a copied part keeps: how it looks. Joints would tie it to the real body, and the rest has no business on it.
local KEEP = {
	Decal = true,
	Texture = true,
	SurfaceAppearance = true,
	SpecialMesh = true,
	Attachment = true,
}

local player = Players.LocalPlayer
local deathRemote = ReplicatedStorage:WaitForChild("GunRemotes"):WaitForChild("DeathBurst") :: RemoteEvent
local random = Random.new()

local folder = Instance.new("Folder")
folder.Name = "KillDerez"
folder.Parent = workspace

-- A part of the body: the real one, which is hidden, and its frozen copy.
type Piece = {
	part: BasePart,
	transparency: number,
	decals: { [Decal]: number },
	ghost: BasePart?,
	frame: CFrame?, -- where the copy stands when nothing is shifting it
	size: Vector3, -- the copy's own size, before it collapses
	height: number, -- 0 at the bottom of the body, 1 at the top
	goneAt: number,
	count: number, -- glitching squares it leaves as
	released: number,
	head: boolean,
}
type Emitters = { holder: BasePart, pixels: ParticleEmitter, motes: ParticleEmitter, scanlines: ParticleEmitter }
type Derez = {
	model: Model,
	startedAt: number,
	wind: Vector3, -- the way the shot was going, flat
	headshot: boolean,
	pieces: { Piece },
	copy: Model?,
	glow: Highlight?,
	anchor: BasePart?,
	light: PointLight?,
	emitters: Emitters?,
	bounds: CFrame?, -- the body's box when it froze
	extent: Vector3?,
	lastStep: number,
}

local derezzes: { Derez } = {}
local started: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local clock = 0
local speed = 1

local function setShown(piece: Piece, shown: boolean)
	piece.part.Transparency = if shown then piece.transparency else 1
	for decal, transparency in piece.decals do
		decal.Transparency = if shown then transparency else 1
	end
end

local function emitter(holder: BasePart, texture: string): ParticleEmitter
	local made = Instance.new("ParticleEmitter")
	made.Texture = texture
	made.Rate = 0
	made.Shape = Enum.ParticleEmitterShape.Box
	made.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	made.LightEmission = 1
	made.LightInfluence = 0
	made.Orientation = Enum.ParticleOrientation.FacingCamera
	made.SpreadAngle = Vector2.new(180, 180)
	made.ZOffset = 0.5
	made.Parent = holder
	return made
end

-- Three emitters for one body, blown the way its shot went. A Box-shaped emitter fills whatever part its holder
-- is moved onto, so one set serves every part.
local function makeEmitters(wind: Vector3): Emitters
	local holder = Instance.new("Part")
	holder.Name = "DerezEmit"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Parent = folder

	local pixels = emitter(holder, KillFx.TEXTURES.pixel)
	pixels.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
	pixels.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	pixels.Lifetime = NumberRange.new(0.3, 0.55)
	pixels.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.34, 0.12),
		NumberSequenceKeypoint.new(1, 0.26, 0.1),
	})
	pixels.Speed = NumberRange.new(1, 4)
	pixels.Drag = 3
	pixels.Acceleration = wind * WIND + Vector3.yAxis * LIFT
	pixels.Brightness = 2
	pixels.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, HOT),
		ColorSequenceKeypoint.new(0.25, COOL),
		ColorSequenceKeypoint.new(1, COOL),
	})
	pixels.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.75, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})

	local motes = emitter(holder, KillFx.TEXTURES.mote)
	motes.Lifetime = NumberRange.new(0.45, 0.9)
	motes.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.14, 0.06),
		NumberSequenceKeypoint.new(0.7, 0.1, 0.04),
		NumberSequenceKeypoint.new(1, 0),
	})
	motes.Speed = NumberRange.new(0.5, 3)
	motes.Drag = 1.5
	motes.Acceleration = wind * MOTE_WIND + Vector3.yAxis * LIFT
	motes.Brightness = 3
	motes.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, HOT),
		ColorSequenceKeypoint.new(0.4, COOL),
		ColorSequenceKeypoint.new(1, COOL),
	})
	motes.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.6, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})

	local scanlines = emitter(holder, KillFx.TEXTURES.scanline)
	scanlines.Lifetime = NumberRange.new(0.05, 0.1)
	scanlines.Speed = NumberRange.new(0)
	scanlines.Brightness = 3
	scanlines.Color = ColorSequence.new(COOL, HOT)
	scanlines.Transparency = NumberSequence.new(0, 1)
	return { holder = holder, pixels = pixels, motes = motes, scanlines = scanlines }
end

-- Lets count squares, and their dust, go from a part, wherever its copy stands now.
local function release(derez: Derez, piece: Piece, count: number)
	local emitters = derez.emitters :: Emitters
	local source = piece.ghost or piece.part
	emitters.holder.Size = piece.size
	emitters.holder.CFrame = source.CFrame
	emitters.pixels:Emit(count)
	emitters.motes:Emit(count * MOTES)
end

-- A tear flashes thin lines across the body at its height.
local function flashScanlines(derez: Derez, height: number)
	local emitters = derez.emitters :: Emitters
	local bounds, extent = derez.bounds :: CFrame, derez.extent :: Vector3
	local width = math.max(extent.X, extent.Z) + SCANLINE_WIDTH
	emitters.scanlines.Size = NumberSequence.new(width)
	emitters.holder.Size = Vector3.new(0.2, extent.Y * 0.15, 0.2)
	emitters.holder.CFrame = bounds + Vector3.yAxis * (height - 0.5) * extent.Y
	emitters.scanlines:Emit(SCANLINES)
end

-- A copy of a part that stays where it is and touches nothing.
local function ghostOf(part: BasePart): BasePart?
	local archivable = part.Archivable
	part.Archivable = true
	local ok, copy = pcall(part.Clone, part)
	part.Archivable = archivable
	if not ok or not copy then
		return nil
	end
	for _, item in copy:GetDescendants() do
		if item.Parent and not KEEP[item.ClassName] then
			item:Destroy()
		end
	end
	copy.Anchored = true
	copy.CanCollide = false
	copy.CanQuery = false
	copy.CanTouch = false
	copy.Massless = true
	copy.CollisionGroup = "Default"
	copy.LocalTransparencyModifier = 0
	return copy
end

-- Swaps the body for its frozen copy and works out when each part goes and how many squares it leaves as.
local function freeze(derez: Derez)
	local copy = Instance.new("Model")
	copy.Name = "Derez"
	local bottom, top = math.huge, -math.huge
	local volumes = {}
	for index, piece in derez.pieces do
		local ghost = ghostOf(piece.part)
		if ghost then
			ghost.Parent = copy
			piece.ghost = ghost
			piece.frame = ghost.CFrame
		end
		piece.size = piece.part.Size
		local y = piece.part.Position.Y
		bottom, top = math.min(bottom, y), math.max(top, y)
		local size = piece.part.Size
		volumes[index] = size.X * size.Y * size.Z
		setShown(piece, false)
	end
	copy.Parent = folder
	derez.copy = copy
	derez.model:SetAttribute("Derezzed", true) -- RemotePoses hides the gun and hands it shows on this body
	local bounds, extent = copy:GetBoundingBox()
	derez.bounds, derez.extent = CFrame.new(bounds.Position), extent

	local counts = KillFx.pixelCounts(volumes, Perf.pick(PIXELS, math.floor(PIXELS / 2), math.floor(PIXELS / 4)))
	local span = math.max(top - bottom, 0.01)
	for index, piece in derez.pieces do
		piece.height = (piece.part.Position.Y - bottom) / span
		piece.count = counts[index]
		if derez.headshot and piece.head then
			piece.goneAt = KillFx.HEAD_GONE
			piece.count *= HEAD_PIXELS
		else
			piece.goneAt = KillFx.goneAt(piece.height, random:NextNumber())
		end
	end

	local glow = Instance.new("Highlight")
	glow.Adornee = copy
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.FillColor = HOT
	glow.OutlineColor = COOL
	glow.FillTransparency = 0.05
	glow.OutlineTransparency = 0
	glow.Parent = copy
	derez.glow = glow

	local anchor = Instance.new("Part")
	anchor.Name = "DerezLight"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.CFrame = derez.bounds :: CFrame
	anchor.Parent = folder
	local light = Instance.new("PointLight")
	light.Color = COOL
	light.Range = LIGHT_RANGE
	light.Brightness = LIGHT_BRIGHTNESS
	light.Shadows = false
	light.Parent = anchor
	derez.anchor, derez.light = anchor, light
	derez.emitters = makeEmitters(derez.wind)
end

-- Keeps the real body hidden. BodyHands puts the soldier's own hand meshes back when the body dies, after the
-- copy was taken, so anything that shows up again is hidden again.
local function hideRest(derez: Derez)
	for _, item in derez.model:GetDescendants() do
		if item:IsA("BasePart") then
			if item.Transparency < 1 and item.Name ~= "HumanoidRootPart" then
				item.Transparency = 1
			end
		elseif item:IsA("Decal") then
			item.Transparency = 1
		end
	end
end

local function stepDerez(derez: Derez): boolean
	local age = clock - derez.startedAt
	if age < 0 then
		return true -- your own body, waiting
	end
	if not derez.copy then
		if not derez.model.Parent then
			return false -- gone before it could start
		end
		freeze(derez)
	end
	local emitters = derez.emitters :: Emitters
	for _, made in { emitters.pixels, emitters.motes, emitters.scanlines } do
		made.TimeScale = speed
	end
	if KillFx.done(age) then
		-- The body has gone; the last particles clear, then everything goes.
		if derez.copy and derez.copy.Parent then
			derez.copy:Destroy();
			(derez.anchor :: BasePart):Destroy()
		end
		if age >= KillFx.DISSOLVE + LINGER then
			emitters.holder:Destroy()
			return false
		end
		return true
	end

	local glow = derez.glow :: Highlight
	local fill, cool = KillFx.glow(age)
	glow.FillTransparency = fill
	glow.FillColor = HOT:Lerp(COOL, cool)
	glow.OutlineTransparency = math.max(fill - 0.3, 0)
	local light = derez.light :: PointLight
	light.Brightness = LIGHT_BRIGHTNESS * (1 - math.clamp(age / KillFx.DISSOLVE, 0, 1))

	local step = KillFx.step(age)
	local newStep = step ~= derez.lastStep
	derez.lastStep = step
	if newStep and derez.model.Parent then
		hideRest(derez)
	end
	-- A tear shifts everything above a height sideways across the screen, for one step, and flashes scanlines.
	local tearHeight, tearShift = KillFx.tear(step, age)
	if newStep and tearHeight then
		flashScanlines(derez, tearHeight)
	end
	local camera = workspace.CurrentCamera
	local across = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z)
	across = if across.Magnitude > 0.01 then across.Unit else Vector3.xAxis

	for index, piece in derez.pieces do
		local ghost = piece.ghost
		local left = piece.goneAt - age
		local wanted = KillFx.released(piece.count, left)
		if wanted > piece.released then
			release(derez, piece, wanted - piece.released)
			piece.released = wanted
		end
		if ghost and ghost.Parent then
			if left <= 0 then
				ghost:Destroy()
			else
				-- It collapses smoothly, every frame; the glitches land on the steps.
				if left < KillFx.COLLAPSE then
					local wide, high = KillFx.squash(left)
					ghost.Size = piece.size * Vector3.new(wide, high, wide)
				end
				if newStep then
					local out = KillFx.blinkedOut(step, index, left)
					ghost.Transparency = if out then 1 else piece.transparency
					for _, child in ghost:GetChildren() do
						if child:IsA("Decal") then
							child.Transparency = if out then 1 else 0
						end
					end
					local shift = KillFx.jitter(step, index, left)
					if tearHeight and piece.height >= tearHeight then
						shift += tearShift :: number
					end
					ghost.CFrame = (piece.frame :: CFrame) + across * shift
				end
			end
		end
	end
	return true
end

RunService.RenderStepped:Connect(function(dt)
	local slow = workspace:GetAttribute("KillFxSpeed")
	speed = if type(slow) == "number" and slow > 0 then math.min(slow, 1) else 1
	clock += dt * speed
	for index = #derezzes, 1, -1 do
		if not stepDerez(derezzes[index]) then
			table.remove(derezzes, index)
		end
	end
end)

-- The way the shot was going: from the killer through the body, flat. A random way if nobody is known.
local function windFrom(body: Vector3, killer: Player?): Vector3
	local root = killer and killer.Character and killer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local away = body - root.Position
		local flat = Vector3.new(away.X, 0, away.Z)
		if flat.Magnitude > 0.5 then
			return flat.Unit
		end
	end
	local turn = random:NextNumber(0, 2 * math.pi)
	return Vector3.new(math.cos(turn), 0, math.sin(turn))
end

local function begin(at: Vector3, killer: Player?, model: Model?, headshot: boolean?)
	if typeof(model) ~= "Instance" or not model:IsA("Model") or not model.Parent or started[model] then
		return
	end
	started[model] = true
	local head = model:FindFirstChild("Head")
	local pieces: { Piece } = {}
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" and item.Transparency < 1 then
			local decals = {}
			for _, child in item:GetChildren() do
				if child:IsA("Decal") then
					decals[child] = child.Transparency
				end
			end
			local isHead = head ~= nil
				and head:IsA("BasePart")
				and (
					item == head
					or item:IsDescendantOf(head) -- the soldier's head meshes sit inside its Head
					or (item.Parent ~= nil and item.Parent:IsA("Accessory") and (item.Position - head.Position).Magnitude < 2.5)
				)
			table.insert(pieces, {
				part = item,
				transparency = item.Transparency,
				decals = decals,
				size = item.Size,
				height = 0,
				goneAt = 0,
				count = 0,
				released = 0,
				head = isHead,
			})
		end
	end
	if #pieces == 0 then
		return
	end
	table.insert(derezzes, {
		model = model,
		startedAt = clock + (if model == player.Character then KillFx.OWN_DELAY else 0),
		wind = windFrom(at, killer),
		headshot = headshot == true,
		pieces = pieces,
		lastStep = -1,
	})
end

deathRemote.OnClientEvent:Connect(begin)
