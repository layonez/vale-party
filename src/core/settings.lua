local Settings = {}

Settings.defaults = {
	language = "ru",
	fullscreen = false,
	debug = false,
}

local function isValid(settings)
	return type(settings) == "table" and (settings.language == "ru" or settings.language == "de")
end

---@param settings table|nil
---@return table
function Settings.normalize(settings)
	if not isValid(settings) then
		return {
			language = "ru",
			fullscreen = false,
			debug = false,
		}
	end

	return {
		language = settings.language,
		fullscreen = settings.fullscreen == true,
		debug = settings.debug == true,
	}
end

---@param text string|nil
---@return table
function Settings.decode(text)
	local ok, chunk = pcall(loadstring or load, "return " .. (text or ""))
	if ok and type(chunk) == "function" then
		local okData, data = pcall(chunk)
		if okData then
			return Settings.normalize(data)
		end
	end
	return Settings.normalize(nil)
end

---@param settings table
---@return string
function Settings.encode(settings)
	settings = Settings.normalize(settings)
	return string.format(
		"{language=%q, fullscreen=%s, debug=%s}",
		settings.language,
		tostring(settings.fullscreen),
		tostring(settings.debug)
	)
end

return Settings
