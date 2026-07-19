-- The active-mission box, bottom-right of the Flight Map (spec §14). Shows the
-- target country's flag, name, and a question mark. Hidden when no mission is
-- active (the scene only calls draw while a mission is active). The name is
-- supplementary; the flag + arrow + highlight carry the mission without reading.
local Fonts = require("src.core.fonts")

local MissionBox = {}

local W = 150
local H = 60
local MARGIN = 12

-- Draw the target country's flag as horizontal stripes from its color list.
local function drawFlag(colors, x, y, w, h)
	local n = #colors
	local stripe = h / n
	for i, c in ipairs(colors) do
		love.graphics.setColor(c[1], c[2], c[3], 1)
		love.graphics.rectangle("fill", x, y + (i - 1) * stripe, w, stripe)
	end
	love.graphics.setColor(0.1, 0.1, 0.12, 1)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", x, y, w, h)
end

-- Draw the box for the given target country. `name` is the localized name.
---@param country table target country (has .flag colors)
---@param name string
function MissionBox.draw(country, name)
	local x = 640 - W - MARGIN
	local y = 480 - H - MARGIN

	-- Panel.
	love.graphics.setColor(0.06, 0.1, 0.18, 0.9)
	love.graphics.rectangle("fill", x, y, W, H, 10)
	love.graphics.setColor(0.4, 0.45, 0.55, 1)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", x, y, W, H, 10)

	-- Flag on the left.
	drawFlag(country.flag, x + 10, y + 12, 48, 34)

	-- Question mark on the right (spec §14).
	love.graphics.setFont(Fonts.get(26))
	love.graphics.setColor(1, 0.9, 0.4, 1)
	love.graphics.printf("?", x + W - 34, y + 14, 24, "center")

	-- Country name across the bottom.
	love.graphics.setFont(Fonts.get(16))
	love.graphics.setColor(1, 0.97, 0.85, 1)
	love.graphics.printf(name, x + 62, y + 20, W - 70, "center")
end

return MissionBox
