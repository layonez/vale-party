-- Draws airports on the Flight Map. Each playable country has one airport
-- (content/world.lua); in the MVP every airport is locked and shows a clear
-- stop/lock symbol (spec §9). Airports are non-interactive here — the scene
-- has no airport A-button handling — so "locked and inert" needs no logic,
-- only this visual. Airports are drawn only when on the visible hemisphere.
local Sphere = require("src.core.sphere")

local Airport = {}

local SIZE = 11 -- half-size of the airport marker in pixels

-- Draw one airport marker centered at screen (x, y): a small pad with a red
-- stop/lock badge so "you cannot land here yet" reads without text.
local function drawLocked(x, y)
	-- Pad base.
	love.graphics.setColor(0.85, 0.85, 0.9)
	love.graphics.rectangle("fill", x - SIZE, y - SIZE, SIZE * 2, SIZE * 2, 3)
	love.graphics.setColor(0.2, 0.2, 0.25)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", x - SIZE, y - SIZE, SIZE * 2, SIZE * 2, 3)
	-- Red locked badge (octagon-ish stop) with a white crossbar.
	love.graphics.setColor(0.82, 0.12, 0.14)
	love.graphics.circle("fill", x, y, SIZE - 1)
	love.graphics.setColor(1, 1, 1)
	love.graphics.setLineWidth(3)
	love.graphics.line(x - (SIZE - 4), y, x + (SIZE - 4), y)
end

-- Draw every visible airport for the given orientation. `globe` is {x,y,radius}.
---@param airports table[]
---@param orientation table
---@param globe table
function Airport.draw(airports, orientation, globe)
	for _, airport in ipairs(airports) do
		local sx, sy, visible = Sphere.project(
			orientation,
			airport.latitude,
			airport.longitude,
			globe.radius,
			globe.x,
			globe.y
		)
		if visible and airport.state == "locked" then
			drawLocked(sx, sy)
		end
	end
end

return Airport
