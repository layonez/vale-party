local Gamestate = require("vendor.hump.gamestate")
local Menu = require("src.ui.menu")

local Pause = {}

function Pause:enter(app, garden)
	self.app = app
	self.garden = garden
	self.selected = 1
end

function Pause:update()
	local input = self.app.input
	input:update()

	if input:pressed("move_down") then
		self.selected = math.min(3, self.selected + 1)
	end
	if input:pressed("move_up") then
		self.selected = math.max(1, self.selected - 1)
	end
	if input:pressed("back") or input:pressed("pause") then
		Gamestate.pop()
	end
	if input:pressed("interact") then
		if self.selected == 1 then
			Gamestate.pop()
		elseif self.selected == 2 then
			Gamestate.switch(require("src.scenes.garden"), self.app)
		else
			Gamestate.switch(require("src.scenes.main_menu"), self.app)
		end
	end
end

function Pause:draw()
	self.app.drawScaled(function()
		self.garden:drawWorld()
		love.graphics.setColor(0, 0, 0, 0.48)
		love.graphics.rectangle("fill", 0, 0, 640, 480)
		love.graphics.setFont(love.graphics.newFont(28))
		Menu.draw({
			{ label = self.app.loc:t("pause.continue") },
			{ label = self.app.loc:t("pause.restart") },
			{ label = self.app.loc:t("pause.main_menu") },
		}, self.selected, 170, 150, 300)
	end)
end

return Pause
