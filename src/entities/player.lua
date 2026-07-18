---@class Player
---@field x number
---@field y number
---@field face string
---@field walkTime number
---@field radius number
local Player = {
	radius = 26,
	speed = 145,
}

---@param x number
---@param y number
---@return Player
function Player.new(x, y)
	return {
		x = x,
		y = y,
		face = "down",
		walkTime = 0,
		radius = Player.radius,
	}
end

---@param input table
---@return number x
---@return number y
function Player.moveVector(input)
	local x = (input.right and 1 or 0) - (input.left and 1 or 0)
	local y = (input.down and 1 or 0) - (input.up and 1 or 0)

	if x ~= 0 or y ~= 0 then
		local length = math.sqrt(x * x + y * y)
		x = x / length
		y = y / length
	end

	return x, y
end

---@param player Player
---@param input table
---@param dt number
---@param bounds table
---@param obstacles table[]
function Player.update(player, input, dt, bounds, obstacles)
	local velocityX, velocityY = Player.moveVector(input)

	if velocityX ~= 0 or velocityY ~= 0 then
		player.walkTime = player.walkTime + dt
		if math.abs(velocityX) > math.abs(velocityY) then
			player.face = velocityX < 0 and "left" or "right"
		else
			player.face = velocityY < 0 and "up" or "down"
		end
	else
		player.walkTime = 0
	end

	local nextX = player.x + velocityX * Player.speed * dt
	local nextY = player.y + velocityY * Player.speed * dt
	nextX = math.max(bounds.x + player.radius, math.min(bounds.x + bounds.w - player.radius, nextX))
	nextY = math.max(bounds.y + player.radius, math.min(bounds.y + bounds.h - player.radius, nextY))

	for _, obstacle in ipairs(obstacles or {}) do
		local overlaps = nextX + player.radius > obstacle.x
			and nextX - player.radius < obstacle.x + obstacle.w
			and nextY + player.radius > obstacle.y
			and nextY - player.radius < obstacle.y + obstacle.h
		if overlaps then
			nextX = player.x
			nextY = player.y
		end
	end

	player.x = nextX
	player.y = nextY
end

---@param player Player
function Player.draw(player)
	local bob = math.sin(player.walkTime * 10) * 4
	love.graphics.setColor(0.22, 0.36, 0.8)
	love.graphics.circle("fill", player.x, player.y - 18 + bob, 22)
	love.graphics.setColor(1, 0.82, 0.55)
	love.graphics.circle("fill", player.x, player.y - 48 + bob, 20)
	love.graphics.setColor(0.08, 0.08, 0.1)
	love.graphics.setLineWidth(4)
	love.graphics.circle("line", player.x, player.y - 48 + bob, 20)
	love.graphics.circle("line", player.x, player.y - 18 + bob, 22)

	local eyeOffset = player.face == "left" and -7 or player.face == "right" and 7 or 0
	love.graphics.circle("fill", player.x - 6 + eyeOffset, player.y - 52 + bob, 3)
	love.graphics.circle("fill", player.x + 6 + eyeOffset, player.y - 52 + bob, 3)
end

return Player
