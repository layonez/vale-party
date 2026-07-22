local Gamestate = require("vendor.hump.gamestate")
local Menu = require("src.ui.menu")
local Fonts = require("src.core.fonts")
local Audio = require("src.platform.audio")

local MainMenu = {}

local logo = love.graphics.newImage("assets/sprites/logo.png")

function MainMenu:enter(_, app)
	self.app = app
	self.selected = 1
	-- Silence gameplay music whenever we land on the menu. This is the single
	-- authoritative stop: it covers quitting to menu directly and via the pause
	-- menu (where the Flight Map is not the top state, so its leave never fires).
	Audio.stopMusic(app.audio)
end

function MainMenu:update()
	local input = self.app.input
	input:update()

	if input:pressed("debug") then
		self.app.toggleDebug()
	end
	if input:pressed("move_right") then
		self.selected = math.min(3, self.selected + 1)
	end
	if input:pressed("move_left") then
		self.selected = math.max(1, self.selected - 1)
	end
	if input:pressed("interact") then
		if self.selected == 1 then
			Gamestate.switch(require("src.scenes.flight_map"), self.app)
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
		local pad = 20
		local lw, lh = logo:getDimensions()
		local maxW = app.W - pad * 2
		local scale = math.min(maxW / lw, (app.H * 0.75) / lh) * 1.3086
		local lx = (app.W - lw * scale) / 2
		local ly = pad - app.H * 0.11
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.draw(logo, lx, ly, 0, scale, scale)

		love.graphics.setFont(Fonts.get(26))
		local btnH = 56
		local btnY = app.H - btnH - pad
		Menu.drawHorizontal({
			{ label = app.loc:t("menu.start") },
			{ label = app.loc:t("language." .. app.loc.language) },
			{ label = app.loc:t("menu.quit") },
		}, self.selected, pad, btnY, app.W - pad * 2, btnH)
		app.drawDebug("main_menu")
	end)
end

return MainMenu
