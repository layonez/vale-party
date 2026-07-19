local Gamestate = require("vendor.hump.gamestate")
local Menu = require("src.ui.menu")

local MainMenu = {}

function MainMenu:enter(_, app)
	self.app = app
	self.selected = 1
end

function MainMenu:update()
	local input = self.app.input
	input:update()

	if input:pressed("debug") then
		self.app.toggleDebug()
	end
	if input:pressed("move_down") then
		self.selected = math.min(3, self.selected + 1)
	end
	if input:pressed("move_up") then
		self.selected = math.max(1, self.selected - 1)
	end
	if input:pressed("move_left") or input:pressed("move_right") then
		self:toggleLanguage()
	end
	if input:pressed("interact") then
		if self.selected == 1 then
			Gamestate.switch(require("src.scenes.garden"), self.app)
		elseif self.selected == 2 then
			self:toggleLanguage()
		else
			love.event.quit()
		end
	end
end

function MainMenu:toggleLanguage()
	local nextLanguage = self.app.loc.language == "ru" and "de" or "ru"
	self.app.loc:setLanguage(nextLanguage)
	self.app.save()
end

function MainMenu:draw()
	local app = self.app
	app.drawScaled(function()
		love.graphics.setFont(love.graphics.newFont(32))
		love.graphics.setColor(0.18, 0.48, 0.22)
		love.graphics.printf(app.loc:t("title"), 40, 48, 560, "center")

		love.graphics.setFont(love.graphics.newFont(26))
		local languageLabel = app.loc:t("menu.language")
			.. ": "
			.. app.loc:t("language." .. app.loc.language)
		Menu.draw({
			{ label = app.loc:t("menu.start") },
			{ label = languageLabel },
			{ label = app.loc:t("menu.quit") },
		}, self.selected, 170, 160, 300)
		app.drawDebug("main_menu")
	end)
end

return MainMenu
