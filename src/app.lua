local Gamestate = require("vendor.hump.gamestate")
local Input = require("src.platform.input")
local Audio = require("src.platform.audio")
local Settings = require("src.core.settings_love")
local Localization = require("src.core.localization")
local Fonts = require("src.core.fonts")

---@class App
---@field W integer
---@field H integer
---@field VERSION string
local App = {
	W = 640,
	H = 480,
	VERSION = "0.1.0",
}

---@param message string
function App.log(message)
	print(os.date("!%Y-%m-%dT%H:%M:%SZ") .. " " .. message)
end

function App.load()
	love.graphics.setDefaultFilter("nearest", "nearest")
	-- Use a Cyrillic-capable font everywhere; LOVE's built-in font renders
	-- Russian text as tofu boxes.
	love.graphics.setFont(Fonts.get(14))
	App.canvas = love.graphics.newCanvas(App.W, App.H)
	App.input = Input.new()
	App.settings = Settings.load(App.log)
	App.loc = Localization.new(App.settings.language, App.log)
	App.audio = Audio.new(App.log)
	App.debug = App.settings.debug

	local loveVersion = { love.getVersion() }
	App.log("Valya Adventure " .. App.VERSION .. " love " .. table.concat(loveVersion, "."))
	App.log("os " .. love.system.getOS())

	for _, joystick in ipairs(love.joystick.getJoysticks()) do
		App.log("joystick " .. joystick:getName())
	end

	Gamestate.registerEvents()
	Gamestate.switch(require("src.scenes.main_menu"), App)
end

function App.save()
	App.settings.language = App.loc.language
	App.settings.debug = App.debug
	Settings.save(App.settings, App.log)
end

---@param drawWorld fun()
function App.drawScaled(drawWorld)
	love.graphics.setCanvas(App.canvas)
	love.graphics.clear(0.67, 0.86, 0.95)
	drawWorld()
	love.graphics.setCanvas()

	local windowWidth, windowHeight = love.graphics.getDimensions()
	local scale = math.min(windowWidth / App.W, windowHeight / App.H)
	local offsetX = (windowWidth - App.W * scale) / 2
	local offsetY = (windowHeight - App.H * scale) / 2

	love.graphics.clear(0.05, 0.07, 0.1)
	love.graphics.setColor(1, 1, 1)
	love.graphics.draw(App.canvas, offsetX, offsetY, 0, scale, scale)
end

function App.toggleDebug()
	App.debug = not App.debug
	App.save()
end

---@param sceneName string
---@param extra string|nil
function App.drawDebug(sceneName, extra)
	if not App.debug then
		return
	end

	love.graphics.setColor(0, 0, 0, 0.65)
	love.graphics.rectangle("fill", 8, 8, 290, 150)
	love.graphics.setColor(1, 1, 1)
	love.graphics.print(
		"scene: "
			.. sceneName
			.. "\nlang: "
			.. App.loc.language
			.. "\nfps: "
			.. love.timer.getFPS()
			.. "\njoystick: "
			.. (App.input.joystick and App.input.joystick:getName() or "none")
			.. "\n"
			.. (extra or ""),
		16,
		16
	)
end

return App
