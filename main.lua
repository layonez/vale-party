local app = require("src.app")

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
