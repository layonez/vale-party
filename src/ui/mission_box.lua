-- The active-mission box, bottom-right of the Flight Map (spec §14). Shows who
-- we are carrying (the mission character's portrait), the phrase "wants to go"
-- and, on a second line, the target country's name in bold with its flag on the
-- right. Hidden when no mission is active (the scene only calls draw while a
-- mission is active). The name is supplementary; the portrait + flag + arrow +
-- highlight carry the mission without reading.
local Fonts = require("src.core.fonts")

local MissionBox = {}

local W = 250
local H = 92
local MARGIN = 12
local PORTRAIT = 60 -- character portrait box on the left

-- Path -> Image cache (see src/ui/character.lua). `false` = missing asset.
local images = {}

local function sprite(path)
	if images[path] == nil then
		local ok, img = pcall(love.graphics.newImage, path)
		images[path] = ok and img or false
	end
	return images[path] or nil
end

-- Fake-bold: DejaVuSans has no bold face, so we stamp the text a few times with
-- tiny offsets to thicken the strokes. Assumes color + font are already set.
local function printBold(text, x, y, wrap, align)
	for _, o in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
		love.graphics.printf(text, x + o[1], y + o[2], wrap, align)
	end
end

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

-- Draw the box. `country` is the target (has .flag colors); `name` is its
-- localized name; `character` is who we are carrying (has .sprite); `prompt` is
-- the localized "wants to go" phrase.
---@param country table
---@param name string
---@param character table
---@param prompt string
function MissionBox.draw(country, name, character, prompt)
	local x = 640 - W - MARGIN
	local y = 480 - H - MARGIN

	-- Panel.
	love.graphics.setColor(0.06, 0.1, 0.18, 0.9)
	love.graphics.rectangle("fill", x, y, W, H, 10)
	love.graphics.setColor(0.4, 0.45, 0.55, 1)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", x, y, W, H, 10)

	-- Carried character portrait, boxed on the left.
	local px, py = x + 10, y + (H - PORTRAIT) / 2
	love.graphics.setColor(0.03, 0.05, 0.1, 1)
	love.graphics.rectangle("fill", px, py, PORTRAIT, PORTRAIT, 8)
	local img = character and character.sprite and sprite(character.sprite)
	if img then
		local iw, ih = img:getDimensions()
		local scale = (PORTRAIT - 6) / math.max(iw, ih)
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.draw(img, px + PORTRAIT / 2, py + PORTRAIT / 2, 0, scale, scale, iw / 2, ih / 2)
	elseif character then
		local c = character.color
		love.graphics.setColor(c[1], c[2], c[3], 1)
		love.graphics.circle("fill", px + PORTRAIT / 2, py + PORTRAIT / 2, PORTRAIT / 2 - 6)
	end
	love.graphics.setColor(0.4, 0.45, 0.55, 1)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", px, py, PORTRAIT, PORTRAIT, 8)

	-- Text column to the right of the portrait.
	local tx = px + PORTRAIT + 10
	local tw = x + W - tx - 10

	-- Line 1: "wants to go" prompt — larger and brighter than before.
	love.graphics.setFont(Fonts.get(18))
	love.graphics.setColor(1, 0.95, 0.8, 1)
	love.graphics.printf(prompt, tx, y + 12, tw, "center")

	-- Line 2: country name in bold, centered, with the flag to its right.
	-- Reserve room for the flag, then shrink the font until the name fits on a
	-- single line (long names like "Германия" must not wrap).
	local flagW, flagH = 34, 24
	local nameW = tw - flagW - 8
	local size = 22
	local font = Fonts.get(size)
	while size > 12 and font:getWidth(name) > nameW do
		size = size - 1
		font = Fonts.get(size)
	end
	love.graphics.setFont(font)
	local nameY = y + 44 + (22 - size) / 2 -- keep smaller text vertically centered on the line
	love.graphics.setColor(1, 0.97, 0.85, 1)
	printBold(name, tx, nameY, nameW, "center")
	drawFlag(country.flag, tx + nameW + 8, y + 46, flagW, flagH)
end

return MissionBox
