-- Central font loader. LOVE's built-in font (Vera Sans) has no Cyrillic
-- glyphs, so Russian text renders as tofu boxes. We vendor DejaVu Sans, which
-- covers Latin and Cyrillic, and route every font through here so all scenes
-- share the same glyph coverage.
local FONT_PATH = "assets/fonts/DejaVuSans.ttf"

local M = { path = FONT_PATH }
local cache = {}

---@param size integer
function M.get(size)
	local font = cache[size]
	if not font then
		font = love.graphics.newFont(FONT_PATH, size)
		cache[size] = font
	end
	return font
end

return M
