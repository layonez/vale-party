return {
	draw = function(x, y, w, h)
		love.graphics.setColor(1, 0.55, 0.1)
		love.graphics.setLineWidth(7)
		love.graphics.rectangle("line", x - 6, y - 6, w + 12, h + 12, 22)
	end,
}
