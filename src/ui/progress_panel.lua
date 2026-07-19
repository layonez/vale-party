-- The permanent mission-progress panel at the top of the Flight Map (spec §16).
-- One slot per mission character, each in one of three states:
--   available  - normal character icon (mission unfinished, character on globe)
--   active     - highlighted border (this character's mission is active)
--   completed  - green check over the icon (character done for this cycle)
-- The panel stays visible in every state, including while a mission is active.
local ProgressPanel = {}

local SLOT = 44 -- slot size in pixels
local GAP = 10 -- gap between slots
local TOP = 8 -- y offset from the top edge

-- Draw a green check mark inside the slot at (x, y).
local function drawCheck(x, y)
	love.graphics.setColor(0.2, 0.75, 0.3, 1)
	love.graphics.setLineWidth(4)
	love.graphics.line(x + 10, y + SLOT / 2, x + SLOT / 2 - 2, y + SLOT - 12, x + SLOT - 8, y + 10)
end

-- Draw the panel. `characters` is the ordered list; `states` maps character id
-- to "available"|"active"|"completed". Centered horizontally at the top.
---@param characters table[]
---@param states table<string,string>
function ProgressPanel.draw(characters, states)
	local count = #characters
	local totalW = count * SLOT + (count - 1) * GAP
	local startX = (640 - totalW) / 2

	for index, character in ipairs(characters) do
		local x = startX + (index - 1) * (SLOT + GAP)
		local state = states[character.id] or "available"

		-- Slot background.
		love.graphics.setColor(0.06, 0.1, 0.18, 0.85)
		love.graphics.rectangle("fill", x, TOP, SLOT, SLOT, 8)

		-- Character icon (dimmed when completed).
		local c = character.color
		local dim = state == "completed" and 0.35 or 1
		love.graphics.setColor(c[1] * dim, c[2] * dim, c[3] * dim, 1)
		love.graphics.circle("fill", x + SLOT / 2, TOP + SLOT / 2, SLOT / 2 - 8)

		-- Border: bright/thick when active, subtle otherwise (spec §16).
		if state == "active" then
			love.graphics.setColor(1, 0.9, 0.35, 1)
			love.graphics.setLineWidth(4)
		else
			love.graphics.setColor(0.4, 0.45, 0.55, 1)
			love.graphics.setLineWidth(2)
		end
		love.graphics.rectangle("line", x, TOP, SLOT, SLOT, 8)

		if state == "completed" then
			drawCheck(x, TOP)
		end
	end
end

return ProgressPanel
