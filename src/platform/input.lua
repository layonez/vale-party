local baton = require("vendor.baton")

local Input = {}

local controls = {
	move_left = { "key:left", "key:a", "axis:leftx-", "button:dpleft" },
	move_right = { "key:right", "key:d", "axis:leftx+", "button:dpright" },
	move_up = { "key:up", "key:w", "axis:lefty-", "button:dpup" },
	move_down = { "key:down", "key:s", "axis:lefty+", "button:dpdown" },
	interact = { "key:return", "key:space", "button:a" },
	repeat_instruction = { "key:r", "key:backspace", "button:b" },
	pause = { "key:escape", "key:p", "button:start" },
	back = { "key:escape", "key:backspace", "button:b" },
	debug = { "key:f1", "key:`" },
	-- Debug-only helpers (active while debug mode is on). `key:`` toggles debug
	-- itself and is browser-safe, unlike F1 which browsers intercept. dbg_drift
	-- cycles a persistent camera drift so rotation is observable in a single
	-- screenshot; dbg_reset returns to the start position.
	dbg_drift = { "key:0" },
	dbg_reset = { "key:9" },
}

function Input.new()
	return baton.new({
		controls = controls,
		pairs = { { "move_left", "move_right", "move_up", "move_down" } },
		joystick = love.joystick.getJoysticks()[1],
	})
end

---@param input table
---@return table movement
function Input.snapshot(input)
	return {
		left = input:down("move_left"),
		right = input:down("move_right"),
		up = input:down("move_up"),
		down = input:down("move_down"),
	}
end

-- Discrete controls worth logging when they fire, so play sessions (including
-- automated browser tests) leave a readable action trail in the console.
local LOGGED = {
	"interact",
	"back",
	"pause",
	"repeat_instruction",
	"dbg_drift",
	"dbg_reset",
	"debug",
}

-- Log every control that transitioned to "pressed" this frame. Call once per
-- update after input:update(). `logger` receives a short "input:<name>" string.
---@param input table
---@param logger fun(message:string)
function Input.logActions(input, logger)
	for _, name in ipairs(LOGGED) do
		if input:pressed(name) then
			logger("input:" .. name)
		end
	end
end

return Input
