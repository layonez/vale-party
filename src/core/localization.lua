---@class Localization
---@field language string
---@field logger fun(message:string)|nil
local Localization = {}

local ru = require("content.localization.ru")
local de = require("content.localization.de")
local translations = {
	ru = ru,
	de = de,
}

---@param language string|nil
---@param logger fun(message:string)|nil
---@return Localization
function Localization.new(language, logger)
	return setmetatable({
		language = language or "ru",
		logger = logger,
	}, { __index = Localization })
end

---@param language string
function Localization:setLanguage(language)
	if translations[language] then
		self.language = language
	end
end

---@param key string
---@return string
function Localization:t(key)
	local selected = translations[self.language] or ru
	local value = selected[key]
	if value then
		return value
	end

	if self.logger then
		self.logger("missing translation " .. self.language .. ":" .. key)
	end
	return ru[key] or key
end

---@return string[]
function Localization.languages()
	return { "ru", "de" }
end

return Localization
