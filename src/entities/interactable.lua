local Interactable = {
	range = 92,
}

---@param x number
---@param y number
---@return table
function Interactable.new(x, y)
	return {
		x = x,
		y = y,
		range = Interactable.range,
		activeTime = 0,
		messageTime = 0,
	}
end

---@param object table
---@param player table
---@return boolean
function Interactable.isNear(object, player)
	local dx = player.x - object.x
	local dy = player.y - object.y
	return dx * dx + dy * dy <= object.range * object.range
end

---@param object table
function Interactable.activate(object)
	object.activeTime = 0.6
	object.messageTime = 1.8
end

---@param object table
---@param dt number
function Interactable.update(object, dt)
	object.activeTime = math.max(0, object.activeTime - dt)
	object.messageTime = math.max(0, object.messageTime - dt)
end

---@param object table
function Interactable.draw(object)
	local scale = 1
	if object.activeTime > 0 then
		scale = 1 + math.sin(object.activeTime * 25) * 0.08
	end

	love.graphics.push()
	love.graphics.translate(object.x, object.y)
	love.graphics.scale(scale, scale)
	love.graphics.setColor(0.22, 0.55, 0.18)
	love.graphics.rectangle("fill", -5, -10, 10, 62, 5)
	love.graphics.setColor(1, 0.72, 0.22)
	for index = 1, 8 do
		local angle = index * math.pi / 4
		love.graphics.ellipse(
			"fill",
			math.cos(angle) * 24,
			math.sin(angle) * 24 - 18,
			15,
			24,
			angle
		)
	end
	love.graphics.setColor(0.45, 0.22, 0.08)
	love.graphics.circle("fill", 0, -18, 16)
	love.graphics.pop()
end

return Interactable
