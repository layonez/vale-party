-- Draws mission characters on the Flight Map globe. Characters sit at fixed
-- world positions (content/world.lua) and have a subtle pulsing glow so they
-- read as interactive (spec §10). During free flight all unfinished characters
-- are shown; while a mission is active only the active one remains (the scene
-- decides which to pass in). Characters are drawn only on the visible
-- hemisphere.
local Sphere = require("src.core.sphere")

local Character = {}

local BODY = 12 -- character body radius in pixels

-- Draw one character at screen (x, y). `time` drives the glow pulse; `strong`
-- brightens it when the airplane is inside the interaction area (spec §11).
local function drawOne(x, y, color, time, strong)
	local pulse = 0.5 + 0.5 * math.sin(time * 3)
	local glow = strong and (0.9 + 0.1 * pulse) or (0.35 + 0.25 * pulse)
	local glowR = strong and (BODY + 12) or (BODY + 6 + 3 * pulse)
	love.graphics.setColor(color[1], color[2], color[3], glow * 0.5)
	love.graphics.circle("fill", x, y, glowR)
	-- Body.
	love.graphics.setColor(color[1], color[2], color[3], 1)
	love.graphics.circle("fill", x, y, BODY)
	love.graphics.setColor(0.12, 0.12, 0.16, 1)
	love.graphics.setLineWidth(2)
	love.graphics.circle("line", x, y, BODY)
	-- Simple face so it reads as a character, not a dot.
	love.graphics.setColor(0.12, 0.12, 0.16, 1)
	love.graphics.circle("fill", x - 4, y - 2, 1.8)
	love.graphics.circle("fill", x + 4, y - 2, 1.8)
end

-- Draw the given characters for the current orientation. `nearId` (optional)
-- is the id of the character the airplane is currently inside the interaction
-- area of, which gets a stronger glow. `globe` is {x, y, radius}.
---@param characters table[]
---@param orientation table
---@param globe table
---@param time number
---@param nearId string|nil
function Character.draw(characters, orientation, globe, time, nearId)
	for _, character in ipairs(characters) do
		local sx, sy, visible = Sphere.project(
			orientation,
			character.latitude,
			character.longitude,
			globe.radius,
			globe.x,
			globe.y
		)
		if visible then
			drawOne(sx, sy, character.color, time, character.id == nearId)
		end
	end
end

return Character
