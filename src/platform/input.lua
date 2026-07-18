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
	debug = { "key:f1" },
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

return Input
