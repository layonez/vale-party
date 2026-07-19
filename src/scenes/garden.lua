local Gamestate = require("vendor.hump.gamestate")
local Player = require("src.entities.player")
local Flower = require("src.entities.interactable")
local Input = require("src.platform.input")
local Prompt = require("src.ui.interaction_prompt")

local Garden = {
	bounds = { x = 34, y = 72, w = 572, h = 360 },
	obstacles = { { x = 246, y = 224, w = 120, h = 38 } },
}

function Garden:enter(_, app)
	self.app = app
	self.player = Player.new(120, 360)
	self.flower = Flower.new(500, 285)
	self.instructionTime = 2.4
end

---@param dt number
function Garden:update(dt)
	local input = self.app.input
	input:update()

	if input:pressed("debug") then
		self.app.toggleDebug()
	end
	if input:pressed("pause") then
		Gamestate.push(require("src.scenes.pause"), self.app, self)
		return
	end
	if input:pressed("repeat_instruction") then
		self.instructionTime = 2.8
		self.app.audio.playVoice(self.app.audio, self.app.loc.language, "garden.instruction")
	end

	local nearFlower = Flower.isNear(self.flower, self.player)
	if input:pressed("interact") and nearFlower then
		Flower.activate(self.flower)
		self.app.audio.playVoice(self.app.audio, self.app.loc.language, "garden.interaction")
	end

	Player.update(self.player, Input.snapshot(input), dt, self.bounds, self.obstacles)
	Flower.update(self.flower, dt)
	self.instructionTime = math.max(0, self.instructionTime - dt)
	self.near = nearFlower
end

function Garden:drawWorld()
	love.graphics.setColor(0.66, 0.89, 0.58)
	love.graphics.rectangle("fill", 0, 0, 640, 480)
	love.graphics.setColor(0.48, 0.76, 0.38)
	love.graphics.rectangle("fill", 34, 72, 572, 360, 24)
	love.graphics.setColor(0.42, 0.25, 0.12)
	love.graphics.rectangle("fill", 246, 224, 120, 38, 12)
	love.graphics.setColor(0.25, 0.55, 0.2)
	love.graphics.setLineWidth(8)
	love.graphics.rectangle("line", 34, 72, 572, 360, 24)

	Flower.draw(self.flower)
	if self.near then
		Prompt.draw(self.app.loc:t("garden.prompt"), self.flower.x, self.flower.y)
	end
	Player.draw(self.player)

	love.graphics.setFont(love.graphics.newFont(24))
	if self.flower.messageTime > 0 then
		love.graphics.setColor(1, 1, 1, 0.9)
		love.graphics.rectangle("fill", 365, 120, 190, 54, 18)
		love.graphics.setColor(0.1, 0.1, 0.1)
		love.graphics.printf(self.app.loc:t("garden.interaction"), 365, 135, 190, "center")
	end
	if self.instructionTime > 0 then
		love.graphics.setColor(0.05, 0.1, 0.05, 0.75)
		love.graphics.rectangle("fill", 48, 18, 544, 44, 14)
		love.graphics.setColor(1, 1, 1)
		love.graphics.printf(self.app.loc:t("garden.instruction"), 60, 28, 520, "center")
	end

	self.app.drawDebug(
		"garden",
		string.format("player: %.0f,%.0f\nnear: %s", self.player.x, self.player.y, tostring(self.near))
	)
end

function Garden:draw()
	self.app.drawScaled(function()
		self:drawWorld()
	end)
end

return Garden
