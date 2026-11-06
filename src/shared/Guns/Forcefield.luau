-- The doorway field's motion. A body pressing in bends it. Pushed far enough, it lets go, slowly
-- parts around the body, then its pieces get sucked home one at a time. distance is how far the
-- body is from the field's plane, signed by side.
local REACH = 1.2 -- how far off the plane a body first touches it
local STRETCH = 6 -- how far it bends before letting go. Walking pace crosses this in under 0.4s.
local CLEAR = STRETCH - REACH + 1 -- how far off the plane a body has to be for the field to be done with it
local STIFFNESS = 170 -- for a body that slips away without pushing through
local DAMPING = 14
local GLITCH_FADE = 2.5
-- The dent is body shaped, a column around the root part.
local BODY_UP = 2.5
local BODY_DOWN = 3
local BODY_RADIUS = 1
local FALLOFF = 1.1 -- studs, how quickly the sheet returns to flat beyond the body
local MAX_STEP = 1 / 30
local PART_TIME = 0.7 -- seconds to get out of the body's way
local PART_WIDTH = 2.5 -- studs each side
local RETURN_SPREAD = 1.8 -- seconds from the first piece heading home to the last
local RETURN_TIME = 0.5 -- seconds one piece takes
local RELEASE_TIME = PART_TIME + RETURN_SPREAD + RETURN_TIME

export type State = {
	depth: number,
	velocity: number,
	side: number,
	broken: boolean,
	glitch: number,
	released: number?, -- seconds since it let go, until the last piece is home
}

local Forcefield = {}

function Forcefield.new(): State
	return { depth = 0, velocity = 0, side = 0, broken = false, glitch = 0 }
end

local function spring(state: State, dt: number)
	state.velocity += (-STIFFNESS * state.depth - DAMPING * state.velocity) * dt
	state.depth += state.velocity * dt
end

function Forcefield.step(state: State, distance: number?, dt: number)
	dt = math.min(dt, MAX_STEP)
	state.glitch *= math.exp(-dt * GLITCH_FADE)

	if distance and math.abs(distance) > CLEAR then
		state.side = if distance > 0 then 1 else -1
		state.broken = false
	end
	local press = if distance then REACH - distance * state.side else 0
	if distance and state.side ~= 0 and not state.broken and press > 0 then
		if press < STRETCH then
			state.depth = -state.side * press
			state.velocity = 0
			state.released = nil
			state.glitch = math.max(state.glitch, press / STRETCH * 0.5)
			return
		end
		state.broken = true
		state.glitch = 1
		state.velocity = 0
		state.released = 0
		return
	end

	if state.released then
		state.released += dt
		if state.released >= RELEASE_TIME then
			state.released = nil
			state.depth = 0
		end
		return
	end
	spring(state, dt)
end

-- How far the cell at x, y moves off the plane, for a body whose root is at centreX, centreY.
function Forcefield.offset(depth: number, x: number, y: number, centreX: number, centreY: number): number
	local dx = x - centreX
	local dy = y - math.clamp(y, centreY - BODY_DOWN, centreY + BODY_UP)
	local beyond = math.max(math.sqrt(dx * dx + dy * dy) - BODY_RADIUS, 0)
	return depth * math.exp(-(beyond * beyond) / (2 * FALLOFF * FALLOFF))
end

-- Where the cell at x, y sits: sideways, up and off the plane. delay is 0 to 1, the cell's place
-- in the queue home.
function Forcefield.piece(state: State, x: number, y: number, centreX: number, centreY: number, delay: number): (number, number, number)
	local released = state.released
	if not released then
		return 0, 0, Forcefield.offset(state.depth, x, y, centreX, centreY)
	end
	local dent = Forcefield.offset(1, x, y, centreX, centreY)
	local parting = 1 - (1 - math.min(released / PART_TIME, 1)) ^ 2
	local journey = math.clamp((released - PART_TIME - delay * RETURN_SPREAD) / RETURN_TIME, 0, 1)
	local left = 1 - journey ^ 3

	local dx = x - centreX
	local dy = y - math.clamp(y, centreY - BODY_DOWN, centreY + BODY_UP)
	local length = math.sqrt(dx * dx + dy * dy)
	local away = PART_WIDTH * parting * dent * left
	if length == 0 then
		return away, 0, state.depth * dent * left
	end
	return dx / length * away, dy / length * away, state.depth * dent * left
end

return Forcefield
