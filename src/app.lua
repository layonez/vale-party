local Gamestate = require("vendor.hump.gamestate")
local Input = require("src.platform.input")
local Touch = require("src.platform.touch")
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
	io.write(os.date("!%Y-%m-%dT%H:%M:%SZ") .. " " .. message .. "\n")
	-- Flush immediately: on the handheld stdout is redirected to a file and thus
	-- block-buffered, so without this the action trail never reaches the log if
	-- the game later hangs or is killed (exactly the case we debug end-screen
	-- input with). Cheap at our log volume.
	io.flush()
end

function App.load()
	-- On the handheld the launcher sets VALE_FULLSCREEN=1 so the 640x480 canvas
	-- fills the panel; App.drawScaled letterboxes whatever the window reports.
	if os.getenv("VALE_FULLSCREEN") then
		pcall(love.window.setFullscreen, true, "desktop")
	end

	love.graphics.setDefaultFilter("nearest", "nearest")
	-- Use a Cyrillic-capable font everywhere; LOVE's built-in font renders
	-- Russian text as tofu boxes.
	love.graphics.setFont(Fonts.get(14))
	App.canvas = love.graphics.newCanvas(App.W, App.H)
	App.input = Input.new()

	-- Touch controls for the web/mobile build: an on-screen D-pad + A button.
	-- The handheld and desktop use real buttons and skip this entirely. Gate on
	-- the Web platform (VALE_TOUCH=1 forces it on for desktop testing).
	App.isTouch = love.system.getOS() == "Web" or os.getenv("VALE_TOUCH") ~= nil
	if App.isTouch then
		App.touch = Touch.new(App.W, App.H)
		App.input = Input.withTouch(App.input, App.touch)
		-- Defined BEFORE Gamestate.registerEvents() (below) so HUMP captures them
		-- and keeps calling them each event (it preserves any pre-existing love
		-- callback, then dispatches to the scene — no scene defines these). Mouse
		-- mirrors touch for desktop-web testing but is ignored once a real touch
		-- arrives, since mobile browsers also emit synthetic mouse events.
		function love.touchpressed(id, x, y)
			App.touch:press(id, x, y)
		end
		function love.touchmoved(id, x, y)
			App.touch:move(id, x, y)
		end
		function love.touchreleased(id, x, y)
			App.touch:release(id)
		end
		function love.mousepressed(x, y, button)
			if button == 1 and not App.touch.touchSeen then
				App.touch:press("mouse", x, y)
			end
		end
		function love.mousemoved(x, y)
			if not App.touch.touchSeen and love.mouse.isDown(1) then
				App.touch:move("mouse", x, y)
			end
		end
		function love.mousereleased(x, y, button)
			if button == 1 then
				App.touch:release("mouse")
			end
		end
	end

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
	-- On-screen touch controls (web/mobile) draw onto the canvas so they scale and
	-- letterbox with the scene; the same math maps a real touch back to this space.
	if App.touch then
		App.touch:draw()
	end
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
