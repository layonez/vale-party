local settings = require("src.core.settings")
local M = { file = "settings.lua" }
function M.load(log)
	if not love.filesystem.getInfo(M.file) then
		return settings.normalize(nil)
	end
	local ok, data = pcall(love.filesystem.read, M.file)
	if not ok then
		if log then
			log("settings load failure")
		end
		return settings.normalize(nil)
	end
	return settings.decode(data)
end
function M.save(s, log)
	local ok, err = pcall(love.filesystem.write, M.file, settings.encode(s))
	if not ok and log then
		log("settings save failure: " .. tostring(err))
	end
end
return M
