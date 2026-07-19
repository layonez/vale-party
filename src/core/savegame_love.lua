-- love.filesystem I/O for the Flight Map save state, mirroring settings_love.
-- Serialization lives in src/core/savegame.lua so it can be unit tested.
local savegame = require("src.core.savegame")
local M = { file = "savegame.lua" }

function M.load(log)
	if not love.filesystem.getInfo(M.file) then
		return savegame.fresh()
	end
	local ok, data = pcall(love.filesystem.read, M.file)
	if not ok then
		if log then
			log("savegame load failure")
		end
		return savegame.fresh()
	end
	return savegame.decode(data)
end

function M.save(state, log)
	local ok, err = pcall(love.filesystem.write, M.file, savegame.encode(state))
	if not ok and log then
		log("savegame save failure: " .. tostring(err))
	end
end

return M
