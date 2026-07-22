-- Loads and indexes Flight Map content (content/world.lua) and answers world
-- queries: look up entities by id, and determine which country lies beneath a
-- given world position. Pure logic (no LOVE), so it can be unit tested.
--
-- Country detection uses a great-circle angular distance to each country's
-- region center; the airplane is "over" a country when that distance is within
-- the region's angular radius (degrees). Regions do not overlap by design
-- (spec §7), so the first match wins.
local Sphere = require("src.core.sphere")

local World = {}
World.__index = World

-- Index a list of {id=...} records by id.
local function indexById(list)
	local byId = {}
	for _, item in ipairs(list) do
		byId[item.id] = item
	end
	return byId
end

-- The antipode of a lat/lon: the point on the exact opposite side of the globe.
-- Characters are placed here relative to their drop-off country so the player
-- must fly across the whole world to complete a delivery (content/world.lua).
---@param lat number
---@param lon number
---@return number lat, number lon
local function antipode(lat, lon)
	return -lat, Sphere.normalizeLon(lon + 180)
end

---@param data table content table with countries/character_slots/rounds
---@return table world
function World.new(data)
	local self = setmetatable({}, World)
	self.countries = data.countries
	self.characterSlots = data.character_slots
	self.rounds = data.rounds
	self.countryById = indexById(data.countries)
	-- Start on the first round; buildRound fills characters/missions + indexes.
	self.roundIndex = 1
	self:buildRound()
	return self
end

-- (Re)build the current round's characters and missions from the round's target
-- country ids and the fixed character slots. Each character is positioned at the
-- antipode of its target country. Ids are stable across rounds (character_1..N,
-- mission_1..N) so save data and per-slot sprites are reused every round; only
-- positions and drop-off targets change. Voice lines, by contrast, are keyed by
-- the target country (mission.<country>/thanks.<country> in src/platform/audio),
-- so the spoken destination always matches the current round's actual target.
function World:buildRound()
	local targets = self.rounds[self.roundIndex]
	local characters, missions = {}, {}
	for slot, countryId in ipairs(targets) do
		local country = self.countryById[countryId]
		local lat, lon = antipode(country.latitude, country.longitude)
		local characterId = "character_" .. slot
		local missionId = "mission_" .. slot
		local appearance = self.characterSlots[slot]
		characters[slot] = {
			id = characterId,
			color = appearance.color,
			sprite = appearance.sprite,
			latitude = lat,
			longitude = lon,
			mission_id = missionId,
		}
		missions[slot] = {
			id = missionId,
			character_id = characterId,
			target_country_id = countryId,
		}
	end
	self.characters = characters
	self.missions = missions
	self.characterById = indexById(characters)
	self.missionById = indexById(missions)
end

---@return integer number of delivery rounds in the endless cycle
function World:roundCount()
	return #self.rounds
end

---@return integer the current 1-based round index
function World:currentRound()
	return self.roundIndex
end

-- Switch to round `index`, wrapping into range so the cycle is endless and any
-- stale/out-of-range saved round resolves to a valid one. Rebuilds the round's
-- characters and missions in place.
---@param index number|nil
function World:setRound(index)
	local count = #self.rounds
	index = math.floor(tonumber(index) or 1)
	-- Wrap into 1..count (Lua has no modulo-into-1-based helper).
	self.roundIndex = ((index - 1) % count) + 1
	self:buildRound()
end

-- Advance to the next round, looping back to the first after the last.
function World:advanceRound()
	self:setRound(self.roundIndex + 1)
end

---@param id string
---@return table|nil
function World:country(id)
	return self.countryById[id]
end

---@param id string
---@return table|nil
function World:mission(id)
	return self.missionById[id]
end

---@param id string
---@return table|nil
function World:character(id)
	return self.characterById[id]
end

-- Great-circle angular distance (degrees) between two lat/lon points.
---@param lat1 number
---@param lon1 number
---@param lat2 number
---@param lon2 number
---@return number degrees
function World.angularDistance(lat1, lon1, lat2, lon2)
	local ax, ay, az = Sphere.latLonToVec(lat1, lon1)
	local bx, by, bz = Sphere.latLonToVec(lat2, lon2)
	local dot = math.max(-1, math.min(1, ax * bx + ay * by + az * bz))
	return math.deg(math.acos(dot))
end

-- The playable country whose region contains (lat, lon), or nil. Regions are
-- non-overlapping, so the first (and only) match is returned.
---@param lat number
---@param lon number
---@return table|nil country
function World:countryAt(lat, lon)
	for _, country in ipairs(self.countries) do
		local r = country.region
		if World.angularDistance(lat, lon, r.latitude, r.longitude) <= r.radius then
			return country
		end
	end
	return nil
end

return World
