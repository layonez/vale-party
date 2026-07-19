local Gamestate = require("vendor.hump.gamestate")
local Fonts = require("src.core.fonts")
local Sphere = require("src.core.sphere")
local Input = require("src.platform.input")
local Audio = require("src.platform.audio")
local Landmass = require("src.core.landmass")
local Continents = require("content.continents")
local World = require("src.core.world")
local WorldData = require("content.world")
local Recognition = require("src.core.recognition")

-- Flight Map: the main playable scene. The player flies a small airplane that
-- stays fixed near the center of the screen while the globe rotates beneath it.
--
-- Movement uses a free 3D orientation (see src/core/sphere.lua) rather than a
-- camera lat/lon. This avoids polar singularities: "up" rotates the globe about
-- the screen's horizontal axis, so you fly straight over a pole and keep going
-- instead of stalling there. The airplane stays pinned at the globe center.
local FlightMap = {}

-- Screen-space placement and size of the globe. The airplane sits at the globe
-- center so it reads as "above" the planet surface.
local GLOBE = {
	x = 320,
	y = 250,
	radius = 210,
}

local MOVE_SPEED = 45 -- degrees per second; constant, no acceleration/inertia
local GRID_STEP = 30 -- degrees between grid lines
local SEGMENTS = 48 -- samples per grid line

-- Debug-only auto-drift directions cycled by the dbg_drift key. Each entry is a
-- screen-axis turn {axis, sign}: "y" = up/down flight, "z" = left/right flight.
local DRIFTS = {
	{ "z", -1 }, -- east (globe spins so terrain moves left)
	{ "y", 1 }, -- north
	{ "z", 1 }, -- west
	{ "y", -1 }, -- south
}

-- Deterministic starfield so the background does not flicker frame to frame.
local function buildStars()
	local stars = {}
	local seed = 1
	local function rand()
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	for _ = 1, 90 do
		stars[#stars + 1] = { x = rand() * 640, y = rand() * 480, size = 1 + rand() * 1.5 }
	end
	return stars
end

function FlightMap:enter(_, app)
	self.app = app
	self.stars = buildStars()
	self.continents = Landmass.build(Continents)
	self.world = World.new(WorldData)
	self.recognition = Recognition.new()
	-- Precompute each country's region outline (great-circle circle) once.
	self.countryOutlines = {}
	for _, country in ipairs(self.world.countries) do
		local r = country.region
		self.countryOutlines[country.id] =
			Sphere.circlePoints(r.latitude, r.longitude, r.radius, 40)
	end
	-- Start in the northern part of the globe, no mission active (spec §3).
	self.start = { lat = 40, lon = 10 }
	self.orientation = Sphere.orientationFor(self.start.lat, self.start.lon)
	self.time = 0
	self.currentCountryId = nil
	-- Debug-only auto-drift so rotation is observable without holding a key.
	-- 0 = off; other indices pick a direction from DRIFTS.
	self.drift = 0
end

-- Read the d-pad into a screen-axis turn for this frame. Conflicting directions
-- resolve consistently (vertical wins) and there is no diagonal requirement.
-- Returns an axis ("y"/"z") and signed angle in radians, or nil when idle.
local function turnDelta(input, dt)
	local step = math.rad(MOVE_SPEED * dt)
	if input:down("move_up") then
		return "y", step
	elseif input:down("move_down") then
		return "y", -step
	elseif input:down("move_right") then
		return "z", -step
	elseif input:down("move_left") then
		return "z", step
	end
	return nil
end

function FlightMap:update(dt)
	local input = self.app.input
	input:update()
	Input.logActions(input, self.app.log)

	if input:pressed("debug") then
		self.app.toggleDebug()
	end
	if input:pressed("pause") then
		Gamestate.push(require("src.scenes.pause"), self.app, self)
		return
	end

	-- Debug-only movement helpers, gated so they never affect real gameplay.
	if self.app.debug then
		if input:pressed("dbg_drift") then
			self.drift = (self.drift + 1) % (#DRIFTS + 1)
		end
		if input:pressed("dbg_reset") then
			self.orientation = Sphere.orientationFor(self.start.lat, self.start.lon)
			self.drift = 0
		end
	else
		self.drift = 0
	end

	local axis, angle = turnDelta(input, dt)
	-- Manual input always wins and cancels any active drift.
	if axis then
		self.drift = 0
	elseif self.drift > 0 then
		local dir = DRIFTS[self.drift]
		axis, angle = dir[1], dir[2] * math.rad(MOVE_SPEED * dt)
	end
	if axis then
		self.orientation = Sphere.turn(self.orientation, axis, angle)
	end

	-- Country detection uses the world point beneath the airplane (view front).
	local lat, lon = Sphere.front(self.orientation)
	local country = self.world:countryAt(lat, lon)
	self.currentCountryId = country and country.id or nil
	local recognized = self.recognition:update(self.currentCountryId, dt)
	if recognized then
		local named = self.world:country(recognized)
		self.app.log("recognized:" .. recognized)
		Audio.playVoice(self.app.audio, self.app.loc.language, "voice." .. recognized)
		self.recognizedName = self.app.loc:t(named.name_key)
	elseif not self.recognition.recognizedId then
		self.recognizedName = nil
	end

	self.time = self.time + dt
end

local function drawStars(stars)
	love.graphics.setColor(1, 1, 1, 0.85)
	for _, star in ipairs(stars) do
		love.graphics.circle("fill", star.x, star.y, star.size)
	end
end

-- Draw one grid line by sampling world points and projecting them. A break in
-- visibility (point passing behind the horizon) starts a new polyline so lines
-- disappear naturally at the edge instead of streaking across the disc.
local function drawGridLine(points, orientation)
	local run = {}
	local function flush()
		if #run >= 4 then
			love.graphics.line(run)
		end
		run = {}
	end
	for _, p in ipairs(points) do
		local sx, sy, visible =
			Sphere.project(orientation, p[1], p[2], GLOBE.radius, GLOBE.x, GLOBE.y)
		if visible then
			run[#run + 1] = sx
			run[#run + 1] = sy
		else
			flush()
		end
	end
	flush()
end

function FlightMap:drawGlobe()
	local orientation = self.orientation

	-- Ocean sphere with a soft rim so the curvature and horizon read clearly.
	love.graphics.setColor(0.16, 0.42, 0.7)
	love.graphics.circle("fill", GLOBE.x, GLOBE.y, GLOBE.radius)

	-- Simplified continents for geographic reference (non-interactive).
	Landmass.draw(self.continents, orientation, GLOBE)

	-- Lat/lon graticule rotating beneath the plane.
	love.graphics.setColor(0.35, 0.62, 0.85, 0.75)
	love.graphics.setLineWidth(1)
	-- Parallels (constant latitude).
	for lat = -60, 60, GRID_STEP do
		local pts = {}
		for i = 0, SEGMENTS do
			pts[#pts + 1] = { lat, -180 + i * 360 / SEGMENTS }
		end
		drawGridLine(pts, orientation)
	end
	-- Meridians (constant longitude).
	for lon = -180, 150, GRID_STEP do
		local pts = {}
		for i = 0, SEGMENTS do
			pts[#pts + 1] = { -90 + i * 180 / SEGMENTS, lon }
		end
		drawGridLine(pts, orientation)
	end

	self:drawCountries(orientation)

	-- Horizon rim on top.
	love.graphics.setColor(0.09, 0.24, 0.45)
	love.graphics.setLineWidth(6)
	love.graphics.circle("line", GLOBE.x, GLOBE.y, GLOBE.radius)
end

-- Outline each playable country's region. The recognised country (or the one
-- currently beneath the plane) gets a brighter, thicker highlight (spec §8).
function FlightMap:drawCountries(orientation)
	for _, country in ipairs(self.world.countries) do
		local recognized = self.recognition.recognizedId == country.id
		if recognized then
			love.graphics.setColor(1, 0.95, 0.5, 0.95)
			love.graphics.setLineWidth(3)
		else
			love.graphics.setColor(0.95, 0.85, 0.4, 0.5)
			love.graphics.setLineWidth(2)
		end
		drawGridLine(self.countryOutlines[country.id], orientation)
	end
end

local function drawAirplane(x, y)
	love.graphics.push()
	love.graphics.translate(x, y)
	love.graphics.setColor(1, 0.95, 0.4)
	love.graphics.polygon("fill", 0, -18, 12, 14, 0, 8, -12, 14)
	love.graphics.setColor(0.2, 0.2, 0.25)
	love.graphics.setLineWidth(3)
	love.graphics.polygon("line", 0, -18, 12, 14, 0, 8, -12, 14)
	love.graphics.pop()
end

function FlightMap:drawWorld()
	love.graphics.setColor(0.04, 0.05, 0.12)
	love.graphics.rectangle("fill", 0, 0, 640, 480)
	drawStars(self.stars)
	self:drawGlobe()
	drawAirplane(GLOBE.x, GLOBE.y)

	-- Recognised country name, shown as a learning aid (spec §8). Play is fully
	-- possible without reading, so this is supplementary.
	if self.recognizedName then
		love.graphics.setFont(Fonts.get(26))
		local w = 360
		love.graphics.setColor(0.05, 0.1, 0.2, 0.8)
		love.graphics.rectangle("fill", (640 - w) / 2, 400, w, 48, 14)
		love.graphics.setColor(1, 0.97, 0.7)
		love.graphics.printf(self.recognizedName, (640 - w) / 2, 412, w, "center")
	end

	love.graphics.setFont(Fonts.get(14))
	local driftNames = { "east", "north", "west", "south" }
	local lat, lon = Sphere.front(self.orientation)
	self.app.drawDebug(
		"flight_map",
		string.format(
			"lat: %.1f\nlon: %.1f\nover: %s\ndrift[0]: %s\nreset[9]",
			lat,
			lon,
			self.currentCountryId or "-",
			self.drift > 0 and driftNames[self.drift] or "off"
		)
	)
end

function FlightMap:draw()
	self.app.drawScaled(function()
		self:drawWorld()
	end)
end

return FlightMap
