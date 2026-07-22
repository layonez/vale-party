local M = {}

function M.draw(items, selected, x, y, w)
	for i, it in ipairs(items) do
		local yy = y + (i - 1) * 72
		love.graphics.setColor(i == selected and { 1, 0.86, 0.32 } or { 0.95, 0.95, 0.9 })
		love.graphics.rectangle("fill", x, yy, w, 56, 18)
		love.graphics.setColor(0.12, 0.16, 0.2)
		love.graphics.setLineWidth(5)
		love.graphics.rectangle("line", x, yy, w, 56, 18)
		love.graphics.printf(it.label, x, yy + 13, w, "center")
	end
end

function M.drawHorizontal(items, selected, x, y, totalW, h)
	h = h or 56
	local gap = 10
	local n = #items
	local bw = (totalW - (n - 1) * gap) / n
	for i, it in ipairs(items) do
		local xx = x + (i - 1) * (bw + gap)
		love.graphics.setColor(i == selected and { 1, 0.86, 0.32 } or { 0.95, 0.95, 0.9 })
		love.graphics.rectangle("fill", xx, y, bw, h, 18)
		love.graphics.setColor(0.12, 0.16, 0.2)
		love.graphics.setLineWidth(5)
		love.graphics.rectangle("line", xx, y, bw, h, 18)
		love.graphics.printf(
			it.label,
			xx,
			y + (h - love.graphics.getFont():getHeight()) / 2,
			bw,
			"center"
		)
	end
end

return M
