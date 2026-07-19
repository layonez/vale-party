local M = {}
function M.draw(text, x, y)
	love.graphics.setColor(1, 1, 1, 0.92)
	love.graphics.rectangle("fill", x - 70, y - 92, 140, 42, 14)
	love.graphics.setColor(0.1, 0.2, 0.1)
	love.graphics.printf(text, x - 70, y - 82, 140, "center")
end
return M
