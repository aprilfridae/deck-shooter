-- The pack opening. It plays by itself in the 3D world, where an inspected card is held up beside
-- the menu: the pack spins in, its top strip peels away, the cards rise out, spread and all turn over.
-- Separate surfaces held up in front of the world draw in no reliable order, so the pack and the
-- cards rising out of it share one surface, which keeps the cards behind the wrapper.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CardCore = ReplicatedStorage:WaitForChild("CardCore")
local CardLook = require(CardCore:WaitForChild("CardLook"))
local PackArt = require(CardCore:WaitForChild("PackArt"))
local PullMotion = require(CardCore:WaitForChild("PullMotion"))
local Variant = require(CardCore:WaitForChild("Variant"))
local Guns = ReplicatedStorage:WaitForChild("Guns")
local CardSpin = require(Guns:WaitForChild("Hud"):WaitForChild("CardSpin"))
local Palette = require(Guns:WaitForChild("Palette"))
local CardFace = require(script.Parent.CardFace)
local CardInspect = require(script.Parent.CardInspect)
local MenuCamera = require(script.Parent.MenuCamera)
local PackCardBack = require(script.Parent.PackCardBack)
local PackFace = require(script.Parent.PackFace)
local TypeLabel = require(script.Parent.TypeLabel)

local STEP_NAME = "PullStage"
local runs = 0 -- each gets its own step, since the last one's clean-up can land after the next starts

-- In wrapper units: a pack is 150 wide and 230 tall.
local PACK_WIDTH = PackFace.WIDTH
local PACK_HEIGHT = PackFace.HEIGHT
local ROOM = 190 -- above the pack, for the cards to rise into
local TEAR = 37 -- how far below the pack's top the strip tears off
local CANVAS_SCALE = 5 -- surface pixels to a unit
local STACK_WIDTH = 130
local STACK_INSET = 10
local STACK_DROP = 2 -- how far below the tear the cards start
local STACK_RISE = 190
local WRAPPER_CLIP = 225 -- the cards stop short of the pack's bottom crimp
local GLOW_HEIGHT = 70
local STRIP_PIECES = 6
local STRIP_LIFT = 50
local STRIP_DRIFT = 20
local STRIP_TOWARD = 30
local STRIP_TURN = 2 -- radians

-- Shares of the screen's height, unless they say otherwise.
local PACK_SHARE = 0.62
local CARD_WIDTH_SHARE = 0.26
local CARD_WIDTH_MOST = 0.15 -- of the screen's width
local LABEL_SPACE = 0.014
local LABEL_SIZE = 0.075 -- of a card's width
local BUTTON_SPACE = 0.05
local CARD_SHAPE = 240 / 150
local CANVAS_CARD_WIDTH = 500

local SHAKE = 0.012 -- of the pack's or a card's width
local LEAN = 0.18 -- radians each side card turns in
local DROP_TIME = 0.35 -- seconds the empty pack takes to fall away
local DROP_DISTANCE = 0.9
local DIM_TIME = 0.3
local ZERO_DAY_CLEAR = 0.12
local FLASH_TIME = 0.45
local POP_TIME = 0.25
local POP_SIZE = 0.1

local LIGHTS = {
	Field = Palette.Bone,
	Redline = Palette.HazardRed,
	Prototype = Palette.SignalAcid,
	ZeroDay = Palette.DataCyan,
}

local PullStage = {}

local function ease(progress: number): number
	local left = 1 - math.clamp(progress, 0, 1)
	return 1 - left * left * left
end

local function hide(run: any)
	for _, gui in run.surfaces do
		gui.Enabled = false
	end
end

local function wrapperImage(parent: Instance, pack: string, y: number, x: number?): ImageLabel
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Image = PackArt.image(pack) or ""
	image.Position = UDim2.fromOffset(x or 0, y)
	image.Size = UDim2.fromOffset(PACK_WIDTH * CANVAS_SCALE, PACK_HEIGHT * CANVAS_SCALE)
	image.Parent = parent
	return image
end

local function worldSurface(run: any, part: BasePart, face: Enum.NormalId, canvas: Vector2): SurfaceGui
	local gui = CardInspect.surface(part, face, canvas)
	gui.AlwaysOnTop = true
	gui.Enabled = false
	table.insert(run.instances, gui)
	table.insert(run.surfaces, gui)
	return gui
end

local function part(run: any, name: string): Part
	local made = CardInspect.clearPart(name)
	table.insert(run.instances, made)
	return made
end

-- The surface with the wrapper, the glow and the cards still inside.
local function buildOpener(run: any)
	local scale = CANVAS_SCALE
	local canvas = Vector2.new(PACK_WIDTH * scale, (PACK_HEIGHT + ROOM) * scale)
	run.opener = part(run, "PullPack")
	run.openerFront = worldSurface(run, run.opener, Enum.NormalId.Back, canvas)
	run.openerRear = worldSurface(run, run.opener, Enum.NormalId.Front, canvas)
	wrapperImage(run.openerRear, run.pack, ROOM * scale)

	local glow = Instance.new("Frame")
	glow.AnchorPoint = Vector2.new(0, 1)
	glow.BackgroundColor3 = run.light
	glow.BackgroundTransparency = 1
	glow.BorderSizePixel = 0
	glow.Position = UDim2.fromOffset(0, (ROOM + TEAR) * scale)
	glow.Size = UDim2.fromOffset(canvas.X, 0)
	glow.Parent = run.openerFront
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new(1, 0)
	fade.Parent = glow
	run.glow = glow

	local clip = Instance.new("Frame")
	clip.BackgroundTransparency = 1
	clip.ClipsDescendants = true
	clip.Size = UDim2.fromOffset(canvas.X, (ROOM + WRAPPER_CLIP) * scale)
	clip.ZIndex = 2
	clip.Parent = run.openerFront
	run.stack = PackCardBack.new(clip, run.pack, STACK_WIDTH * scale)
	run.stack.Position = UDim2.fromOffset(STACK_INSET * scale, 0)
	run.stack.Visible = false

	local wrapper = Instance.new("Frame")
	wrapper.BackgroundTransparency = 1
	wrapper.ClipsDescendants = true
	wrapper.Position = UDim2.fromOffset(0, (ROOM + TEAR) * scale)
	wrapper.Size = UDim2.fromOffset(canvas.X, (PACK_HEIGHT - TEAR) * scale)
	wrapper.ZIndex = 3
	wrapper.Parent = run.openerFront
	PackFace.new(wrapper, { pack = run.pack, width = canvas.X, position = UDim2.fromOffset(0, -TEAR * scale) })
end

local function buildStrip(run: any)
	local scale = CANVAS_SCALE
	local pieceWidth = PACK_WIDTH * scale / STRIP_PIECES
	run.strip = {}
	for index = 1, STRIP_PIECES do
		local piece = part(run, "PullStrip")
		local gui = worldSurface(run, piece, Enum.NormalId.Back, Vector2.new(pieceWidth, TEAR * scale))
		local clip = Instance.new("Frame")
		clip.BackgroundTransparency = 1
		clip.ClipsDescendants = true
		clip.Size = UDim2.fromScale(1, 1)
		clip.Parent = gui
		local image = wrapperImage(clip, run.pack, 0, -(index - 1) * pieceWidth)
		table.insert(run.strip, { part = piece, gui = gui, image = image })
	end
end

local function buildCards(run: any)
	local canvas = Vector2.new(CANVAS_CARD_WIDTH, CANVAS_CARD_WIDTH * CARD_SHAPE)
	run.slots = {}
	for index, card in run.cards do
		local holder = part(run, "PullCard")
		local front = worldSurface(run, holder, Enum.NormalId.Back, canvas)
		local back = worldSurface(run, holder, Enum.NormalId.Front, canvas)
		CardFace.new(front, { cardId = card.cardId, tier = card.tier, variant = card.variant, width = CANVAS_CARD_WIDTH })
		PackCardBack.new(back, run.pack, CANVAS_CARD_WIDTH)
		table.insert(run.slots, { card = card, index = index, part = holder, front = front, back = back })
	end
end

local function buildDim(run: any)
	run.dim = part(run, "PullDim")
	run.dim.Size = Vector3.new(CardInspect.DIM_SIZE, CardInspect.DIM_SIZE, CardInspect.THICKNESS)
	local gui = CardInspect.surface(run.dim, Enum.NormalId.Back, Vector2.new(4, 4))
	table.insert(run.instances, gui)
	table.insert(run.surfaces, gui)
	run.dimGui = gui
	run.dimFrame = Instance.new("Frame")
	run.dimFrame.BackgroundColor3 = Palette.DeepNavy
	run.dimFrame.BackgroundTransparency = 1
	run.dimFrame.BorderSizePixel = 0
	run.dimFrame.Size = UDim2.fromScale(1, 1)
	run.dimFrame.Parent = gui
end

local function flash(run: any, strength: number)
	if strength <= 0 then
		return
	end
	local sheet = Instance.new("Frame")
	sheet.BackgroundColor3 = run.light
	sheet.BackgroundTransparency = 1 - strength
	sheet.BorderSizePixel = 0
	sheet.Size = UDim2.fromScale(1, 1)
	sheet.Parent = run.frame
	local fading = TweenService:Create(sheet, TweenInfo.new(FLASH_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
	fading.Completed:Once(function()
		sheet:Destroy()
	end)
	fading:Play()
end

-- Click areas and rarity names, once everything has landed. They sit where the cards do on screen.
local function settle(run: any, cardX: { number }, cardY: number, cardWidth: number, view: Vector2)
	local height = cardWidth * CARD_SHAPE
	for _, slot in run.slots do
		local x = cardX[slot.index]
		local hit = Instance.new("TextButton")
		hit.AnchorPoint = Vector2.new(0.5, 0.5)
		hit.BackgroundTransparency = 1
		hit.Text = ""
		hit.Position = UDim2.fromOffset(x, cardY)
		hit.Size = UDim2.fromOffset(cardWidth, height)
		hit.Parent = run.frame
		hit.Activated:Connect(function()
			run.callbacks.inspect(slot.card)
		end)
		if PullMotion.flash(slot.card) > 0 then
			local line = cardY + height / 2 + LABEL_SPACE * view.Y
			local name = TypeLabel.new(run.frame, {
				style = "LabelBold",
				size = cardWidth * LABEL_SIZE,
				tracking = 0,
				color = Palette.Bone,
				position = UDim2.new(),
			})
			name:set(CardLook.rarityText(slot.card.tier, slot.card.variant))
			name:setPosition(UDim2.fromOffset(x - name:width() / 2, line))
		end
	end
	run.callbacks.rested(cardY + height / 2 + BUTTON_SPACE * view.Y)
end

local function step(run: any, dt: number)
	if CardInspect.isOpen() then
		hide(run)
		return
	end
	if run.elapsed == 0 then
		-- The Outpost's colour grade tints the world green, cards included, so it's off for the opening.
		local grade = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
		if grade and grade.Enabled then
			grade.Enabled = false
			run.grade = grade
		end
	end
	run.elapsed += dt
	local time = run.elapsed
	local times = run.times
	local camera = Workspace.CurrentCamera
	local view = camera.ViewportSize
	local look = camera.CFrame.LookVector
	local facing = camera.CFrame.Rotation
	local depth = CardInspect.DEPTH
	local studsPerPixel = 2 * depth * math.tan(math.rad(camera.FieldOfView) / 2) / view.Y
	local function point(x: number, y: number, along: number?): Vector3
		-- The camera's sheared picture is allowed for by asking MenuCamera for the ray.
		local ray = MenuCamera.ray(x, y)
		return ray.Origin + ray.Direction * ((along or depth) / ray.Direction:Dot(look))
	end
	local function shows(what: BasePart): boolean
		return what.CFrame.LookVector:Dot(what.Position - camera.CFrame.Position) > 0
	end

	local centreX, centreY = view.X * CardInspect.SCREEN_X, view.Y * CardInspect.SCREEN_Y
	run.dim.CFrame = CFrame.new(point(centreX, centreY, depth + CardInspect.DIM_DEPTH)) * facing
	run.dimGui.Enabled = true
	local clear = if run.deepDim then ZERO_DAY_CLEAR else CardInspect.DIM_CLEAR
	run.dimFrame.BackgroundTransparency = 1 - (1 - clear) * math.min(time / DIM_TIME, 1)

	local swayYaw, swayPitch = CardSpin.sway(time)
	local spin, arriving = CardSpin.enter(time)
	local unitPixels = PACK_SHARE * view.Y / PACK_HEIGHT
	local dropped = math.clamp((time - times.spread) / DROP_TIME, 0, 1)

	-- The pack and the strip.
	if dropped < 1 then
		local unit = unitPixels * studsPerPixel * arriving
		local charge = math.clamp((time - CardSpin.ENTER_TIME) / (times.rise - CardSpin.ENTER_TIME), 0, 1)
		local reach = SHAKE * PACK_WIDTH * unit * charge * (1 - dropped)
		local base = CFrame.new(point(centreX, centreY + dropped * dropped * DROP_DISTANCE * view.Y))
			* facing
			* CFrame.Angles(swayPitch, spin + swayYaw, 0)
			* CFrame.new(run.random:NextNumber(-reach, reach), run.random:NextNumber(-reach, reach), 0)
		run.opener.Size = Vector3.new(PACK_WIDTH * unit, (PACK_HEIGHT + ROOM) * unit, CardInspect.THICKNESS)
		run.opener.CFrame = base * CFrame.new(0, ROOM * unit / 2, 0)
		local showsFront = shows(run.opener)
		run.openerFront.Enabled = showsFront
		run.openerRear.Enabled = not showsFront and time < times.rip

		local ripped = math.clamp((time - times.rip) / PullMotion.RIP_TIME, 0, 1)
		for index, piece in run.strip do
			local peeled = PullMotion.peel(ripped, index, STRIP_PIECES)
			local side = (index - (STRIP_PIECES + 1) / 2) / ((STRIP_PIECES - 1) / 2)
			local across = (index - (STRIP_PIECES + 1) / 2) * PACK_WIDTH / STRIP_PIECES + side * peeled * STRIP_DRIFT
			local up = PACK_HEIGHT / 2 - TEAR / 2 + peeled * STRIP_LIFT
			piece.part.Size = Vector3.new(PACK_WIDTH / STRIP_PIECES * unit, TEAR * unit, CardInspect.THICKNESS)
			piece.part.CFrame = base
				* CFrame.new(across * unit, up * unit, peeled * STRIP_TOWARD * unit)
				* CFrame.Angles(peeled * STRIP_TURN, 0, side * peeled)
			piece.image.ImageTransparency = math.clamp((peeled - 0.5) * 2, 0, 1)
			piece.gui.Enabled = showsFront and peeled < 1
		end

		local rising = ease((time - times.rise) / PullMotion.RISE_TIME)
		local scale = CANVAS_SCALE
		run.stack.Visible = time >= times.rise and time < times.spread
		run.stack.Position = UDim2.fromOffset(STACK_INSET * scale, (ROOM + TEAR + STACK_DROP - rising * STACK_RISE) * scale)
		run.glow.Size = UDim2.fromOffset(PACK_WIDTH * scale, GLOW_HEIGHT * scale * ease(ripped))
		run.glow.BackgroundTransparency = if time < times.spread then 1 - ripped else 1
	else
		run.openerFront.Enabled = false
		run.openerRear.Enabled = false
		for _, piece in run.strip do
			piece.gui.Enabled = false
		end
	end

	-- The cards.
	if time < times.spread then
		return
	end
	local spread = ease((time - times.spread) / PullMotion.SPREAD_TIME)
	local fullWidth = math.min(CARD_WIDTH_SHARE * view.Y, CARD_WIDTH_MOST * view.X)
	local startWidth = STACK_WIDTH * unitPixels
	local cardWidth = startWidth + (fullWidth - startWidth) * spread
	local startY = centreY - (PACK_HEIGHT / 2 - (TEAR + STACK_DROP - STACK_RISE) - STACK_WIDTH * CARD_SHAPE / 2) * unitPixels
	local cardY = startY + (centreY - startY) * spread
	local building = math.clamp((time - times.build) / math.max(times.flip - times.build, 0.01), 0, 1)
	local turned = ease((time - times.flip) / PullMotion.TURN_TIME)
	local popped = math.clamp((time - times.rest) / POP_TIME, 0, 1)
	local pop = 1 + POP_SIZE * math.sin(popped * math.pi)
	local cardX = {}
	if turned >= 0.5 and not run.flashed then
		run.flashed = true
		run.deepDim = run.best.variant == Variant.ZeroDay
		flash(run, PullMotion.flash(run.best))
	end
	for _, slot in run.slots do
		local steps, tilt = PullMotion.fan(slot.index)
		local x = centreX + steps * fullWidth * spread
		cardX[slot.index] = x
		local shake = if turned > 0 then 0 else SHAKE * fullWidth * building
		local width = cardWidth * pop * studsPerPixel
		slot.part.Size = Vector3.new(width, width * CARD_SHAPE, CardInspect.THICKNESS)
		local cardYaw, cardPitch = CardSpin.sway(time + slot.index)
		slot.part.CFrame = CFrame.new(point(x + run.random:NextNumber(-shake, shake), cardY + run.random:NextNumber(-shake, shake)))
			* facing
			* CFrame.Angles(0, 0, math.rad(-tilt) * spread)
			* CFrame.Angles(cardPitch, math.pi * (1 - turned) + cardYaw - steps * LEAN * spread, 0)
		local showsFront = shows(slot.part)
		slot.front.Enabled = showsFront
		slot.back.Enabled = not showsFront
	end
	if time >= times.rest and not run.settled then
		run.settled = true
		settle(run, cardX, cardY, fullWidth, view)
	end
end

local function finish(run: any)
	RunService:UnbindFromRenderStep(run.stepName)
	if run.grade then
		run.grade.Enabled = true
	end
	for _, instance in run.instances do
		instance:Destroy()
	end
end

-- Runs until frame is destroyed. callbacks.rested(line) gets the screen line under the cards, and
-- callbacks.inspect(card) is called when a landed card is clicked.
function PullStage.play(frame: Frame, pack: string, cards: { any }, callbacks: any)
	local best = PullMotion.best(cards)
	runs += 1
	local run: any = {
		stepName = `{STEP_NAME}{runs}`,
		frame = frame,
		pack = pack,
		cards = PullMotion.fanOrder(cards),
		best = best,
		light = LIGHTS[CardLook.look(best.tier, best.variant)],
		times = PullMotion.phases(cards),
		callbacks = callbacks,
		random = Random.new(),
		elapsed = 0,
		flashed = false,
		settled = false,
		deepDim = false,
		instances = {},
		surfaces = {},
	}
	buildDim(run)
	buildOpener(run)
	buildStrip(run)
	buildCards(run)

	frame.Destroying:Once(function()
		finish(run)
	end)
	RunService:BindToRenderStep(run.stepName, Enum.RenderPriority.Camera.Value + 1, function(dt)
		step(run, dt)
	end)
end

return PullStage
