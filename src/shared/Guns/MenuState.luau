-- Whether the title screen is up. Input stays blocked until the player presses PLAY.
export type State = { open: boolean }

local MenuState = {}

function MenuState.new(): State
	return { open = true }
end

function MenuState.isOpen(state: State): boolean
	return state.open
end

function MenuState.play(state: State)
	state.open = false
end

function MenuState.filter(state: State, keys: { [string]: boolean }): { [string]: boolean }
	if not state.open then
		return keys
	end
	local blocked = {}
	for key in keys do
		blocked[key] = false
	end
	return blocked
end

-- The one the game uses.
MenuState.shared = MenuState.new()

return MenuState
