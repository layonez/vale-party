local app = require("src.app")

-- Env-gated screenshot harness (dev only): VALE_SHOT=1 love . boots into the
-- Flight Map, captures a frame, and quits. Skipped entirely in normal runs.
if os.getenv("VALE_SHOT") then
	require("scripts.shot").install()
	return
end

function love.load()
	app.load()
end

function love.quit()
	app.log("clean shutdown")
	app.save()
end

-- Crash handling. The stock previous handler returned a do-nothing loop, so any
-- runtime error froze the game with no way out — on the handheld the only escape
-- was rebooting the console. This handler instead:
--   * writes the full traceback to a flushed file in the save dir (love's
--     redirected stdout is block-buffered, so a crash's traceback otherwise
--     never reaches the launcher log), and
--   * shows a minimal message and lets ANY button/key/quit exit cleanly, so a
--     crash returns to the App Center menu instead of wedging the device.
function love.errorhandler(msg)
	msg = tostring(msg)
	local trace = debug.traceback("unexpected error: " .. msg, 2)
	print(trace)

	-- Persist the traceback immediately (flushed) so it survives a freeze/reboot.
	if love.filesystem then
		pcall(love.filesystem.write, "crash.log", trace .. "\n")
	end

	if not love.window or not love.graphics or not love.event then
		return 1 -- headless: just quit with an error code
	end
	love.graphics.setColor(1, 1, 1)
	-- Prefer the currently-set font (the game's Cyrillic DejaVu once app.load ran);
	-- fall back to a fresh font if the crash happened before any was set.
	local font = love.graphics.getFont() or love.graphics.newFont(14)

	local function draw()
		love.graphics.origin()
		love.graphics.clear(0.1, 0.12, 0.18)
		love.graphics.printf(
			"Что-то сломалось.\nНажми любую кнопку, чтобы выйти.\n\n" .. msg,
			font,
			40,
			60,
			560,
			"left"
		)
		love.graphics.present()
	end

	return function()
		love.event.pump()
		for e in love.event.poll() do
			if e == "quit" or e == "keypressed" or e == "gamepadpressed" or e == "joystickpressed" then
				return 1
			end
		end
		draw()
		if love.timer then
			love.timer.sleep(0.05)
		end
	end
end
