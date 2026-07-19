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

function love.errorhandler(msg)
	print(debug.traceback("unexpected error: " .. tostring(msg), 2))
	return function() end
end
