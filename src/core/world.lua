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

---@param data table content table with countries/airports/characters/missions
---@return table world
function World.new(data)
	local self = setmetatable({}, World)
	self.countries = data.countries
	self.airports = data.airports
	self.characters = data.characters
	self.missions = data.missions
	self.countryById = indexById(data.countries)
	self.airportById = indexById(data.airports)
	self.characterById = indexById(data.characters)
	self.missionById = indexById(data.missions)
	return self
end

---@param id string
---@return table|nil
function World:country(id)
	return self.countryById[id]
end

---@param id string
---@return table|nil
function World:airport(id)
	return self.airportById[id]
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
