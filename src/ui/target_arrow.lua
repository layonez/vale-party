-- The target-direction arrow (spec §13). While a mission is active and the
-- target country is behind the horizon, an arrow at the edge of the play area
-- points along the screen-space direction toward the target. It rotates freely
-- (not limited to four directions) and updates as the globe turns. When the
-- target becomes visible the scene stops drawing it and highlights the country
-- instead.
local TargetArrow = {}

-- Center of the globe/play area; the arrow orbits this point.
local CENTER_X = 320
local CENTER_Y = 250
local ORBIT = 232 -- radius at which the arrow sits (just outside the globe rim)
local SIZE = 26 -- larger so it reads clearly as a direction hint

-- Draw the arrow given a unit screen-space direction (dx, dy), y down.
---@param dx number
---@param dy number
function TargetArrow.draw(dx, dy)
	local x = CENTER_X + dx * ORBIT
	local y = CENTER_Y + dy * ORBIT
	local angle = math.atan2(dy, dx)

	-- Vertices of a broad chevron pointing along +x.
	local tip, back, half = SIZE, -SIZE * 0.6, SIZE * 0.8

	love.graphics.push()
	love.graphics.translate(x, y)
	love.graphics.rotate(angle)
	-- Dark contrast halo behind the arrow so it stands out over ocean and space.
	love.graphics.setColor(0.05, 0.05, 0.08, 0.85)
	love.graphics.circle("fill", 0, 0, SIZE * 1.15)
	-- Bright fill.
	love.graphics.setColor(1, 0.82, 0.15, 1)
	love.graphics.polygon("fill", tip, 0, back, half, back * 0.4, 0, back, -half)
	-- Thick high-contrast outline.
	love.graphics.setColor(0.15, 0.1, 0.02, 1)
	love.graphics.setLineWidth(3)
	love.graphics.polygon("line", tip, 0, back, half, back * 0.4, 0, back, -half)
	love.graphics.pop()
end

return TargetArrow
