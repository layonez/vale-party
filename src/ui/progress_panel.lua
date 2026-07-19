-- The permanent mission-progress panel on the Flight Map (spec §16). One slot
-- per mission character, stacked in a vertical column down the left edge where
-- there is empty space beside the globe. Each slot is in one of three states:
--   available  - normal character icon (mission unfinished, character on globe)
--   active     - highlighted border (this character's mission is active)
--   completed  - green check over the icon (character done for this cycle)
-- The panel stays visible in every state, including while a mission is active.
local ProgressPanel = {}

local SLOT = 56 -- slot size in pixels
local GAP = 12 -- gap between slots
local LEFT = 12 -- x offset from the left edge
local PAD = 5 -- inner padding so the portrait sits inside the slot border
local ICON_SCALE = 1.2 -- portrait is drawn 20% larger than the padded slot fit

-- Path -> Image cache (see src/ui/character.lua). `false` means the asset was
-- missing, so we fall back to the colored circle without retrying each frame.
local images = {}

local function slotImage(path)
	if images[path] == nil then
		local ok, img = pcall(love.graphics.newImage, path)
		images[path] = ok and img or false
	end
	return images[path] or nil
end

-- Draw a green check mark inside the slot whose top-left is (x, y).
local function drawCheck(x, y)
	love.graphics.setColor(0.2, 0.75, 0.3, 1)
	love.graphics.setLineWidth(4)
	love.graphics.line(x + 12, y + SLOT / 2, x + SLOT / 2 - 2, y + SLOT - 14, x + SLOT - 10, y + 12)
end

-- Draw the panel. `characters` is the ordered list; `states` maps character id
-- to "available"|"active"|"completed". Stacked vertically, centered on the
-- left edge of the 640x480 canvas.
---@param characters table[]
---@param states table<string,string>
function ProgressPanel.draw(characters, states)
	local count = #characters
	local totalH = count * SLOT + (count - 1) * GAP
	local startY = (480 - totalH) / 2

	for index, character in ipairs(characters) do
		local x = LEFT
		local y = startY + (index - 1) * (SLOT + GAP)
		local state = states[character.id] or "available"

		-- Slot background.
		love.graphics.setColor(0.06, 0.1, 0.18, 0.85)
		love.graphics.rectangle("fill", x, y, SLOT, SLOT, 8)

		-- Character icon (dimmed when completed). Prefer the portrait art; fall
		-- back to a colored circle when the sprite is missing (e.g. tests).
		local dim = state == "completed" and 0.35 or 1
		local image = character.sprite and slotImage(character.sprite)
		if image then
			local iw, ih = image:getDimensions()
			local inner = SLOT - PAD * 2
			local scale = (inner / math.max(iw, ih)) * ICON_SCALE
			love.graphics.setColor(dim, dim, dim, 1)
			love.graphics.draw(image, x + SLOT / 2, y + SLOT / 2, 0, scale, scale, iw / 2, ih / 2)
		else
			local c = character.color
			love.graphics.setColor(c[1] * dim, c[2] * dim, c[3] * dim, 1)
			love.graphics.circle("fill", x + SLOT / 2, y + SLOT / 2, SLOT / 2 - 8)
		end

		-- Border: bright/thick when active, subtle otherwise (spec §16).
		if state == "active" then
			love.graphics.setColor(1, 0.9, 0.35, 1)
			love.graphics.setLineWidth(4)
		else
			love.graphics.setColor(0.4, 0.45, 0.55, 1)
			love.graphics.setLineWidth(2)
		end
		love.graphics.rectangle("line", x, y, SLOT, SLOT, 8)

		if state == "completed" then
			drawCheck(x, y)
		end
	end
end

return ProgressPanel
