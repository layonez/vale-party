-- Env-gated screenshot harness: boots straight into the Flight Map, lets a few
-- frames settle, captures a PNG to the save dir, then quits. Run with:
--   VALE_SHOT=1 love .   (prints "SHOT_SAVED <path>" and exits)
-- Not part of the game; only loaded from main.lua when VALE_SHOT is set.
local App = require("src.app")
local Gamestate = require("vendor.hump.gamestate")

local M = {}

function M.install()
	local frames = 0
	function love.load()
		App.load() -- registers Gamestate events (which sets love.draw)
		local scene = require("src.scenes.flight_map")
		Gamestate.switch(scene, App)

		-- Optionally park the plane over a character so a captured frame shows the
		-- hover highlight. VALE_SHOT_HOVER = "lat,lon".
		local hover = os.getenv("VALE_SHOT_HOVER")
		if hover then
			local lat, lon = hover:match("(-?%d+),(-?%d+)")
			if lat then
				local Sphere = require("src.core.sphere")
				scene.orientation = Sphere.orientationFor(tonumber(lat), tonumber(lon))
			end
		end

		-- Optionally accept a mission so the frame shows the active mission box.
		-- VALE_SHOT_MISSION = character id (e.g. "character_3").
		local missionChar = os.getenv("VALE_SHOT_MISSION")
		if missionChar then
			scene.mission:reset()
			scene.mission:accept(missionChar)
		end

		-- Optionally force the recognized-country label (normally set after
		-- dwelling over a country). VALE_SHOT_COUNTRY = display name.
		local country = os.getenv("VALE_SHOT_COUNTRY")
		if country then
			scene.recognizedName = country
		end

		-- Wrap the draw hook Gamestate just installed so we can grab a frame.
		local gsDraw = love.draw
		function love.draw()
			-- update() clears recognizedName when not dwelling; re-apply each frame.
			if country then
				scene.recognizedName = country
			end
			gsDraw()
			frames = frames + 1
			if frames == 30 then
				love.graphics.captureScreenshot(function(imageData)
					local path = "vale_shot.png"
					imageData:encode("png", path)
					print("SHOT_SAVED " .. love.filesystem.getSaveDirectory() .. "/" .. path)
					love.event.quit()
				end)
			end
		end
	end
end

return M
