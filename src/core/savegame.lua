-- Persistent Flight Map save state (spec §20): the minimum needed to resume a
-- session — airplane position, current-cycle completion, and the active mission
-- if any. Pure serialization logic (no LOVE), so it is unit tested; the
-- love.filesystem I/O lives in src/core/savegame_love.lua.
--
-- The airplane position is stored as the front lat/lon (not the full 3D
-- orientation); restoring via Sphere.orientationFor is close enough and keeps
-- the save format simple and human-readable.
local SaveGame = {}

-- A fresh save: airplane at the northern start, first round, nothing completed,
-- no mission.
---@return table
function SaveGame.fresh()
	return {
		lat = 40,
		lon = 10,
		round = 1,
		completed = {},
		activeMissionId = nil,
	}
end

-- Coerce arbitrary decoded data into a valid save, filling defaults for missing
-- or malformed fields so a corrupt file never crashes the game.
---@param data table|nil
---@return table
function SaveGame.normalize(data)
	if type(data) ~= "table" then
		return SaveGame.fresh()
	end
	local out = SaveGame.fresh()
	if type(data.lat) == "number" and data.lat >= -90 and data.lat <= 90 then
		out.lat = data.lat
	end
	if type(data.lon) == "number" then
		out.lon = data.lon
	end
	-- Round is validated as a positive integer only; World:setRound wraps any
	-- value that exceeds the actual round count, so a stale save never wedges.
	if type(data.round) == "number" and data.round >= 1 then
		out.round = math.floor(data.round)
	end
	if type(data.completed) == "table" then
		out.completed = {}
		for _, id in ipairs(data.completed) do
			if type(id) == "string" then
				out.completed[#out.completed + 1] = id
			end
		end
	end
	if type(data.activeMissionId) == "string" then
		out.activeMissionId = data.activeMissionId
	end
	return out
end

-- Decode a Lua-literal save string, tolerating garbage by falling back to fresh.
---@param text string|nil
---@return table
function SaveGame.decode(text)
	local ok, chunk = pcall(loadstring or load, "return " .. (text or ""))
	if ok and type(chunk) == "function" then
		local okData, data = pcall(chunk)
		if okData then
			return SaveGame.normalize(data)
		end
	end
	return SaveGame.fresh()
end

-- Encode a save table to a Lua-literal string.
---@param save table
---@return string
function SaveGame.encode(save)
	save = SaveGame.normalize(save)
	local ids = {}
	for _, id in ipairs(save.completed) do
		ids[#ids + 1] = string.format("%q", id)
	end
	return string.format(
		"{lat=%s, lon=%s, round=%s, completed={%s}, activeMissionId=%s}",
		tostring(save.lat),
		tostring(save.lon),
		tostring(save.round),
		table.concat(ids, ", "),
		save.activeMissionId and string.format("%q", save.activeMissionId) or "nil"
	)
end

return SaveGame
