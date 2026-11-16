-- A body killed by a gun glitches away, like dust blowing off in the wind but digital. The body is hidden and a
-- frozen copy of it takes its place, posed as it died. The copy flashes white, then flickers between cyan and white
-- and tears sideways at random heights while its parts go one by one, loosely from the top down. Each part blinks
-- and twitches for a moment, leaking a few pixels, then leaves as a puff of them. The pixels drift away from the
-- shot and up, moving in stutters, and shrink and flicker out. A headshot's head goes at once. Everyone sees it.
-- Your own body waits a moment first, so the soul sees it drop before it goes. Timings are in KillFx.
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

local PIXELS = 150 -- pixels a whole body leaves as, on a fast machine
local WIND = { 2.5, 6.5 } -- studs a second away from the shot
local LIFT = { 0.5, 3 } -- and up
local SCATTER = 1.2 -- and any way, at most
local HEAD_PIXELS = 2 -- a headshot's head leaves as this many times its share
local DRAG = 0.8 -- how fast they slow, a second
local RISE = 2.5 -- studs a second gained upward each second
local PIXEL_TWITCH = 0.12 -- studs a pixel can land off its path on each jump
local BODY_COLOR_SHARE = 0.2 -- of the pixels, how many keep the colour of the part they came off
local WHITE_SHARE = 0.25 -- and how many are white; the rest are Data Cyan
local HEAD_NEAR = 2.5 -- hats and hair this close to the head go with it
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
	height: number, -- 0 at the bottom of the body, 1 at the top
	goneAt: number,
	count: number, -- pixels it leaves as
	released: number,
	head: boolean,
}
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
	lastStep: number,
}
type Pixel = {
	part: BasePart,
	position: Vector3,
	velocity: Vector3,
	turn: CFrame,
	size: number,
	age: number,
	life: number,
	phase: number, -- so they don't all jump on the same frame
	lastJump: number,
	seed: number,
}

local derezzes: { Derez } = {}
local pixels: { Pixel } = {}
local started: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local clock = 0

local function between(range: { number }): number
	return random:NextNumber(range[1], range[2])
end

local function setShown(piece: Piece, shown: boolean)
	piece.part.Transparency = if shown then piece.transparency else 1
	for decal, transparency in piece.decals do
		decal.Transparency = if shown then transparency else 1
	end
end

-- Lets count pixels go from a part, wherever its copy stands now.
local function release(derez: Derez, piece: Piece, count: number)
	local source = piece.ghost or piece.part
	for _ = 1, count do
		local size = between(KillFx.PIXEL_SIZE)
		local offset = Vector3.new(random:NextNumber(-0.5, 0.5), random:NextNumber(-0.5, 0.5), random:NextNumber(-0.5, 0.5))
			* source.Size
		local at = source.CFrame:PointToWorldSpace(offset)
		local roll = random:NextNumber()
		local color = if roll < BODY_COLOR_SHARE
			then piece.part.Color
			elseif roll < BODY_COLOR_SHARE + WHITE_SHARE then HOT
			else COOL
		local pixel = Instance.new("Part")
		pixel.Name = "Pixel"
		pixel.Anchored = true
		pixel.CanCollide = false
		pixel.CanQuery = false
		pixel.CanTouch = false
		pixel.CastShadow = false
		pixel.Material = Enum.Material.Neon
		pixel.Color = color
		pixel.Size = Vector3.one * size
		-- Square on to the world, like a pixel, with a little turn.
		local turn = CFrame.Angles(0, random:NextNumber(0, math.pi / 2), 0)
		pixel.CFrame = CFrame.new(at) * turn
		pixel.Parent = folder
		table.insert(pixels, {
			part = pixel,
			position = at,
			velocity = derez.wind * between(WIND) + Vector3.yAxis * between(LIFT) + random:NextUnitVector() * random:NextNumber(0, SCATTER),
			turn = turn,
			size = size,
			age = 0,
			life = between(KillFx.PIXEL_LIFE),
			phase = random:NextNumber(0, KillFx.PIXEL_STEP),
			lastJump = -1,
			seed = random:NextNumber(0, 1000),
		})
	end
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

-- Swaps the body for its frozen copy and works out when each part goes and how many pixels it leaves as.
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
		local y = piece.part.Position.Y
		bottom, top = math.min(bottom, y), math.max(top, y)
		local size = piece.part.Size
		volumes[index] = size.X * size.Y * size.Z
		setShown(piece, false)
	end
	copy.Parent = folder
	derez.copy = copy
	derez.model:SetAttribute("Derezzed", true) -- RemotePoses hides the gun and hands it shows on this body

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
	anchor.CFrame = CFrame.new(derez.model:GetPivot().Position)
	anchor.Parent = folder
	local light = Instance.new("PointLight")
	light.Color = COOL
	light.Range = LIGHT_RANGE
	light.Brightness = LIGHT_BRIGHTNESS
	light.Shadows = false
	light.Parent = anchor
	derez.anchor, derez.light = anchor, light
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

local function finish(derez: Derez)
	if derez.copy then
		derez.copy:Destroy()
	end
	if derez.anchor then
		derez.anchor:Destroy()
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
	-- A tear shifts everything above a height sideways across the screen, for one step.
	local tearHeight, tearShift = KillFx.tear(step, age)
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
			elseif newStep then
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

	if KillFx.done(age) then
		finish(derez)
		return false
	end
	return true
end

local function stepPixels(dt: number)
	local parts, frames = {}, {}
	for index = #pixels, 1, -1 do
		local pixel = pixels[index]
		pixel.age += dt
		local share = pixel.age / pixel.life
		if share >= 1 then
			pixel.part:Destroy()
			table.remove(pixels, index)
		else
			pixel.velocity = pixel.velocity * math.exp(-dt * DRAG) + Vector3.yAxis * RISE * dt
			pixel.position += pixel.velocity * dt
			-- It's only redrawn on its jumps, and lands a little off its path each time.
			local jump = math.floor((pixel.age + pixel.phase) / KillFx.PIXEL_STEP)
			if jump ~= pixel.lastJump then
				pixel.lastJump = jump
				local size, transparency = KillFx.pixel(share)
				local flickered = share > KillFx.PIXEL_HOLD and KillFx.noise(jump, pixel.seed) < 0.3
				pixel.part.Size = Vector3.one * math.max(pixel.size * size, 0.02)
				pixel.part.Transparency = if flickered then 1 else transparency
				local twitch = random:NextUnitVector() * random:NextNumber(0, PIXEL_TWITCH)
				table.insert(parts, pixel.part)
				table.insert(frames, CFrame.new(pixel.position + twitch) * pixel.turn)
			end
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

RunService.RenderStepped:Connect(function(dt)
	local speed = workspace:GetAttribute("KillFxSpeed")
	dt *= if type(speed) == "number" and speed > 0 then speed else 1
	clock += dt
	for index = #derezzes, 1, -1 do
		if not stepDerez(derezzes[index]) then
			table.remove(derezzes, index)
		end
	end
	stepPixels(dt)
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
					or (item.Parent ~= nil and item.Parent:IsA("Accessory") and (item.Position - head.Position).Magnitude < HEAD_NEAR)
				)
			table.insert(pieces, {
				part = item,
				transparency = item.Transparency,
				decals = decals,
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
